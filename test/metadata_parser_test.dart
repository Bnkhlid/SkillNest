import 'package:flutter_test/flutter_test.dart';
import 'package:learning_vault/core/services/metadata_service.dart';

void main() {
  group('HtmlMetadataParser Unit Tests', () {
    test('OpenGraph title, description, image, and site_name extraction', () {
      const html = '''
<!DOCTYPE html>
<html>
<head>
  <meta property="og:title" content="Deep Learning with PyTorch" />
  <meta property="og:description" content="A comprehensive guide to neural networks." />
  <meta property="og:image" content="https://example.com/assets/cover.png" />
  <meta property="og:site_name" content="AI Research Hub" />
  <meta property="og:type" content="article" />
  <meta name="author" content="Dr. Jane Doe" />
</head>
<body><h1>Hello World</h1></body>
</html>
''';

      final metadata = HtmlMetadataParser.parse(html, sourceUrl: 'https://example.com/deep-learning');
      expect(metadata.title, 'Deep Learning with PyTorch');
      expect(metadata.description, 'A comprehensive guide to neural networks.');
      expect(metadata.thumbnailUrl, 'https://example.com/assets/cover.png');
      expect(metadata.siteName, 'AI Research Hub');
      expect(metadata.author, 'Dr. Jane Doe');
      expect(metadata.resourceType, 'article');
    });

    test('Standard HTML fallback tags (<title> and <meta name="description">)', () {
      const html = '''
<!DOCTYPE html>
<html>
<head>
  <title>Understanding Flutter Architecture - Developer Blog</title>
  <meta name="description" content="An in-depth article about state management." />
</head>
<body><p>Content</p></body>
</html>
''';

      final metadata = HtmlMetadataParser.parse(html, sourceUrl: 'https://blog.flutter.dev/posts/architecture');
      expect(metadata.title, 'Understanding Flutter Architecture - Developer Blog');
      expect(metadata.description, 'An in-depth article about state management.');
      expect(metadata.siteName, 'blog.flutter.dev');
      expect(metadata.resourceType, 'article');
    });

    test('Twitter Card meta tags extraction', () {
      const html = '''
<html>
<head>
  <meta name="twitter:title" content="Fast Capture with SkillNest">
  <meta name="twitter:description" content="Seamless local-first knowledge management.">
  <meta name="twitter:image" content="https://skillnest.app/og.png">
</head>
</html>
''';

      final metadata = HtmlMetadataParser.parse(html, sourceUrl: 'https://skillnest.app');
      expect(metadata.title, 'Fast Capture with SkillNest');
      expect(metadata.description, 'Seamless local-first knowledge management.');
      expect(metadata.thumbnailUrl, 'https://skillnest.app/og.png');
      expect(metadata.siteName, 'skillnest.app');
    });

    test('HTML Entities decoding in titles and descriptions', () {
      const html = '''
<html>
<head>
  <meta property="og:title" content="Tom &amp; Jerry &mdash; &quot;Best Friends&quot; &#39;Forever&#39;">
  <meta property="og:description" content="A &lt;classic&gt; cartoon &amp; fun for all.">
</head>
</html>
''';

      final metadata = HtmlMetadataParser.parse(html);
      expect(metadata.title, 'Tom & Jerry — "Best Friends" \'Forever\'');
      expect(metadata.description, 'A <classic> cartoon & fun for all.');
    });

    test('Malformed and truncated HTML does not crash', () {
      const malformed = '<head><meta property="og:title" content="Broken Tag <title>Nested</title><';
      final metadata = HtmlMetadataParser.parse(malformed, sourceUrl: 'https://broken.com');
      expect(metadata.title, isNotNull);
      expect(metadata.siteName, 'broken.com');
    });

    test('Empty HTML returns graceful domain fallback', () {
      final metadata = HtmlMetadataParser.parse('', sourceUrl: 'https://youtube.com/watch?v=1234');
      expect(metadata.title, isNull);
      expect(metadata.siteName, 'youtube.com');
      expect(metadata.resourceType, 'video');
    });

    test('Resolves relative image paths to absolute URLs using sourceUrl', () {
      const html = '''
<html>
<head>
  <meta property="og:image" content="/images/banner.jpg">
</head>
</html>
''';

      final metadata = HtmlMetadataParser.parse(html, sourceUrl: 'https://example.com/posts/flutter');
      expect(metadata.thumbnailUrl, 'https://example.com/images/banner.jpg');
    });
  });
}
