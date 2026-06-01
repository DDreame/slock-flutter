import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Share platform wiring', () {
    test(
        'Android manifest registers text, image, video, and generic file share intents',
        () {
      final manifest =
          File('android/app/src/main/AndroidManifest.xml').readAsStringSync();

      expect(manifest, contains('android.intent.action.SEND'));
      expect(manifest, contains('android.intent.action.SEND_MULTIPLE'));
      expect(manifest, contains('android:mimeType="text/*"'));
      expect(manifest, contains('android:mimeType="image/*"'));
      expect(manifest, contains('android:mimeType="video/*"'));
      expect(
        RegExp(r'android:mimeType="\*/\*"').allMatches(manifest),
        hasLength(greaterThanOrEqualTo(2)),
        reason: 'single and multi-share filters must accept arbitrary files',
      );
    });

    test(
        'iOS Runner and ShareExtension share the app group and ShareMedia callback scheme',
        () {
      final runnerInfo = File('ios/Runner/Info.plist').readAsStringSync();
      final runnerEntitlements =
          File('ios/Runner/Runner.entitlements').readAsStringSync();
      final extensionInfo =
          File('ios/ShareExtension/Info.plist').readAsStringSync();
      final extensionEntitlements =
          File('ios/ShareExtension/ShareExtension.entitlements')
              .readAsStringSync();
      final project =
          File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync();

      expect(runnerInfo, contains('<key>AppGroupId</key>'));
      expect(runnerInfo, contains('group.app.slock.shared'));
      expect(runnerInfo, contains(r'ShareMedia-$(PRODUCT_BUNDLE_IDENTIFIER)'));
      expect(runnerEntitlements, contains('group.app.slock.shared'));
      expect(extensionInfo, contains('<key>AppGroupId</key>'));
      expect(extensionInfo, contains('group.app.slock.shared'));
      expect(extensionEntitlements, contains('group.app.slock.shared'));
      expect(project, contains('ShareExtension.appex in Embed App Extensions'));
      expect(project, contains('com.apple.product-type.app-extension'));
    });

    test('iOS ShareExtension writes receive_sharing_intent compatible payload',
        () {
      final swift = File('ios/ShareExtension/ShareViewController.swift')
          .readAsStringSync();

      expect(swift, contains('userDefaultsKey = "ShareKey"'));
      expect(swift, contains('userDefaultsMessageKey = "ShareMessageKey"'));
      expect(swift, contains('JSONEncoder().encode(items)'));
      expect(swift, contains('ShareMedia-\\(hostBundleIdentifier):share'));
      expect(swift, contains('if #available(iOS 18.0, *)'));
      expect(
          swift,
          contains(
              'application.open(url, options: [:], completionHandler: nil)'));
      expect(swift, contains('sel_registerName("openURL:")'));
      expect(swift, contains('copyToSharedContainer'));
      expect(swift, isNot(contains('forKey: "SharedMedia"')));
    });

    test('iOS ShareExtension has localized share sheet display names', () {
      expect(
        File('ios/ShareExtension/en.lproj/InfoPlist.strings')
            .readAsStringSync(),
        contains('Share to Slock'),
      );
      expect(
        File('ios/ShareExtension/es.lproj/InfoPlist.strings')
            .readAsStringSync(),
        contains('Compartir en Slock'),
      );
      expect(
        File('ios/ShareExtension/zh.lproj/InfoPlist.strings')
            .readAsStringSync(),
        contains('分享到 Slock'),
      );
    });
  });
}
