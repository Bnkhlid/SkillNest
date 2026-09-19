/// URL Normalization Utility for SkillNest.
/// Cleans, standardizes, and normalizes URLs to enable accurate duplicate detection
/// without altering the underlying target destination.
class UrlNormalizer {
  static const Set<String> _trackingParams = {
    'utm_source',
    'utm_medium',
    'utm_campaign',
    'utm_term',
    'utm_content',
    'fbclid',
    'gclid',
    'dclid',
    'msclkid',
    'mc_cid',
    'mc_eid',
    'igshid',
    'si', // YouTube Share ID parameter
    'feature',
    'ref',
    'ref_src',
  };

  /// Normalizes a raw URL string into a canonical representation.
  /// Returns empty string if input is blank or invalid.
  static String normalize(String rawUrl) {
    var trimmed = rawUrl.trim();
    if (trimmed.isEmpty) return '';

    // Add https:// scheme if missing so Uri can parse host properly
    if (!trimmed.contains('://')) {
      trimmed = 'https://$trimmed';
    }

    final uri = Uri.tryParse(trimmed);
    if (uri == null || uri.host.isEmpty) return rawUrl.trim();

    var scheme = uri.scheme.toLowerCase();
    if (scheme == 'http') scheme = 'https';
    var host = uri.host.toLowerCase();
    if (host.startsWith('www.')) {
      host = host.substring(4);
    }

    // Clean and filter query parameters
    final cleanParams = <String, String>{};
    if (uri.hasQuery) {
      uri.queryParameters.forEach((key, value) {
        final lowerKey = key.toLowerCase();
        if (!_trackingParams.contains(lowerKey) && !lowerKey.startsWith('utm_')) {
          cleanParams[key] = value;
        }
      });
    }

    // Normalize path: collapse duplicate slashes and remove trailing slash for root or simple paths
    var path = uri.path;
    if (path == '/' && cleanParams.isEmpty) {
      path = '';
    } else if (path.endsWith('/') && path.length > 1) {
      path = path.substring(0, path.length - 1);
    }

    // Build canonical URI
    final normalizedUri = Uri(
      scheme: scheme,
      userInfo: uri.userInfo.isEmpty ? null : uri.userInfo,
      host: host,
      port: (uri.hasPort && uri.port != 80 && uri.port != 443) ? uri.port : null,
      path: path.isEmpty ? null : path,
      queryParameters: cleanParams.isEmpty ? null : cleanParams,
    );

    return normalizedUri.toString();
  }

  /// Extracts clean domain name for display (e.g. "youtube.com").
  static String extractDomain(String url) {
    if (url.trim().isEmpty) return '';
    var trimmed = url.trim();
    if (!trimmed.contains('://')) trimmed = 'https://$trimmed';
    final uri = Uri.tryParse(trimmed);
    if (uri == null || uri.host.isEmpty || !uri.host.contains('.')) return '';
    var host = uri.host.toLowerCase();
    if (host.startsWith('www.')) host = host.substring(4);
    return host;
  }
}
