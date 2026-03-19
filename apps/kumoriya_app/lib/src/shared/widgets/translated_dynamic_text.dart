import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../dynamic_translation.dart';

class TranslatedDynamicText extends ConsumerWidget {
  const TranslatedDynamicText(
    this.text, {
    super.key,
    this.style,
    this.maxLines,
    this.overflow,
    this.textAlign,
  });

  final String text;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = Localizations.maybeLocaleOf(context);
    final languageCode = locale?.languageCode ?? 'en';
    final translatedState = ref.watch(
      translatedDynamicTextProvider((text: text, targetLanguage: languageCode)),
    );
    final resolvedText = translatedState.maybeWhen(
      data: (value) => value,
      orElse: () => text,
    );

    return Text(
      resolvedText,
      style: style,
      maxLines: maxLines,
      overflow: overflow,
      textAlign: textAlign,
    );
  }
}
