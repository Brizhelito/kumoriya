import 'package:flutter/widgets.dart';
import 'package:kumoriya_app/l10n/generated/app_localizations.dart';
import 'package:kumoriya_domain/kumoriya_domain.dart';

extension KumoriyaL10nX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

String displayGenreLabel(BuildContext context, String genre) {
  if (Localizations.localeOf(context).languageCode != 'es') {
    return genre;
  }

  return switch (genre.trim().toLowerCase()) {
    'action' => 'Accion',
    'adventure' => 'Aventura',
    'comedy' => 'Comedia',
    'drama' => 'Drama',
    'ecchi' => 'Ecchi',
    'fantasy' => 'Fantasia',
    'horror' => 'Terror',
    'mahou shoujo' => 'Magical girl',
    'mecha' => 'Mecha',
    'music' => 'Musica',
    'mystery' => 'Misterio',
    'psychological' => 'Psicologico',
    'romance' => 'Romance',
    'sci-fi' => 'Ciencia ficcion',
    'slice of life' => 'Slice of life',
    'sports' => 'Deportes',
    'supernatural' => 'Sobrenatural',
    'thriller' => 'Suspenso',
    _ => genre,
  };
}

String displayRelationTypeLabel(BuildContext context, AnimeRelationType type) {
  final spanish = Localizations.localeOf(context).languageCode == 'es';
  return switch (type) {
    AnimeRelationType.prequel => spanish ? 'Precuela' : 'Prequel',
    AnimeRelationType.sequel => spanish ? 'Secuela' : 'Sequel',
    AnimeRelationType.sideStory => spanish ? 'Historia lateral' : 'Side story',
    AnimeRelationType.adaptation => spanish ? 'Adaptacion' : 'Adaptation',
    AnimeRelationType.spinOff => 'Spin-off',
    AnimeRelationType.other => spanish ? 'Relacion' : 'Related',
  };
}

String displayFormatLabel(BuildContext context, AnimeFormat format) {
  final spanish = Localizations.localeOf(context).languageCode == 'es';
  return switch (format) {
    AnimeFormat.tv => 'TV',
    AnimeFormat.movie => spanish ? 'Pelicula' : 'Movie',
    AnimeFormat.ova => 'OVA',
    AnimeFormat.ona => 'ONA',
    AnimeFormat.special => spanish ? 'Especial' : 'Special',
    AnimeFormat.unknown => spanish ? 'Desconocido' : 'Unknown',
  };
}
