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
  String get errorJkanimeParse =>
      'La estructura de JKAnime cambio y no se pudieron interpretar los links de forma segura.';

  @override
  String get errorJkanimeInconsistent =>
      'JKAnime devolvio datos de servidores inconsistentes para este episodio.';

  @override
  String get errorJkanimeEmpty =>
      'JKAnime no tiene datos para este item en este momento.';

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
  String get resolveServerLink => 'Resolver';

  @override
  String get resolverResolving => 'Resolviendo enlace de stream...';

  @override
  String get resolverNoResolverFound =>
      'No hay resolver disponible para este server link.';

  @override
  String get resolverAmbiguousSelection =>
      'Mas de un resolver coincide con este link con la misma prioridad.';

  @override
  String get resolverMalformedLink =>
      'El enlace de origen es invalido y no se puede resolver.';

  @override
  String get resolverParseFailure =>
      'El resolver no pudo extraer un stream valido del payload.';

  @override
  String get resolverInconsistentPayload =>
      'El resolver recibio un payload inconsistente del proveedor.';

  @override
  String get resolverTransportFailure =>
      'La solicitud del resolver fallo por transporte/red.';

  @override
  String get resolverUnexpectedFailure =>
      'Error inesperado al resolver el enlace.';

  @override
  String get resolverNoStreams =>
      'El resolver no devolvio candidatos de stream.';

  @override
  String resolverPageTitle(
    Object animeTitle,
    Object episodeNumber,
    Object serverName,
  ) {
    return '$animeTitle Ep.$episodeNumber | Resolver $serverName';
  }

  @override
  String resolverQuality(Object quality) {
    return 'Calidad: $quality';
  }

  @override
  String get resolverQualityUnknown => 'desconocida';

  @override
  String resolverMediaType(Object type) {
    return 'Tipo: $type';
  }

  @override
  String get resolverTypeHls => 'HLS';

  @override
  String get resolverTypeMp4 => 'MP4';

  @override
  String resolverMimeType(Object mimeType) {
    return 'MIME: $mimeType';
  }

  @override
  String resolverHeader(Object name, Object value) {
    return 'Header $name: $value';
  }

  @override
  String resolverUsed(Object resolverName) {
    return 'Resuelto por: $resolverName';
  }

  @override
  String get openPlayer => 'Abrir player';

  @override
  String get playerTitle => 'Player';

  @override
  String playerEpisodeTitle(Object animeTitle, Object episodeNumber) {
    return '$animeTitle - Episodio $episodeNumber';
  }

  @override
  String get playerLoading => 'Abriendo reproduccion...';

  @override
  String playerCandidatePosition(Object current, Object total) {
    return 'Candidato $current de $total';
  }

  @override
  String playerCurrentStream(Object url) {
    return 'Stream actual: $url';
  }

  @override
  String get playerPlay => 'Reproducir';

  @override
  String get playerPause => 'Pausar';

  @override
  String get playerNoPlayableStream =>
      'No hay un stream reproducible disponible.';

  @override
  String get playerUnsupportedStream =>
      'El stream seleccionado no es compatible con este player.';

  @override
  String get playerOpenFailed =>
      'El player no pudo abrir el stream seleccionado.';

  @override
  String get playerOpenTimeout =>
      'Se agoto el tiempo de apertura de reproduccion.';

  @override
  String get playerBufferingTimeout =>
      'El buffering tomo demasiado tiempo. Se intentara fallback si existe.';

  @override
  String get playerNetworkFailure => 'Fallo de red al abrir la reproduccion.';

  @override
  String get playerCandidateFailedTryingFallback =>
      'Este stream fallo. Probando otro candidato.';

  @override
  String get playerAllCandidatesFailed =>
      'Todos los candidatos de stream fallaron.';

  @override
  String get playerPlaybackErrorGeneric => 'Ocurrio un error de reproduccion.';

  @override
  String playerPlaybackError(Object reason) {
    return 'Error de reproduccion: $reason';
  }

  @override
  String get jkanimeServerLinksLoading =>
      'Cargando enlaces de servidores de JKAnime...';

  @override
  String get jkanimeServerLinksEmpty =>
      'No se encontraron servidores para este episodio en JKAnime.';

  @override
  String get jkanimeLinkTypeStream => 'STREAM';

  @override
  String get jkanimeLinkTypeDownload => 'DESCARGA';

  @override
  String get jkanimeDownloadOnly => 'Descargar';

  @override
  String jkanimeDetectedHost(Object host) {
    return 'Host: $host';
  }

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
