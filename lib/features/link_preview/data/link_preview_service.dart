import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html_parser;

import 'link_metadata.dart';

/// Regex for detecting URLs in message text.
///
/// Matches `http://` and `https://` URLs. After the main URL body,
/// trailing punctuation that is unlikely to be part of the URL
/// (`.` `,` `)` `]` `>` `!` `?` `;` `:`) is stripped.
final RegExp urlPattern = RegExp(
  r'https?://[^\s)\]>]+',
  caseSensitive: false,
);

/// Characters that are commonly appended after a URL in prose
/// and should be stripped from the match.
final RegExp _trailingPunctuation = RegExp(r'[.,)>\]!?;:]+$');

/// Extract the first URL from [text], or `null` if none found.
///
/// Strips trailing punctuation that is unlikely to be part of the URL.
String? extractFirstUrl(String text) {
  final match = urlPattern.firstMatch(text);
  if (match == null) return null;
  return _cleanUrl(match.group(0)!);
}

/// Extract all URLs from [text].
List<String> extractAllUrls(String text) {
  return urlPattern
      .allMatches(text)
      .map((m) => _cleanUrl(m.group(0)!))
      .toList();
}

/// Strip trailing punctuation from a URL match.
String _cleanUrl(String raw) {
  return raw.replaceAll(_trailingPunctuation, '');
}

/// Fetches Open Graph / HTML meta tags from a URL and returns
/// structured [LinkMetadata].
///
/// Uses a standalone [Dio] instance (no auth interceptor) to
/// fetch external pages.
class LinkPreviewService {
  LinkPreviewService({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 10),
              headers: {
                'User-Agent': 'Mozilla/5.0 (compatible; SlockBot/1.0)',
                'Accept': 'text/html',
              },
              // Only accept HTML content, limit response size.
              responseType: ResponseType.plain,
            ));

  final Dio _dio;

  /// Fetch metadata for the given [url].
  ///
  /// Returns `null` if the page was fetched successfully but contains
  /// no usable OG/meta tags (permanent — safe to cache).
  ///
  /// Throws on network errors or non-200 responses so callers can
  /// distinguish transient failures from genuine "no metadata" results.
  Future<LinkMetadata?> fetchMetadata(String url) async {
    final response = await _dio.get<String>(
      url,
      options: Options(
        // Follow redirects, accept HTML.
        followRedirects: true,
        maxRedirects: 5,
        // Limit received data to ~512KB to avoid huge pages.
        receiveTimeout: const Duration(seconds: 10),
      ),
    );

    if (response.statusCode != 200 || response.data == null) {
      return null;
    }

    return _parseHtml(response.data!, url);
  }

  /// Parse HTML content to extract OG and meta tags.
  LinkMetadata? _parseHtml(String html, String url) {
    final document = html_parser.parse(html);
    final metaTags = document.getElementsByTagName('meta');

    String? ogTitle;
    String? ogDescription;
    String? ogImage;
    String? metaDescription;
    String? pageTitle;

    // Extract <title> tag.
    final titleElements = document.getElementsByTagName('title');
    if (titleElements.isNotEmpty) {
      pageTitle = titleElements.first.text.trim();
    }

    // Extract meta/OG tags.
    for (final tag in metaTags) {
      final property = tag.attributes['property']?.toLowerCase();
      final name = tag.attributes['name']?.toLowerCase();
      final content = tag.attributes['content'];

      if (content == null || content.isEmpty) continue;

      if (property == 'og:title') {
        ogTitle = content.trim();
      } else if (property == 'og:description') {
        ogDescription = content.trim();
      } else if (property == 'og:image') {
        ogImage = content.trim();
      } else if (name == 'description') {
        metaDescription = content.trim();
      }
    }

    // Title: prefer OG, fall back to <title>.
    final title = ogTitle ?? pageTitle ?? '';
    if (title.isEmpty) return null;

    // Description: prefer OG, fall back to meta description.
    final description = ogDescription ?? metaDescription;

    // Resolve relative image URLs.
    String? imageUrl = ogImage;
    if (imageUrl != null && imageUrl.startsWith('/')) {
      final uri = Uri.tryParse(url);
      if (uri != null) {
        imageUrl = '${uri.scheme}://${uri.host}$imageUrl';
      }
    }

    // Extract domain.
    final domain = Uri.tryParse(url)?.host ?? url;

    return LinkMetadata(
      url: url,
      title: title,
      description: description,
      imageUrl: imageUrl,
      domain: domain,
    );
  }
}
