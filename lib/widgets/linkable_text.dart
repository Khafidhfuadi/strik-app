import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:get/get.dart';

class LinkableText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextStyle? linkStyle;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign textAlign;

  const LinkableText(
    this.text, {
    super.key,
    this.style,
    this.linkStyle,
    this.maxLines,
    this.overflow,
    this.textAlign = TextAlign.start,
  });

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) return const SizedBox.shrink();

    // Regex to detect urls starting with http://, https://, or www.
    final RegExp urlRegex = RegExp(
      r'((https?:\/\/|www\.)[^\s\n]+)',
      caseSensitive: false,
    );

    final List<InlineSpan> spans = [];
    int start = 0;

    final matches = urlRegex.allMatches(text);

    for (final match in matches) {
      // Add text before the link
      if (match.start > start) {
        spans.add(TextSpan(
          text: text.substring(start, match.start),
          style: style,
        ));
      }

      final String urlText = match.group(0)!;
      final String launchUrlText = urlText.toLowerCase().startsWith('www.')
          ? 'https://$urlText'
          : urlText;

      spans.add(TextSpan(
        text: urlText,
        style: linkStyle ??
            (style ?? const TextStyle()).copyWith(
              color: Colors.cyanAccent,
              decoration: TextDecoration.underline,
              fontWeight: FontWeight.w600,
            ),
        recognizer: TapGestureRecognizer()
          ..onTap = () async {
            try {
              final Uri uri = Uri.parse(launchUrlText);
              final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
              if (!launched) {
                await launchUrl(uri, mode: LaunchMode.platformDefault);
              }
            } catch (e) {
              Get.snackbar(
                'Error',
                'Gagal membuka link: $urlText',
                snackPosition: SnackPosition.BOTTOM,
              );
            }
          },
      ));

      start = match.end;
    }

    // Add remaining text
    if (start < text.length) {
      spans.add(TextSpan(
        text: text.substring(start),
        style: style,
      ));
    }

    return RichText(
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow ?? (maxLines != null ? TextOverflow.ellipsis : TextOverflow.clip),
      text: TextSpan(
        children: spans,
      ),
    );
  }
}
