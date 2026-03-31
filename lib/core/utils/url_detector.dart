class UrlDetector {
  // 常见的顶级域名后缀
  static const List<String> _commonTlds = [
    'com', 'cn', 'org', 'net', 'edu', 'gov', 'mil', 'int',
    'co', 'io', 'ai', 'me', 'tv', 'cc', 'tk', 'ml', 'ga',
    'cf', 'biz', 'info', 'name', 'pro', 'aero', 'asia',
    'cat', 'coop', 'jobs', 'mobi', 'museum', 'tel', 'travel',
    // 国家域名
    'uk', 'us', 'de', 'fr', 'jp', 'kr', 'in', 'au', 'ca',
    'br', 'ru', 'it', 'es', 'mx', 'nl', 'se', 'no', 'dk',
    'fi', 'pl', 'tr', 'za', 'eg', 'il', 'th', 'sg', 'my',
    'ph', 'vn', 'id', 'pk', 'bd', 'lk', 'np', 'mm', 'kh',
    'la', 'bt', 'mv', 'af', 'ir', 'iq', 'sy', 'lb', 'jo',
    'sa', 'ae', 'kw', 'qa', 'bh', 'om', 'ye', 'ps',
    // 中国特殊域名
    'com.cn', 'net.cn', 'org.cn', 'gov.cn', 'edu.cn',
  ];

  // 创建TLD模式字符串
  static String get _tldPattern {
    // 对包含点的TLD（如com.cn）进行特殊处理
    final dotTlds = _commonTlds.where((tld) => tld.contains('.')).toList();
    final simpleTlds = _commonTlds.where((tld) => !tld.contains('.')).toList();
    
    final dotTldPattern = dotTlds.map((tld) => tld.replaceAll('.', r'\.')).join('|');
    final simpleTldPattern = simpleTlds.join('|');
    
    return '(?:$dotTldPattern|$simpleTldPattern)';
  }

  // 完整的URL匹配正则表达式
  static RegExp get urlPattern {
    return RegExp(
      r'(?:'
      // 1. 完整的HTTP/HTTPS链接
      r'https?://[^\s<>"{}|\\^`\[\]]+'
      r'|'
      // 2. www开头的域名
      r'www\.(?:[a-zA-Z0-9-]+\.)*[a-zA-Z0-9-]+\.(?:' + _tldPattern + r')(?:[^\s<>"{}|\\^`\[\]]*)'
      r'|'
      // 3. 普通域名（包含常见TLD）
      r'(?:[a-zA-Z0-9-]+\.)+(?:' + _tldPattern + r')(?:[^\s<>"{}|\\^`\[\]]*)'
      r')',
      caseSensitive: false,
    );
  }

  // 检查字符串是否为有效URL
  static bool isValidUrl(String text) {
    final matches = urlPattern.allMatches(text);
    return matches.any((match) => match.group(0) == text.trim());
  }

  // 从文本中提取所有URL
  static List<UrlMatch> extractUrls(String text) {
    final matches = urlPattern.allMatches(text);
    return matches.map((match) {
      final url = match.group(0)!;
      return UrlMatch(
        url: url,
        start: match.start,
        end: match.end,
        normalizedUrl: _normalizeUrl(url),
      );
    }).toList();
  }

  // 标准化URL（添加协议等）
  static String _normalizeUrl(String url) {
    // 如果已经有协议，直接返回
    if (url.startsWith(RegExp(r'https?://', caseSensitive: false))) {
      return url;
    }
    
    // 对于www开头或普通域名，添加https://
    if (url.startsWith(RegExp(r'www\.', caseSensitive: false))) {
      return '#$url';
    }
    
    // 检查是否是有效的域名格式
    if (_isValidDomain(url)) {
      return '#$url';
    }
    
    return url;
  }

  // 检查是否为有效域名
  static bool _isValidDomain(String domain) {
    // 基本的域名格式检查
    final domainPattern = RegExp(
      r'^(?:[a-zA-Z0-9-]+\.)+(?:' + _tldPattern + r')$',
      caseSensitive: false,
    );
    return domainPattern.hasMatch(domain);
  }

  // 获取URL的显示文本（可能截断长URL）
  static String getDisplayText(String url, {int maxLength = 50}) {
    if (url.length <= maxLength) {
      return url;
    }
    
    // 对于长URL，显示前部分...后部分
    final frontPart = url.substring(0, maxLength ~/ 2);
    final backPart = url.substring(url.length - (maxLength ~/ 2) + 3);
    return '$frontPart...$backPart';
  }
}

// URL匹配结果类
class UrlMatch {
  final String url;           // 原始URL文本
  final int start;           // 在原文本中的开始位置
  final int end;             // 在原文本中的结束位置
  final String normalizedUrl; // 标准化后的URL（添加协议等）

  UrlMatch({
    required this.url,
    required this.start,
    required this.end,
    required this.normalizedUrl,
  });

  @override
  String toString() {
    return 'UrlMatch(url: $url, start: $start, end: $end, normalized: $normalizedUrl)';
  }
}