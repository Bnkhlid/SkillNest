import 'package:flutter_test/flutter_test.dart';
import 'package:learning_vault/core/utils/share_parser.dart';
import 'package:learning_vault/core/utils/url_normalizer.dart';

void main() {
  group('ShareParser URL Extraction', () {
    test('Case A: URL only', () {
      const input = 'https://example.com';
      final result = ShareParser.extractUrl(input);
      expect(result, 'https://example.com');
    });

    test('Case B: Text containing URL', () {
      const input = 'Check this:\nhttps://example.com/article';
      final result = ShareParser.extractUrl(input);
      expect(result, 'https://example.com/article');
    });

    test('Case C: Newline with text and URL', () {
      const input = 'Amazing tutorial\n\nhttps://example.com/tutorial';
      final result = ShareParser.extractUrl(input);
      expect(result, 'https://example.com/tutorial');
    });

    test('Case D: YouTube share URL', () {
      const input = 'Watch this video: https://www.youtube.com/watch?v=abc123';
      final result = ShareParser.extractUrl(input);
      expect(result, 'https://www.youtube.com/watch?v=abc123');
    });

    test('Case E: Instagram reel URL', () {
      const input = 'Look at this reel https://www.instagram.com/reel/example/';
      final result = ShareParser.extractUrl(input);
      expect(result, 'https://www.instagram.com/reel/example/');
    });

    test('Case F: Tracking parameters extraction and subsequent normalization', () {
      const input = 'Shared via app: https://example.com/article?utm_source=twitter&utm_medium=social&utm_campaign=spring#section';
      final extracted = ShareParser.extractUrl(input);
      expect(extracted, 'https://example.com/article?utm_source=twitter&utm_medium=social&utm_campaign=spring#section');

      final normalized = UrlNormalizer.normalize(extracted!);
      expect(normalized, 'https://example.com/article');
    });

    test('Case G: Non-URL plain text returns null', () {
      expect(ShareParser.extractUrl('hello world'), isNull);
      expect(ShareParser.extractUrl('call me tomorrow at 5pm'), isNull);
      expect(ShareParser.extractUrl('123456789'), isNull);
      expect(ShareParser.extractUrl(''), isNull);
      expect(ShareParser.extractUrl(null), isNull);
    });

    test('Case H: Multiple URLs extracts the first valid URL', () {
      const input = 'Compare https://first.com/article with https://second.com/article';
      final result = ShareParser.extractUrl(input);
      expect(result, 'https://first.com/article');
    });

    test('Case I: Trims trailing punctuation from sentence context', () {
      const input = 'Check out this site: https://example.com/guide.';
      final result = ShareParser.extractUrl(input);
      expect(result, 'https://example.com/guide');

      const parenthesized = 'Read the docs (https://example.com/docs)!';
      final res2 = ShareParser.extractUrl(parenthesized);
      expect(res2, 'https://example.com/docs');
    });

    test('Case J: Browser share with title and URL on separate lines', () {
      const input = 'Understanding Modern Architecture\nhttps://blog.developer.org/posts/arch-guide';
      final result = ShareParser.extractUrl(input);
      expect(result, 'https://blog.developer.org/posts/arch-guide');
    });
  });
}
