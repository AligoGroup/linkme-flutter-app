import 'package:flutter/gestures.dart';
import 'package:linkme_flutter/core/theme/linkme_material.dart';

/// Very small HTML renderer for simple rich text used in subscription articles.
/// Supported tags: <b>/<strong>, <i>/<em>, <u>, <br>, <p>, <div>, <img src="...">.
/// Other tags are stripped. Links/table are not supported.
class LiteHtml extends StatelessWidget {
  final String html;
  final TextStyle? style;
  final TextAlign textAlign;
  final double lineHeight;
  /// Limit inline image height to avoid extremely tall content.
  final double maxImageHeight;
  const LiteHtml(this.html, {super.key, this.style, this.textAlign = TextAlign.start, this.lineHeight = 1.6, this.maxImageHeight = 360});

  @override
  Widget build(BuildContext context) {
    final base = (style ?? const TextStyle(fontSize: 16)).copyWith(height: lineHeight);
    final spans = _parse(context, html, base);
    return SelectableText.rich(TextSpan(children: spans, style: base), textAlign: textAlign);
  }

  List<InlineSpan> _parse(BuildContext context, String input, TextStyle base) {
    final spans = <InlineSpan>[];
    final tagRegex = RegExp(r"<[^>]+>");
    final tokens = <_Token>[];

    int last = 0;
    for (final m in tagRegex.allMatches(input)) {
      if (m.start > last) {
        tokens.add(_Token.text(input.substring(last, m.start)));
      }
      tokens.add(_Token.tag(input.substring(m.start, m.end)));
      last = m.end;
    }
    if (last < input.length) tokens.add(_Token.text(input.substring(last)));

    // simple stack for styles
    bool bold = false, italic = false, underline = false;
    void pushText(String t) {
      if (t.isEmpty) return;
      t = t.replaceAll('&nbsp;', ' ');
      final st = base.merge(TextStyle(
        fontWeight: bold ? FontWeight.w700 : null,
        fontStyle: italic ? FontStyle.italic : null,
        decoration: underline ? TextDecoration.underline : null,
      ));
      spans.add(TextSpan(text: t, style: st));
    }

    for (final tk in tokens) {
      if (tk.isText) {
        pushText(tk.text);
      } else {
        final tag = tk.tag.toLowerCase();
        if (tag == '<b>' || tag == '<strong>') {
          bold = true;
        } else if (tag == '</b>' || tag == '</strong>') {
          bold = false;
        } else if (tag == '<i>' || tag == '<em>') {
          italic = true;
        } else if (tag == '</i>' || tag == '</em>') {
          italic = false;
        } else if (tag == '<u>') {
          underline = true;
        } else if (tag == '</u>') {
          underline = false;
        } else if (tag.startsWith('<br')) {
          spans.add(const TextSpan(text: '\n'));
        } else if (tag == '<p>' || tag == '<div>') {
          // block start: ensure a new line if not at line start
          if (spans.isNotEmpty) spans.add(const TextSpan(text: '\n'));
        } else if (tag == '</p>' || tag == '</div>') {
          spans.add(const TextSpan(text: '\n'));
        } else if (tag.startsWith('<img')) {
          // Extract src from <img ...> and insert as a block-level image
          String? src;
          final m1 = RegExp(r'src\s*=\s*"([^"]+)"').firstMatch(tk.tag);
          if (m1 != null) {
            src = m1.group(1);
          } else {
            final m2 = RegExp(r"src\s*=\s*'([^']+)'").firstMatch(tk.tag);
            if (m2 != null) src = m2.group(1);
          }
          if (src != null && src.trim().isNotEmpty) {
            final String url = src.trim(); // capture as non-null for nested closures
            spans.add(WidgetSpan(
              alignment: PlaceholderAlignment.baseline,
              baseline: TextBaseline.alphabetic,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: LayoutBuilder(
                  builder: (context, c) {
                    final w = c.maxWidth;
                    return ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: w, maxHeight: maxImageHeight),
                      child: Image.network(
                        url,
                        width: w,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Container(
                          height: 120,
                          color: const Color(0xFFF3F4F6),
                          alignment: Alignment.center,
                          child: const Icon(Icons.broken_image, color: Color(0xFF9CA3AF)),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ));
            // Ensure a line break after image to mimic block behavior
            spans.add(const TextSpan(text: '\n'));
          }
        } else {
          // strip unknown tags
        }
      }
    }

    // normalise: collapse multiple newlines
    final normalized = <InlineSpan>[];
    String? buffer;
    for (final s in spans) {
      if (s is TextSpan && s.text != null) {
        final t = s.text!;
        buffer = (buffer ?? '') + t;
      } else {
        if (buffer != null) {
          normalized.add(TextSpan(text: _collapseNewlines(buffer)));
          buffer = null;
        }
        normalized.add(s);
      }
    }
    if (buffer != null) normalized.add(TextSpan(text: _collapseNewlines(buffer)));
    return normalized;
  }

  String _collapseNewlines(String s) {
    // Replace consecutive blank lines with a single newline
    return s.replaceAll(RegExp(r"\n{3,}"), '\n\n');
  }
}

class _Token {
  final String text;
  final String tag;
  final bool isText;
  _Token.text(this.text) : tag = '', isText = true;
  _Token.tag(this.tag) : text = '', isText = false;
}
