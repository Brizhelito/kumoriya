import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/dynamic_translation.dart';

Future<String> resolveTranslatedEpisodeTitle({
  required WidgetRef ref,
  required String title,
  String? languageCode,
}) {
  final effectiveLanguageCode = languageCode ?? 'en';
  return ref
      .read(dynamicTranslationServiceProvider)
      .translate(text: title, targetLanguage: effectiveLanguageCode);
}
