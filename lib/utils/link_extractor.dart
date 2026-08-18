class LinkExtractor {
  // Matches http, https, and www URLs
  static final RegExp _urlRegex = RegExp(
    r'(https?:\/\/[^\s<>"]+|www\.[^\s<>"]+)',
    caseSensitive: false,
  );

  /// Extracts all valid URLs from any message body, stripping trailing punctuation.
  static List<String> extractUrls(String? text) {
    if (text == null || text.trim().isEmpty) return [];
    final matches = _urlRegex.allMatches(text);
    final urls = <String>[];
    for (final match in matches) {
      var url = match.group(0)?.trim() ?? '';
      // Strip trailing punctuation often attached in natural text/SMS (.,;:)>]})
      url = url.replaceAll(RegExp(r'''[.,;:)>\]}'"\s]+$'''), '');
      if (url.isNotEmpty && !urls.contains(url)) {
        urls.add(url);
      }
    }
    return urls;
  }

  /// Normalizes a URL for launching (prepends https:// to www. addresses if needed).
  static String normalizeUrl(String url) {
    final trimmed = url.trim();
    if (trimmed.toLowerCase().startsWith('www.')) {
      return 'https://$trimmed';
    }
    return trimmed;
  }
}
