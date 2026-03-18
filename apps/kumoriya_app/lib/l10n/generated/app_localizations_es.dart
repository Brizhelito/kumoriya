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
  String get genericLoadFailure => 'Algo no cargo bien. Intenta de nuevo.';

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
  String get viewEpisodeList => 'Episodios';

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

  @override
  String get continueWatching => 'Seguir Viendo';

  @override
  String get continueWatchingHint => 'Vuelve rapido a donde lo dejaste.';

  @override
  String get continueWatchingResumeAction => 'Reanudar ahora';

  @override
  String continueWatchingEpisode(Object episode) {
    return 'Episodio $episode';
  }

  @override
  String get sourceAvailabilityTitle => 'Disponibilidad de fuentes';

  @override
  String get sourceAvailabilityChecking => 'Revisando donde puedes verlo...';

  @override
  String get sourceAvailabilityNone =>
      'Todavia no hay estado de fuentes disponible.';

  @override
  String sourceOpenRecommended(Object sourceName) {
    return 'Abrir fuente recomendada: $sourceName';
  }

  @override
  String sourceRecommended(Object sourceName) {
    return 'Se selecciono esta fuente por el orden de fallback: $sourceName';
  }

  @override
  String get sourceRecommendedShort => 'Recomendada';

  @override
  String get sourceChoosePrompt => 'Otras fuentes con match:';

  @override
  String sourceAvailableEpisodes(int count) {
    return '$count episodios reales disponibles';
  }

  @override
  String sourceNotAvailableNoMatch(Object sourceName) {
    return '$sourceName: no hubo match confiable con AniList.';
  }

  @override
  String sourceNotAvailableAmbiguous(Object sourceName) {
    return '$sourceName: el match fue ambiguo y se descarto por seguridad.';
  }

  @override
  String sourceNotAvailableNoEpisodes(Object sourceName) {
    return '$sourceName: hubo match, pero no se encontraron episodios.';
  }

  @override
  String sourceUnavailableError(Object sourceName) {
    return '$sourceName: la verificacion de la fuente fallo.';
  }

  @override
  String get sourceViewEpisodes => 'Episodios';

  @override
  String sourceEpisodesTitle(Object sourceName, Object animeTitle) {
    return 'Episodios $sourceName | $animeTitle';
  }

  @override
  String sourceServerLinksLoading(Object sourceName) {
    return 'Cargando enlaces de servidores de $sourceName...';
  }

  @override
  String sourceServerLinksTitle(
    Object sourceName,
    Object animeTitle,
    Object episodeNumber,
  ) {
    return '$sourceName | $animeTitle Servidores episodio $episodeNumber';
  }

  @override
  String sourceDetectedHost(Object host) {
    return 'Host: $host';
  }

  @override
  String get detailSynopsisTitle => 'Sinopsis';

  @override
  String get detailDiscoverPrompt =>
      'Mira rapido que esta listo antes de elegir episodio.';

  @override
  String get detailPlaybackNotReady =>
      'Este anime no esta listo para reproducirse ahora mismo.';

  @override
  String get detailPlaybackHint =>
      'Cuando se pueda, reutilizaremos tu ultima fuente y servidor utiles.';

  @override
  String detailContinueEpisode(Object episode) {
    return 'Continuar desde el episodio $episode';
  }

  @override
  String get detailContinueBadge => 'Continuar';

  @override
  String detailPlaybackSources(int count) {
    return 'Disponible en $count fuentes';
  }

  @override
  String get homeHeroTitle => 'Encuentra algo rapido y empieza a ver antes.';

  @override
  String get homeHeroSubtitle =>
      'Busca en AniList, revisa disponibilidad real y entra a reproduccion con menos pasos.';

  @override
  String get homeSearchAction => 'Buscar';

  @override
  String get homeTrendingSection => 'Tendencias';

  @override
  String get homeTrendingHint =>
      'Abre cualquier anime para ver si realmente esta listo para verse.';

  @override
  String get searchHeroTitle => 'Buscar por titulo';

  @override
  String get searchPromptShort =>
      'Busca un titulo para ver animes coincidentes.';

  @override
  String timeAgoMinutes(int count) {
    return 'hace ${count}m';
  }

  @override
  String timeAgoHours(int count) {
    return 'hace ${count}h';
  }

  @override
  String timeAgoDays(int count) {
    return 'hace ${count}d';
  }

  @override
  String get playbackPreparing => 'Preparando reproduccion...';

  @override
  String get playbackOpeningSelectedServer =>
      'Abriendo servidor seleccionado...';

  @override
  String get serverPickerTitle => 'Elige un servidor';

  @override
  String get serverPickerSubtitle =>
      'Aqui solo aparecen opciones que realmente pueden abrirse.';

  @override
  String get serverPickerRememberSelectionTitle => 'Recordar esta seleccion';

  @override
  String get serverPickerRememberSelectionSubtitle =>
      'Usa esta fuente y este servidor primero la proxima vez si siguen disponibles.';

  @override
  String get serverPickerAllSources => 'Todas las fuentes';

  @override
  String serverPickerSourceFilter(Object sourceName, Object count) {
    return '$sourceName $count';
  }

  @override
  String serverPickerSourceOptionCount(Object count) {
    return '$count opciones';
  }

  @override
  String serverPickerCurrentRemembered(Object sourceName, Object serverName) {
    return 'Recordado ahora: $sourceName / $serverName';
  }

  @override
  String get serverPickerUnknownSource => 'Fuente desconocida';

  @override
  String get serverPickerUnknownServer => 'Servidor desconocido';

  @override
  String get serverOptionLastUsed => 'Ultimo usado';

  @override
  String get serverOptionRecommended => 'Recomendado';

  @override
  String get episodeAutoplayFailed =>
      'Ese atajo no abrio. Elige otro servidor.';

  @override
  String get episodePlaybackUnavailable =>
      'Este episodio no esta listo para reproducirse ahora mismo.';

  @override
  String get episodeSelectedServerFailed =>
      'Ese servidor no esta disponible ahora mismo.';

  @override
  String get episodeLockedLabel => 'No disponible';

  @override
  String get episodePlayNowLabel => 'Ver ahora';

  @override
  String get episodeListUsingPreference =>
      'Toca un episodio y Kumoriya intentara primero tu mejor fuente.';

  @override
  String episodeListUsingRememberedSource(
    Object sourceName,
    Object serverName,
  ) {
    return 'Empezaremos con $sourceName $serverName si sigue disponible.';
  }

  @override
  String playerSourceSummary(Object serverName, Object resolverName) {
    return 'Reproduciendo desde $serverName via $resolverName';
  }

  @override
  String playerAudioPreference(Object value) {
    return 'Audio: $value';
  }

  @override
  String get myListHistory => 'Historial';

  @override
  String get myListFavorites => 'Favoritos';

  @override
  String get myListSubscribed => 'Suscritos';

  @override
  String get myListDownloads => 'Descargas';

  @override
  String get myListHistoryHint => 'Tu historial de reproduccion';

  @override
  String get myListFavoritesEmpty =>
      'Sin favoritos aun. Toca el corazon en cualquier anime para guardarlo.';

  @override
  String get myListSubscribedEmpty =>
      'Sin suscripciones aun. Suscribete a un anime para recibir notificaciones de nuevos episodios.';

  @override
  String get myListDownloadsEmpty =>
      'Sin descargas aún. Descarga episodios desde la lista de episodios.';

  @override
  String get addFavorite => 'Agregar a favoritos';

  @override
  String get removeFavorite => 'Quitar de favoritos';

  @override
  String get subscribe => 'Notificar nuevos episodios';

  @override
  String get unsubscribe => 'Dejar de notificar';

  @override
  String get favoriteAdded => 'Agregado a favoritos';

  @override
  String get favoriteRemoved => 'Quitado de favoritos';

  @override
  String get subscribedLabel => 'Suscrito';

  @override
  String get unsubscribedLabel => 'No suscrito';

  @override
  String get downloadEpisode => 'Descargar';

  @override
  String get downloadAll => 'Descargar Todo';

  @override
  String get downloadQueued => 'Descarga en cola';

  @override
  String get downloadAllQueued => 'Todos los episodios en cola de descarga';

  @override
  String get downloadInProgress => 'Descargando...';

  @override
  String get downloadComplete => 'Descargado';

  @override
  String get downloadFailed => 'Descarga fallida';

  @override
  String get downloadPaused => 'Pausado';

  @override
  String get downloadPending => 'Pendiente';

  @override
  String get downloadCancel => 'Cancelar';

  @override
  String get downloadRetry => 'Reintentar';

  @override
  String get downloadDelete => 'Eliminar';

  @override
  String get downloadPause => 'Pausar';

  @override
  String get downloadResume => 'Reanudar';

  @override
  String get downloadFolderTitle => 'Carpeta de descargas';

  @override
  String get downloadFolderDescription =>
      'Los nuevos episodios se guardarán en esta ubicación.';

  @override
  String get downloadFolderDefault => 'Predeterminada';

  @override
  String get downloadFolderCustom => 'Personalizada';

  @override
  String get downloadFolderChange => 'Cambiar carpeta';

  @override
  String get downloadFolderReset => 'Usar carpeta predeterminada';

  @override
  String get downloadFolderSaved => 'Carpeta de descargas actualizada.';

  @override
  String get downloadFolderResetDone =>
      'La carpeta de descargas volvió a la predeterminada.';

  @override
  String get downloadFolderSelectionCancelled =>
      'Selección de carpeta cancelada.';

  @override
  String get downloadFolderPermissionDenied =>
      'No se concedió permiso para usar una carpeta externa de descargas.';

  @override
  String get autoDownload => 'Auto-descargar nuevos episodios';

  @override
  String get autoDownloadEnabled => 'Auto-descarga activada';

  @override
  String get autoDownloadDisabled => 'Auto-descarga desactivada';

  @override
  String get downloadHlsNotSupported =>
      'Los streams HLS no se pueden descargar';

  @override
  String get downloadSelectQuality => 'Seleccionar calidad';

  @override
  String get downloadSelectServer => 'Seleccionar servidor';

  @override
  String get playEpisode => 'Reproducir episodio';

  @override
  String get navHome => 'Inicio';

  @override
  String get navSearch => 'Buscar';

  @override
  String get navCalendar => 'Calendario';

  @override
  String get navLibrary => 'Biblioteca';

  @override
  String get navDownloads => 'Descargas';

  @override
  String get calendarTitle => 'Calendario';

  @override
  String get calendarSubtitle => 'Emisión por día';

  @override
  String get calendarNoAiring => 'No se encontraron animes en emisión.';

  @override
  String get calendarUnknownSchedule => 'Sin horario confirmado';

  @override
  String get downloadsTitle => 'Descargas';

  @override
  String get downloadsSubtitle => 'Episodios sin conexión';

  @override
  String get libraryTitle => 'Biblioteca';

  @override
  String get playerBack => 'Atrás';

  @override
  String get playerAudio => 'Audio';

  @override
  String get playerSubtitles => 'Subtítulos';

  @override
  String get playerQuality => 'Calidad';

  @override
  String get playerRetry => 'REINTENTAR';

  @override
  String get playerSkipBackward => '-10s';

  @override
  String get playerSkipForward => '+10s';

  @override
  String get playerUnlockRotation => 'Desbloquear rotación';

  @override
  String get playerLockRotation => 'Bloquear rotación';

  @override
  String get playerDisableSubtitles => 'Desactivar';

  @override
  String get resumeLabel => 'REANUDAR';

  @override
  String get detailPlay => 'Reproducir';

  @override
  String detailResumeEpisode(int episode) {
    return 'Continuar EP $episode';
  }

  @override
  String get searchPageTitle => 'Buscar';

  @override
  String get homeAiringToday => 'Al Aire Hoy';
}
