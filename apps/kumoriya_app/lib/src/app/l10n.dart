import 'package:flutter/widgets.dart';
import 'package:kumoriya_app/l10n/generated/app_localizations.dart';

extension KumoriyaL10nX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
