import 'package:linkme_flutter/core/theme/linkme_material.dart';
import 'package:flutter/gestures.dart';
import '../../core/utils/url_launcher_helper.dart';

class LinkableText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextStyle? linkStyle;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;

  const LinkableText(
    this.text, {
    super.key,
    this.style,
    this.linkStyle,
    this.maxLines,
    this.overflow,
    this.textAlign,
  });

  @override
  Widget build(BuildContext context) {
    final spans = _buildTextSpans(context);
    
    return RichText(
      text: TextSpan(children: spans),
      maxLines: maxLines,
      overflow: overflow ?? TextOverflow.visible,
      textAlign: textAlign ?? TextAlign.start,
    );
  }

  List<TextSpan> _buildTextSpans(BuildContext context) {
    final List<TextSpan> spans = [];
    final defaultStyle = style ?? DefaultTextStyle.of(context).style;
    final linkTextStyle = linkStyle ?? 
        defaultStyle.copyWith(
          color: Theme.of(context).colorScheme.primary,
          decoration: TextDecoration.underline,
        );

    // 增强的URL正则表达式，支持更多格式
    final urlPattern = RegExp(
      r'(?:'
      // 1. 完整的HTTP/HTTPS链接
      r'https?://[^\s<>"{}|\\^`\[\]]+'
      r'|'
      // 2. www开头的域名
      r'www\.(?:[a-zA-Z0-9-]+\.)*[a-zA-Z0-9-]+\.(?:com|cn|org|net|edu|gov|mil|int|co|io|ai|me|tv|cc|tk|ml|ga|cf|biz|info|name|pro|aero|asia|cat|coop|jobs|mobi|museum|tel|travel|uk|us|de|fr|jp|kr|in|au|ca|br|ru|it|es|mx|nl|se|no|dk|fi|pl|tr|za|eg|il|th|sg|my|ph|vn|id|pk|bd|lk|np|mm|kh|la|bt|mv|af|ir|iq|sy|lb|jo|sa|ae|kw|qa|bh|om|ye|ps|com\.cn|net\.cn|org\.cn|gov\.cn|edu\.cn)(?:[^\s<>"{}|\\^`\[\]]*)'
      r'|'
      // 3. 普通域名（包含常见TLD）
      r'(?:[a-zA-Z0-9-]+\.)+(?:com|cn|org|net|edu|gov|mil|int|co|io|ai|me|tv|cc|tk|ml|ga|cf|biz|info|name|pro|aero|asia|cat|coop|jobs|mobi|museum|tel|travel|uk|us|de|fr|jp|kr|in|au|ca|br|ru|it|es|mx|nl|se|no|dk|fi|pl|tr|za|eg|il|th|sg|my|ph|vn|id|pk|bd|lk|np|mm|kh|la|bt|mv|af|ir|iq|sy|lb|jo|sa|ae|kw|qa|bh|om|ye|ps|com\.cn|net\.cn|org\.cn|gov\.cn|edu\.cn)(?:[^\s<>"{}|\\^`\[\]]*)'
      r')',
      caseSensitive: false,
    );

    int currentIndex = 0;
    final matches = urlPattern.allMatches(text);

    for (final match in matches) {
      // 添加URL前的普通文本
      if (currentIndex < match.start) {
        spans.add(TextSpan(
          text: text.substring(currentIndex, match.start),
          style: defaultStyle,
        ));
      }

      // 添加URL链接
      final url = text.substring(match.start, match.end);
      final normalizedUrl = _normalizeUrl(url);
      
      spans.add(TextSpan(
        text: url,
        style: linkTextStyle,
        recognizer: TapGestureRecognizer()
          ..onTap = () {
            UrlLauncherHelper.openUrlDirectly(context, normalizedUrl);
          },
      ));

      currentIndex = match.end;
    }

    // 添加最后剩余的普通文本
    if (currentIndex < text.length) {
      spans.add(TextSpan(
        text: text.substring(currentIndex),
        style: defaultStyle,
      ));
    }

    // 如果没有找到任何链接，返回普通文本
    if (spans.isEmpty) {
      spans.add(TextSpan(
        text: text,
        style: defaultStyle,
      ));
    }

    return spans;
  }

  // 标准化URL（添加协议等）
  String _normalizeUrl(String url) {
    // 如果已经有协议，直接返回
    if (url.startsWith(RegExp(r'https?://', caseSensitive: false))) {
      return url;
    }
    
    // 对于www开头或普通域名，添加https://
    return '#$url';
  }
}