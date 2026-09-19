/// Utility to parse shared content and extract valid URLs.
class ShareParser {
  // Regex matching HTTP/HTTPS URLs, www-prefixed links, or domain-like URL structures
  static final RegExp _urlRegex = RegExp(
    r'(https?:\/\/[^\s<>"{}|\^~\[\]`]+|www\.[^\s<>"{}|\^~\[\]`]+|[a-zA-Z0-9][-a-zA-Z0-9]*\.[a-zA-Z]{2,}(?:\/[^\s<>"{}|\^~\[\]`]*)?)',
    caseSensitive: false,
  );

  static const Set<String> _trailingPunctuation = {
    '.',
    ',',
    ';',
    ':',
    '!',
    '?',
    ')',
    ']',
    '}',
    '>',
    '"',
    "'",
    '`',
    '*',
  };

  /// Extracts the first valid HTTP/HTTPS or web URL from the provided [rawText].
  /// Returns `null` if no valid URL is found.
  static String? extractUrl(String? rawText) {
    if (rawText == null || rawText.trim().isEmpty) return null;

    final matches = _urlRegex.allMatches(rawText);
    for (final match in matches) {
      var candidate = match.group(0)?.trim() ?? '';
      candidate = _trimTrailingPunctuation(candidate);

      if (candidate.isEmpty) continue;

      // Add https:// scheme if missing for URL parsing
      final hasScheme = candidate.startsWith('http://') || candidate.startsWith('https://');
      final parseableUrl = hasScheme ? candidate : 'https://$candidate';

      final uri = Uri.tryParse(parseableUrl);
      if (uri != null && uri.hasAuthority && uri.host.contains('.')) {
        final hostParts = uri.host.split('.');
        // Ensure valid TLD structure (e.g. at least 2 alpha characters for TLD)
        if (hostParts.length >= 2 && hostParts.last.length >= 2 && RegExp(r'^[a-zA-Z]+$').hasMatch(hostParts.last)) {
          // Reject obvious non-domains like pure numeric numbers or version strings without schemes
          if (!hasScheme && RegExp(r'^\d+(\.\d+)+$').hasMatch(uri.host)) {
            continue;
          }
          return hasScheme ? candidate : 'https://$candidate';
        }
      }
    }
    return null;
  }

  static String _trimTrailingPunctuation(String text) {
    var result = text;
    while (result.isNotEmpty && _trailingPunctuation.contains(result[result.length - 1])) {
      result = result.substring(0, result.length - 1);
    }
    return result;
  }
}
