import 'package:flutter_test/flutter_test.dart';
import 'package:learning_vault/core/utils/url_normalizer.dart';

void main() {
  group('UrlNormalizer', () {
    test('removes tracking query parameters (utm_*, fbclid, gclid, etc.)', () {
      const url = 'https://medium.com/swlh/deep-learning-intro?utm_source=twitter&utm_medium=social&fbclid=IwAR12345';
      final normalized = UrlNormalizer.normalize(url);
      expect(normalized, 'https://medium.com/swlh/deep-learning-intro');
    });

    test('preserves important query parameters like YouTube video ID', () {
      const url = 'https://www.youtube.com/watch?v=dQw4w9WgXcQ&si=tracking123&utm_source=share';
      final normalized = UrlNormalizer.normalize(url);
      expect(normalized, 'https://youtube.com/watch?v=dQw4w9WgXcQ');
    });

    test('lowercases scheme and host and strips www prefix', () {
      const url = 'HTTP://WWW.GITHUB.COM/flutter/flutter';
      final normalized = UrlNormalizer.normalize(url);
      expect(normalized, 'https://github.com/flutter/flutter');
    });

    test('strips trailing slashes from path', () {
      const url = 'https://docs.flutter.dev/get-started/';
      final normalized = UrlNormalizer.normalize(url);
      expect(normalized, 'https://docs.flutter.dev/get-started');
    });

    test('extracts clean domain correctly', () {
      expect(UrlNormalizer.extractDomain('https://www.nytimes.com/section/world'), 'nytimes.com');
      expect(UrlNormalizer.extractDomain('https://github.com/torvalds/linux'), 'github.com');
      expect(UrlNormalizer.extractDomain('invalid-url'), '');
    });
  });
}
