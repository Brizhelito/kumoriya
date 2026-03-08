// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'Kumoriya';

  @override
  String get retry => 'Reintentar';

  @override
  String get loadingGeneric => 'Cargando...';

  @override
  String unexpectedStateError(Object error) {
    return 'Error de estado inesperado: $error';
  }

  @override
  String get errorTransportAnilist =>
      'No se pudo conectar con AniList. Revisa tu conexion y vuelve a intentar.';

  @override
  String get errorMappingAnilist =>
      'AniList devolvio datos que no se pudieron interpretar de forma segura.';

  @override
  String get errorNotFoundAnilist => 'No se encontro el anime en AniList.';

  @override
  String get errorUnexpectedAnilist =>
      'Error inesperado al cargar datos desde AniList.';

  @override
  String get errorTransportSource =>
      'No se pudo conectar con la fuente. Intenta de nuevo en unos momentos.';

  @override
  String get errorMappingSource =>
      'La respuesta de la fuente cambio y no se pudo interpretar de forma segura.';

  @override
  String get errorNotFoundSource =>
      'No se encontraron datos en la fuente para esta consulta.';

  @override
  String get errorUnexpectedSource =>
      'Error inesperado en la fuente al cargar datos.';

  @override
  String get homeLoadingCatalog => 'Cargando catalogo principal...';

  @override
  String get homeEmptyCatalog =>
      'No se encontraron animes en tendencia en AniList en este momento.';

  @override
  String get searchTitle => 'Buscar en AniList';

  @override
  String get searchHintTitle => 'Buscar titulo de anime';

  @override
  String get searchEmptyPrompt =>
      'Escribe un titulo y toca buscar para consultar AniList.';

  @override
  String get searchLoading => 'Buscando en AniList...';

  @override
  String searchNoResults(Object query) {
    return 'No se encontraron resultados en AniList para \"$query\".';
  }

  @override
  String get animeDetailTitle => 'Detalle del anime';

  @override
  String get animeDetailLoading => 'Cargando detalle del anime...';

  @override
  String get viewEpisodeList => 'Ver lista de episodios';

  @override
  String get episodesWord => 'episodios';

  @override
  String get episodePreviewTitle => 'Vista previa de episodios';

  @override
  String get episodeStatusAired => 'Emitido';

  @override
  String get episodeStatusUpcoming => 'Proximo';

  @override
  String get relationsTitle => 'Relaciones';

  @override
  String episodeListTitle(Object animeTitle) {
    return 'Episodios de $animeTitle';
  }

  @override
  String get episodeListLoading => 'Cargando episodios...';

  @override
  String get episodeListEmpty =>
      'AniList todavia no tiene metadatos de episodios para este anime.';

  @override
  String get episodeMetadataAired => 'Metadato emitido';

  @override
  String get episodeMetadataUpcoming => 'Metadato proximo';

  @override
  String get jkanimeAvailabilityTitle => 'Disponibilidad en JKAnime';

  @override
  String get jkanimeChecking => 'Verificando disponibilidad en JKAnime...';

  @override
  String jkanimeErrorConsulting(Object error) {
    return 'Error consultando JKAnime: $error';
  }

  @override
  String jkanimeNotAvailable(Object reason) {
    return 'No disponible en JKAnime ($reason)';
  }

  @override
  String get jkanimeNotAvailableSimple => 'No disponible en JKAnime';

  @override
  String get jkanimeNotAvailableNoMatch =>
      'No se encontro un match confiable en JKAnime.';

  @override
  String get jkanimeNotAvailableNoEpisodes =>
      'Hay match en JKAnime, pero no se encontraron episodios.';

  @override
  String get jkanimeAvailable => 'Disponible en JKAnime';

  @override
  String jkanimeRealEpisodesFound(int count) {
    return 'Episodios reales encontrados: $count';
  }

  @override
  String get jkanimeViewRealEpisodes => 'Ver episodios reales de JKAnime';

  @override
  String get viewServerLinks => 'Ver servidores';

  @override
  String get jkanimeServerLinksLoading =>
      'Cargando enlaces de servidores de JKAnime...';

  @override
  String get jkanimeServerLinksEmpty =>
      'No se encontraron servidores para este episodio en JKAnime.';

  @override
  String jkanimeServerLinksTitle(Object animeTitle, Object episodeNumber) {
    return '$animeTitle | Servidores episodio $episodeNumber';
  }

  @override
  String jkanimeEpisodesTitle(Object animeTitle) {
    return 'Episodios JKAnime | $animeTitle';
  }

  @override
  String animeListEpisodesShort(int count) {
    return '$count eps';
  }
}
