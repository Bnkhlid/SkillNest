import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../utils/url_normalizer.dart';

class ResourceMetadata {
  final String? title;
  final String? description;
  final String? thumbnailUrl;
  final String? siteName;
  final String? author;
  final String? resourceType;

  const ResourceMetadata({
    this.title,
    this.description,
    this.thumbnailUrl,
    this.siteName,
    this.author,
    this.resourceType,
  });

  bool get isEmpty =>
      title == null &&
      description == null &&
      thumbnailUrl == null &&
      siteName == null &&
      author == null;

  @override
  String toString() =>
      'ResourceMetadata(title: $title, site: $siteName, type: $resourceType, thumbnail: $thumbnailUrl)';
}

class HtmlMetadataParser {
  static ResourceMetadata parse(String html, {String? sourceUrl}) {
    if (html.trim().isEmpty) {
      final domain = sourceUrl != null ? UrlNormalizer.extractDomain(sourceUrl) : null;
      final inferredType = _inferResourceType(sourceUrl, null);
      return ResourceMetadata(siteName: domain, resourceType: inferredType);
    }

    // 1. Title Extraction
    final ogTitle = _extractMeta(html, 'og:title');
    final twitterTitle = _extractMeta(html, 'twitter:title');
    final htmlTitle = _extractTitleTag(html);
    final title = ogTitle ?? twitterTitle ?? htmlTitle;

    // 2. Description Extraction
    final ogDesc = _extractMeta(html, 'og:description');
    final metaDesc = _extractMeta(html, 'description');
    final twitterDesc = _extractMeta(html, 'twitter:description');
    final description = ogDesc ?? metaDesc ?? twitterDesc;

    // 3. Image / Thumbnail Extraction
    final ogImage = _extractMeta(html, 'og:image');
    final twitterImage = _extractMeta(html, 'twitter:image');
    var image = ogImage ?? twitterImage;
    if (image != null && sourceUrl != null && !image.startsWith('http://') && !image.startsWith('https://')) {
      // Resolve relative image URLs
      final baseUri = Uri.tryParse(sourceUrl);
      if (baseUri != null) {
        image = baseUri.resolve(image).toString();
      }
    }

    // 4. Site Name
    final ogSite = _extractMeta(html, 'og:site_name');
    final domain = sourceUrl != null ? UrlNormalizer.extractDomain(sourceUrl) : null;
    final siteName = ogSite ?? domain;

    // 5. Author
    final metaAuthor = _extractMeta(html, 'author') ?? _extractMeta(html, 'article:author');

    // 6. Resource Type Classification
    final ogType = _extractMeta(html, 'og:type');
    final inferredType = _inferResourceType(sourceUrl, ogType);

    return ResourceMetadata(
      title: title,
      description: description,
      thumbnailUrl: image,
      siteName: siteName,
      author: metaAuthor,
      resourceType: inferredType,
    );
  }

  static String? _extractMeta(String html, String key) {
    // Pattern 1: property/name="key" ... content="value"
    final p1 = RegExp(
      '''<meta[^>]+(?:property|name)=["']${RegExp.escape(key)}["'][^>]+content=["']([^"']*)["']''',
      caseSensitive: false,
    );
    var match = p1.firstMatch(html);
    if (match != null && match.group(1) != null) {
      final value = _clean(match.group(1)!);
      if (value.isNotEmpty) return value;
    }

    // Pattern 2: content="value" ... property/name="key"
    final p2 = RegExp(
      '''<meta[^>]+content=["']([^"']*)["'][^>]+(?:property|name)=["']${RegExp.escape(key)}["']''',
      caseSensitive: false,
    );
    match = p2.firstMatch(html);
    if (match != null && match.group(1) != null) {
      final value = _clean(match.group(1)!);
      if (value.isNotEmpty) return value;
    }

    return null;
  }

  static String? _extractTitleTag(String html) {
    final p = RegExp(r'<title[^>]*>(.*?)</title>', caseSensitive: false, dotAll: true);
    final match = p.firstMatch(html);
    if (match != null && match.group(1) != null) {
      final value = _clean(match.group(1)!);
      if (value.isNotEmpty) return value;
    }
    return null;
  }

  static String? _inferResourceType(String? url, String? ogType) {
    if (url == null) return null;
    final lower = url.toLowerCase();

    if (lower.contains('youtube.com') || lower.contains('youtu.be') || lower.contains('vimeo.com') || ogType == 'video.other' || ogType == 'video') {
      return 'video';
    }
    if (lower.contains('github.com') || lower.contains('gitlab.com')) {
      return 'repository';
    }
    if (lower.contains('instagram.com') || lower.contains('tiktok.com') || lower.contains('twitter.com') || lower.contains('x.com')) {
      return 'social';
    }
    if (lower.endsWith('.pdf')) {
      return 'pdf';
    }
    if (ogType == 'article' || lower.contains('/blog/') || lower.contains('/posts/') || lower.contains('/article/')) {
      return 'article';
    }
    return 'page';
  }

  static String _clean(String input) {
    return decodeHtmlEntities(input.replaceAll(RegExp(r'\s+'), ' ').trim());
  }

  static String decodeHtmlEntities(String input) {
    return input
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'")
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&mdash;', '—')
        .replaceAll('&ndash;', '–')
        .replaceAll('&#8211;', '–')
        .replaceAll('&#8212;', '—')
        .replaceAll('&#8216;', '‘')
        .replaceAll('&#8217;', '’')
        .replaceAll('&#8220;', '“')
        .replaceAll('&#8221;', '”')
        .replaceAllMapped(RegExp(r'&#(\d+);'), (match) {
          final code = int.tryParse(match.group(1)!);
          return code != null ? String.fromCharCode(code) : match.group(0)!;
        })
        .replaceAllMapped(RegExp(r'&#x([0-9a-fA-F]+);'), (match) {
          final code = int.tryParse(match.group(1)!, radix: 16);
          return code != null ? String.fromCharCode(code) : match.group(0)!;
        });
  }
}

class MetadataService {
  MetadataService._();
  static final MetadataService instance = MetadataService._();

  static const _userAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36 SkillNest/1.0';

  Future<ResourceMetadata> fetchMetadata(
    String url, {
    Duration timeout = const Duration(seconds: 8),
    HttpClient? customClient,
  }) async {
    final cleanUrl = UrlNormalizer.normalize(url);
    if (cleanUrl.isEmpty) {
      return const ResourceMetadata();
    }

    final client = customClient ?? (HttpClient()..connectionTimeout = timeout);

    try {
      final uri = Uri.tryParse(cleanUrl);
      if (uri == null || (!uri.isScheme('http') && !uri.isScheme('https'))) {
        return ResourceMetadata(siteName: UrlNormalizer.extractDomain(cleanUrl));
      }

      final request = await client.getUrl(uri).timeout(timeout);
      request.headers.set('User-Agent', _userAgent);
      request.headers.set('Accept', 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8');
      request.headers.set('Accept-Language', 'en-US,en;q=0.5');
      request.followRedirects = true;
      request.maxRedirects = 5;

      final response = await request.close().timeout(timeout);
      if (response.statusCode >= 200 && response.statusCode < 400) {
        final body = await response.transform(utf8.decoder).join().timeout(timeout);
        return HtmlMetadataParser.parse(body, sourceUrl: cleanUrl);
      }
    } catch (_) {
      // Return safe fallback without throwing
    } finally {
      if (customClient == null) {
        client.close(force: true);
      }
    }

    // Graceful fallback on network error, offline, or timeout
    final domain = UrlNormalizer.extractDomain(cleanUrl);
    return ResourceMetadata(siteName: domain);
  }
}
