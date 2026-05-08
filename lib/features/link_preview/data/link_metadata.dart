/// Metadata extracted from a URL's Open Graph / HTML meta tags.
class LinkMetadata {
  const LinkMetadata({
    required this.url,
    required this.title,
    this.description,
    this.imageUrl,
    required this.domain,
  });

  /// The original URL that was fetched.
  final String url;

  /// Page title (from `og:title` or `<title>`).
  final String title;

  /// Page description (from `og:description` or `<meta name="description">`).
  final String? description;

  /// Preview image URL (from `og:image`).
  final String? imageUrl;

  /// Domain extracted from the URL (e.g. `example.com`).
  final String domain;

  /// Whether the metadata has enough content to display a preview card.
  bool get isDisplayable => title.isNotEmpty;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LinkMetadata &&
          runtimeType == other.runtimeType &&
          url == other.url &&
          title == other.title &&
          description == other.description &&
          imageUrl == other.imageUrl &&
          domain == other.domain;

  @override
  int get hashCode => Object.hash(url, title, description, imageUrl, domain);

  @override
  String toString() =>
      'LinkMetadata(url: $url, title: $title, domain: $domain)';
}
