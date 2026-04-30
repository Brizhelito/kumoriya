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
  String get errorServiceUnavailableAnilist =>
      'AniList no esta disponible en este momento. Intenta mas tarde.';

  @override
  String get offlineBanner => 'Sin conexión';

  @override
  String get anilistDownBanner => 'AniList caído';

  @override
  String get errorRateLimitedAnilist =>
      'AniList esta limitando las solicitudes en este momento. Espera un poco y vuelve a intentar.';

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
  String get homeSeasonHubSection => 'Temporadas';

  @override
  String get homeSeasonHubTitle => 'Explorar temporada';

  @override
  String get homeSeasonHubSubtitle =>
      'Mira lo mas trending de la season, los proximos estrenos y los picks de la comunidad.';

  @override
  String get trendingPageTitle => 'Trending';

  @override
  String get trendingPageSubtitle =>
      'Ranking completo de AniList ordenado por tendencia actual.';

  @override
  String get seasonHubTitle => 'Por temporada';

  @override
  String get seasonHubSubtitle =>
      'Cambia de season para ver que domina ahora, que sigue por estrenarse y que recomienda mas la comunidad.';

  @override
  String get seasonHubLoading => 'Cargando temporada...';

  @override
  String get seasonHubCarryoverNote =>
      'Incluye series que comenzaron en la temporada anterior y siguen en emision durante esta season.';

  @override
  String get seasonHubInSeasonSection => 'En emision';

  @override
  String get seasonHubUpcomingSection => 'Proximos lanzamientos';

  @override
  String get seasonHubRecommendedSection => 'Recomendados por la comunidad';

  @override
  String get seasonHubInSeasonEmpty =>
      'No hay animes en emision para esta season.';

  @override
  String get seasonHubUpcomingEmpty =>
      'No hay estrenos confirmados para esta season.';

  @override
  String get seasonHubRecommendedEmpty =>
      'Todavia no hay suficientes senales de comunidad para recomendar esta season.';

  @override
  String get seasonWinter => 'Invierno';

  @override
  String get seasonSpring => 'Primavera';

  @override
  String get seasonSummer => 'Verano';

  @override
  String get seasonFall => 'Otono';

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
  String notificationNewEpisode(int episodeNumber) {
    return 'Episodio $episodeNumber ya esta disponible';
  }

  @override
  String notificationNewEpisodeWithTitle(
    int episodeNumber,
    Object episodeTitle,
  ) {
    return 'Episodio $episodeNumber - $episodeTitle ya esta disponible';
  }

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
  String historyProgressUpTo(int episode, int total) {
    return 'Visto hasta EP $episode / $total';
  }

  @override
  String historyProgressLastWatched(int episode) {
    return 'Último EP visto $episode';
  }

  @override
  String get episodePlaying => 'REPRODUCIENDO';

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
  String get detailCheckingSources => 'Buscando fuentes...';

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
  String get downloadSourceUnavailable =>
      'No hay descargas disponibles de esta fuente. Elige otra fuente.';

  @override
  String get downloadInProgress => 'Descargando...';

  @override
  String get downloadComplete => 'Descargado';

  @override
  String get downloadFailed => 'Descarga fallida';

  @override
  String get downloadFileNotFound =>
      'Archivo descargado no encontrado — pudo haber sido eliminado.';

  @override
  String get downloadPaused => 'Pausado';

  @override
  String get downloadPending => 'Pendiente';

  @override
  String get downloadCancel => 'Cancelar';

  @override
  String get downloadClearQueue => 'Limpiar cola';

  @override
  String get downloadClearQueueConfirmTitle => '¿Limpiar cola?';

  @override
  String get downloadClearQueueConfirmMessage =>
      'Esto eliminará todas las descargas pendientes y fallidas de la cola. Esta acción no se puede deshacer.';

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
  String get autoDownloadAudioPreference => 'Preferencia de audio';

  @override
  String get autoDownloadAudioAny => 'Cualquiera';

  @override
  String get autoDownloadAudioSub => 'SUB';

  @override
  String get autoDownloadAudioDub => 'DUB';

  @override
  String get downloadAllChooseAudio => 'Elegir tipo de audio';

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
  String get universeAnime => 'Anime';

  @override
  String get universeManga => 'Manga';

  @override
  String get universeSwitchLabel => 'Cambiar universo';

  @override
  String get mangaHomeTitle => 'Inicio Manga';

  @override
  String get mangaSearchTitle => 'Buscar Manga';

  @override
  String get mangaLibraryTitle => 'Biblioteca Manga';

  @override
  String get mangaDownloadsTitle => 'Descargas Manga';

  @override
  String get mangaComingSoonSlice8 =>
      'El descubrimiento y los detalles llegan en el próximo slice. Mientras tanto, vuelve al universo anime.';

  @override
  String get mangaComingSoonSlice10 =>
      'Tu biblioteca de manga vivirá aquí cuando llegue el Slice 10.';

  @override
  String get mangaLibraryHistoryEmpty => 'Aún no hay historial de lectura.';

  @override
  String get mangaLibraryFavoritesEmpty =>
      'Aún no hay favoritos. Toca el corazón en cualquier manga para guardarlo.';

  @override
  String get mangaLibrarySubscribedEmpty =>
      'Aún no hay suscripciones. Suscríbete a un manga para recibir notificaciones de nuevos capítulos.';

  @override
  String mangaLibraryHistoryChapterLine(String number) {
    return 'Último leído: Cap. $number';
  }

  @override
  String get mangaDetailAddFavorite => 'Añadir a favoritos';

  @override
  String get mangaDetailRemoveFavorite => 'Quitar de favoritos';

  @override
  String get mangaDetailSubscribe => 'Notificar nuevos capítulos';

  @override
  String get mangaDetailUnsubscribe => 'Dejar de notificar';

  @override
  String get libraryFilterAll => 'Todos';

  @override
  String get mangaComingSoonSlice11 =>
      'Las descargas de manga (CBZ) llegarán en el Slice 11.';

  @override
  String get mangaHomeFeaturedTag => 'DESTACADO';

  @override
  String get mangaHomeReadAction => 'Ver detalle';

  @override
  String get mangaHomeTrending => 'Tendencia ahora';

  @override
  String get mangaHomePopular => 'Más populares';

  @override
  String get mangaHomeLatest => 'Recién actualizados';

  @override
  String get mangaHomeTopRated => 'Mejor puntuados';

  @override
  String get mangaHomeEmpty =>
      'Aún no hay manga para mostrar. Desliza para actualizar cuando vuelvas a estar conectado.';

  @override
  String get mangaHomeError => 'No se pudo cargar el manga';

  @override
  String get mangaHomeRetry => 'Reintentar';

  @override
  String get mangaSearchHint => 'Busca manga, manhwa, manhua…';

  @override
  String get mangaSearchEmptyTitle => 'Encuentra tu próxima lectura';

  @override
  String get mangaSearchEmptyHint =>
      'Escribe un título — AniList cubre manga, manhwa, manhua y one-shots.';

  @override
  String get mangaSearchNoResults => 'Sin resultados';

  @override
  String mangaCardChapterCountLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count capítulos',
      one: '1 capítulo',
    );
    return '$_temp0';
  }

  @override
  String get mangaDetailSynopsis => 'Sinopsis';

  @override
  String get mangaDetailNoSynopsis => 'Sin sinopsis disponible.';

  @override
  String get mangaDetailGenres => 'Géneros';

  @override
  String get mangaDetailChapters => 'Capítulos';

  @override
  String get mangaDetailNoChaptersInLanguage =>
      'No hay capítulos disponibles en tu idioma.';

  @override
  String get mangaDetailReaderComingSoon => 'El lector llega en el Slice 9';

  @override
  String mangaDetailVolumeLabel(int number) {
    return 'Vol. $number';
  }

  @override
  String mangaDetailChapterLabel(String number) {
    return 'Cap. $number';
  }

  @override
  String get mangaDetailExternalChaptersTitle => 'Capítulos oficiales externos';

  @override
  String get mangaDetailExternalChaptersHint =>
      'Alojados por las editoriales (MangaPlus, Viz, …). Abren en tu navegador; no se leen dentro de la app.';

  @override
  String get mangaDetailOpenExternal => 'Abrir en navegador';

  @override
  String get mangaDetailOpenExternalFailed =>
      'No se pudo abrir el enlace externo.';

  @override
  String get mangaDetailScanlatorLabel => 'Fuente';

  @override
  String get mangaDetailScanlatorAuto => 'Auto';

  @override
  String get mangaDetailScanlatorAutoHint =>
      'Elige la versión más completa por capítulo.';

  @override
  String get mangaDetailScanlatorPickerTitle => 'Elige scanlator';

  @override
  String mangaDetailScanlatorChapterCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count capítulos',
      one: '1 capítulo',
    );
    return '$_temp0';
  }

  @override
  String get mangaDetailScanlatorLastReleaseToday => 'Última publicación hoy';

  @override
  String mangaDetailScanlatorLastReleaseDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Última publicación hace $days días',
      one: 'Última publicación hace 1 día',
    );
    return '$_temp0';
  }

  @override
  String mangaDetailScanlatorLastReleaseMonths(int months) {
    String _temp0 = intl.Intl.pluralLogic(
      months,
      locale: localeName,
      other: 'Última publicación hace $months meses',
      one: 'Última publicación hace 1 mes',
    );
    return '$_temp0';
  }

  @override
  String get mangaDetailSourceLabel => 'Proveedor';

  @override
  String get mangaDetailSourceAuto => 'Todos';

  @override
  String get mangaDetailSourceAutoHint =>
      'Agrupa capítulos de todos los proveedores disponibles.';

  @override
  String get mangaDetailSourcePickerTitle => 'Elige proveedor';

  @override
  String get settingsPluginBaseUrlsTitle => 'URLs base de plugins';

  @override
  String get settingsPluginBaseUrlsDescription =>
      'Sobrescribe la URL base que usa cada plugin de fuente. Dejar vacío para usar la del manifiesto.';

  @override
  String get settingsPluginBaseUrlsAdvancedEntry =>
      'URLs base de plugins (avanzado)';

  @override
  String get settingsPluginBaseUrlsEmpty => 'No hay plugins disponibles.';

  @override
  String get settingsPluginBaseUrlsManifestLabel => 'Predet. del manifiesto';

  @override
  String get settingsPluginBaseUrlsCurrentLabel => 'Actual';

  @override
  String get settingsPluginBaseUrlsOverrideHint => 'https://api.example.com';

  @override
  String get settingsPluginBaseUrlsSave => 'Guardar';

  @override
  String get settingsPluginBaseUrlsClear => 'Restablecer';

  @override
  String get settingsPluginBaseUrlsInvalid => 'Ingresa una URL http(s) válida.';

  @override
  String get settingsPluginBaseUrlsSaved => 'Override guardado.';

  @override
  String get settingsPluginBaseUrlsCleared => 'Override eliminado.';

  @override
  String get calendarTitle => 'Calendario';

  @override
  String get calendarSubtitle => 'Calendario de emisión por fecha';

  @override
  String get calendarNoAiring => 'No se encontraron animes en emisión.';

  @override
  String get calendarUnknownSchedule => 'Sin horario confirmado';

  @override
  String get calendarToday => 'Hoy';

  @override
  String get downloadsTitle => 'Descargas';

  @override
  String get downloadsSubtitle => 'Episodios sin conexión';

  @override
  String get downloadsTabActive => 'Activas';

  @override
  String get downloadsTabQueue => 'En cola';

  @override
  String get downloadsTabCompleted => 'Descargadas';

  @override
  String get downloadsActiveEmpty => 'No hay descargas activas.';

  @override
  String get downloadsQueueEmpty => 'No hay descargas en cola.';

  @override
  String get downloadsCompletedEmpty => 'No hay episodios descargados.';

  @override
  String get libraryTitle => 'Biblioteca';

  @override
  String get settingsTitle => 'Configuración';

  @override
  String get settingsNotificationsTitle => 'Notificaciones';

  @override
  String get settingsNotificationsDescription =>
      'Las suscripciones usan notificaciones del sistema para avisar de episodios nuevos.';

  @override
  String get settingsEnableNotifications => 'Activar notificaciones';

  @override
  String get settingsOpenSystemSettings => 'Abrir ajustes del sistema';

  @override
  String get settingsStatusAllowed => 'Permitido';

  @override
  String get settingsStatusBlocked => 'Bloqueado';

  @override
  String get settingsStatusUnknown => 'Desconocido';

  @override
  String get settingsAppTitle => 'Aplicación';

  @override
  String get settingsThemeLabel => 'Tema';

  @override
  String get settingsThemeDark => 'Oscuro';

  @override
  String get settingsLanguageLabel => 'Idioma';

  @override
  String get settingsVersionLabel => 'Versión';

  @override
  String get settingsLanguageEnglish => 'Inglés';

  @override
  String get settingsLanguageSpanish => 'Español';

  @override
  String get settingsDesktopOnlyVisibleNote =>
      'En Windows solo se muestran ajustes aplicables a escritorio.';

  @override
  String get settingsPlaybackPreferencesTitle => 'Preferencias de reproducción';

  @override
  String get settingsPlaybackPreferencesDescription =>
      'Limpia la fuente, servidor y resolver recordados para volver a elegir desde cero.';

  @override
  String get settingsPlaybackPreferencesClear =>
      'Quitar preferencias guardadas';

  @override
  String get settingsPlaybackPreferencesCleared =>
      'Se eliminaron las preferencias guardadas';

  @override
  String get playerBack => 'Atrás';

  @override
  String get playerAudio => 'Audio';

  @override
  String get playerSubtitles => 'Subtítulos';

  @override
  String get playerQuality => 'Calidad';

  @override
  String get playerNextEpisode => 'Siguiente episodio';

  @override
  String get playerPreviousEpisode => 'Episodio anterior';

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

  @override
  String get myListHistoryEmpty => 'Aún no hay historial de reproducción.';

  @override
  String downloadEpisodesCount(int count) {
    return '$count episodios';
  }

  @override
  String downloadEpisodeLabel(int episode) {
    return 'Episodio $episode';
  }

  @override
  String get downloadedSourceLabel => 'Descargado';

  @override
  String get downloadAllFromSource => 'Descargar todos desde una fuente';

  @override
  String get sectionSeeAll => 'Ver todo';

  @override
  String get statusAiring => 'EN EMISIÓN';

  @override
  String get statusUpcoming => 'PRÓXIMO';

  @override
  String get statusFinished => 'FINALIZADO';

  @override
  String get statusCancelled => 'CANCELADO';

  @override
  String get statusOnHiatus => 'EN PAUSA';

  @override
  String get statusUnknown => 'DESCONOCIDO';

  @override
  String get settingsSubtitleTitle => 'Subtítulos';

  @override
  String get settingsSubtitleDescription =>
      'Personaliza la apariencia de los subtítulos durante la reproducción.';

  @override
  String get settingsSubtitleFontSize => 'Tamaño de fuente';

  @override
  String get settingsSubtitleFontColor => 'Color del texto';

  @override
  String get settingsSubtitleFontOpacity => 'Opacidad del texto';

  @override
  String get settingsSubtitleBgColor => 'Color del fondo';

  @override
  String get settingsSubtitleBgOpacity => 'Opacidad del fondo';

  @override
  String get settingsSubtitleBgBlack => 'Negro';

  @override
  String get settingsSubtitleBgDarkGray => 'Gris oscuro';

  @override
  String get settingsSubtitleBgNone => 'Sin fondo';

  @override
  String get settingsSubtitleEdgeStyle => 'Estilo del borde';

  @override
  String get settingsSubtitleEdgeNone => 'Ninguno';

  @override
  String get settingsSubtitleEdgeOutline => 'Contorno';

  @override
  String get settingsSubtitleEdgeDropShadow => 'Sombra';

  @override
  String get settingsSubtitleEdgeRaised => 'Relieve';

  @override
  String get settingsSubtitleEdgeDepressed => 'Hundido';

  @override
  String get settingsSubtitleSmall => 'P';

  @override
  String get settingsSubtitleMedium => 'M';

  @override
  String get settingsSubtitleLarge => 'G';

  @override
  String get settingsSubtitleExtraLarge => 'XG';

  @override
  String get settingsSubtitleBackground =>
      'Mostrar fondo detrás de los subtítulos';

  @override
  String get playerSubtitleStyle => 'Estilo de subtítulos';

  @override
  String get playerSubtitleStyleDescription =>
      'Mejora la legibilidad sin salir del reproductor.';

  @override
  String get playerSkipIntro => 'Saltar intro';

  @override
  String get playerSkipCredits => 'Saltar créditos';

  @override
  String get clearSearch => 'Borrar búsqueda';

  @override
  String get sourceServerLinksEmpty =>
      'No hay enlaces de servidor disponibles para este episodio.';

  @override
  String get downloadDeleteConfirmTitle => '¿Eliminar descarga?';

  @override
  String get downloadDeleteConfirmMessage =>
      'Este episodio descargado será eliminado permanentemente de tu dispositivo.';

  @override
  String get cancelAction => 'Cancelar';

  @override
  String get playerLockControls => 'Bloquear controles';

  @override
  String get historyGroupToday => 'Hoy';

  @override
  String get historyGroupYesterday => 'Ayer';

  @override
  String get historyGroupThisWeek => 'Esta Semana';

  @override
  String get historyGroupThisMonth => 'Este Mes';

  @override
  String get historyGroupOlder => 'Anterior';

  @override
  String get historyDeleteEntryTitle => '¿Eliminar del historial?';

  @override
  String get historyDeleteEntryMessage =>
      'Este anime será eliminado de tu historial de reproducción.';

  @override
  String get historyClearAllTitle => '¿Borrar todo el historial?';

  @override
  String get historyClearAllMessage =>
      'Tu historial completo de reproducción será eliminado permanentemente.';

  @override
  String get historyClearAllAction => 'Borrar todo el historial';

  @override
  String get deleteAction => 'Eliminar';

  @override
  String get removeAction => 'Quitar';

  @override
  String get downloadViewAnimeDetails => 'Ver detalles del anime';

  @override
  String get downloadDeleteAllEpisodes => 'Eliminar todos los episodios';

  @override
  String get downloadDeleteEpisode => 'Eliminar episodio';

  @override
  String get downloadDeleteAllConfirmTitle =>
      '¿Eliminar todos los episodios descargados?';

  @override
  String get downloadDeleteAllConfirmMessage =>
      'Todos los episodios descargados de este anime serán eliminados permanentemente.';

  @override
  String get librarySortAlphabetical => 'A-Z';

  @override
  String get librarySortRecentlyAdded => 'Recién añadido';

  @override
  String get librarySortRecentlyWatched => 'Visto recientemente';

  @override
  String get libraryActionSave => 'Guardar';

  @override
  String get libraryActionNotify => 'Notificar';

  @override
  String get libraryActionAutoDownload => 'Auto DL';

  @override
  String get discoverTitle => 'Descubrir';

  @override
  String get discoverSubtitle => 'Encuentra tu próximo anime';

  @override
  String get discoverTrending => 'Tendencia ahora';

  @override
  String get discoverTopRated => 'Mejor valorados';

  @override
  String get discoverPopular => 'Más populares';

  @override
  String get discoverGenres => 'Explorar por género';

  @override
  String get discoverCantRemember => '¿No recuerdas el nombre?';

  @override
  String get discoverCantRememberSubtitle =>
      'Busca un anime describiendo de qué trata';

  @override
  String get discoverStartTagSearch => 'Buscar por tags';

  @override
  String get browseResultsTitle => 'Resultados';

  @override
  String get browseNoResults => 'No se encontraron anime con estos filtros.';

  @override
  String get browseFilterGenre => 'Género';

  @override
  String get browseFilterFormat => 'Formato';

  @override
  String get browseFilterSeason => 'Temporada';

  @override
  String get browseFilterYear => 'Año';

  @override
  String get browseFilterSort => 'Ordenar por';

  @override
  String get browseFilterStatus => 'Estado';

  @override
  String get browseFilterTags => 'Tags';

  @override
  String get browseFilterApply => 'Aplicar filtros';

  @override
  String get browseFilterClear => 'Limpiar filtros';

  @override
  String get browseSortTrending => 'Tendencia';

  @override
  String get browseSortScore => 'Puntuación';

  @override
  String get browseSortPopularity => 'Popularidad';

  @override
  String get browseSortFavourites => 'Favoritos';

  @override
  String get browseSortNewest => 'Más recientes';

  @override
  String get browseSortTitle => 'Título';

  @override
  String get tagSearchTitle => 'Buscar por tags';

  @override
  String get tagSearchSubtitle =>
      'Selecciona tags que describan el anime que buscas';

  @override
  String get tagSearchSelectCategory => 'Selecciona una categoría';

  @override
  String tagSearchSelectedTags(int count) {
    return '$count tags seleccionados';
  }

  @override
  String get tagSearchFindAnime => 'Buscar anime';

  @override
  String get tagSearchNoTags => 'Aún no hay tags seleccionados';

  @override
  String get tagSearchGuideStep1 => 'Abre una categoría para ver sus tags';

  @override
  String get tagSearchGuideStep2 => 'Toca los tags que recuerdes del anime';

  @override
  String get tagSearchGuideStep3 => 'Presiona buscar para ver resultados';

  @override
  String get tagSearchFilterHint => 'Filtrar tags por nombre...';

  @override
  String browseGenreApply(int count) {
    return 'Aplicar ($count)';
  }

  @override
  String get formatTv => 'TV';

  @override
  String get formatMovie => 'Película';

  @override
  String get formatOva => 'OVA';

  @override
  String get formatOna => 'ONA';

  @override
  String get formatSpecial => 'Especial';

  @override
  String get downloadRetryAllFailed => 'Reintentar todas';

  @override
  String get downloadPauseAll => 'Pausar todas';

  @override
  String get downloadResumeAll => 'Reanudar todas';

  @override
  String get profileTitle => 'Perfil';

  @override
  String get profileNotSignedIn => 'No has iniciado sesión';

  @override
  String get profileSignIn => 'Iniciar sesión';

  @override
  String get profileLinkedAccounts => 'Cuentas vinculadas';

  @override
  String get profileNoLinkedAccounts => 'Sin cuentas vinculadas';

  @override
  String get profileCouldNotLoadAccounts => 'No se pudieron cargar las cuentas';

  @override
  String get profileActiveSessions => 'Sesiones activas';

  @override
  String get profileNoActiveSessions => 'Sin sesiones activas';

  @override
  String get profileCouldNotLoadSessions =>
      'No se pudieron cargar las sesiones';

  @override
  String get profilePasskeys => 'Passkeys';

  @override
  String get profileNoPasskeys => 'No hay passkeys registradas';

  @override
  String get profileCouldNotLoadPasskeys =>
      'No se pudieron cargar las passkeys';

  @override
  String get profileSync => 'Sincronización';

  @override
  String get profileSyncStatus => 'Estado';

  @override
  String get profileLastSynced => 'Última sincronización';

  @override
  String get profileLastSyncedNever => 'Nunca';

  @override
  String get profileSyncNow => 'Sincronizar ahora';

  @override
  String get profileDeleteAccount => 'Eliminar cuenta';

  @override
  String get profileLogOut => 'Cerrar sesión';

  @override
  String get profileLogOutBody => 'Tus datos locales se conservarán.';

  @override
  String get profileCancel => 'Cancelar';

  @override
  String get profileDeleteAccountWarning =>
      'Esto eliminará permanentemente tu cuenta y todos los datos sincronizados. No se puede deshacer.';

  @override
  String get profileDelete => 'Eliminar';

  @override
  String get profileUnknownDevice => 'Dispositivo desconocido';

  @override
  String get profileUnnamedPasskey => 'Passkey sin nombre';

  @override
  String get profileUnknownProvider => 'Desconocido';

  @override
  String get profileNoEmail => 'Sin email';

  @override
  String get profileSyncIdle => 'En espera';

  @override
  String get profileSyncPushing => 'Subiendo';

  @override
  String get profileSyncPulling => 'Descargando';

  @override
  String get profileSyncSuccess => 'Al día';

  @override
  String get profileSyncFailed => 'Falló';

  @override
  String get profileTimeJustNow => 'Hace un momento';

  @override
  String profileTimeMinutesAgo(int count, Object unit) {
    return 'Hace $count $unit';
  }

  @override
  String profileTimeHoursAgo(int count, Object unit) {
    return 'Hace $count $unit';
  }

  @override
  String profileTimeDaysAgo(int count, Object unit) {
    return 'Hace $count $unit';
  }

  @override
  String get profileTimeMinuteSingular => 'minuto';

  @override
  String get profileTimeMinutePlural => 'minutos';

  @override
  String get profileTimeHourSingular => 'hora';

  @override
  String get profileTimeHourPlural => 'horas';

  @override
  String get profileTimeDaySingular => 'día';

  @override
  String get profileTimeDayPlural => 'días';

  @override
  String get settingsAutoDeleteWatched =>
      'Borrar automáticamente descargas vistas';

  @override
  String get settingsAutoDeleteNever => 'Nunca';

  @override
  String settingsAutoDeleteAfterDays(int days) {
    return 'Después de $days días';
  }

  @override
  String get settingsAutoDeleteImmediately => 'Inmediatamente';

  @override
  String get settingsDownloadsTitle => 'Descargas';

  @override
  String get settingsDownloadsWifiOnly => 'Descargas solo con WiFi';

  @override
  String get settingsDownloadsWifiOnlyDescription =>
      'Pausar descargas cuando no esté conectado a WiFi';

  @override
  String get onboardingNotificationTitle => '¿Activar notificaciones?';

  @override
  String get onboardingNotificationBody =>
      'Kumoriya puede notificarte cuando haya nuevos episodios disponibles de tus anime suscritos.';

  @override
  String get onboardingNotificationAllow => 'Permitir';

  @override
  String get onboardingNotificationSkip => 'Ahora no';

  @override
  String get profileRegisterPasskey => 'Registrar nueva passkey';

  @override
  String get profilePasskeyNameTitle => 'Nombre de la passkey';

  @override
  String get profilePasskeyNameHint => 'ej. Mi teléfono';

  @override
  String get profilePasskeyNameContinue => 'Continuar';

  @override
  String get profilePasskeyRegistered => 'Passkey registrada';

  @override
  String get profilePasskeyRegisterFailed => 'No se pudo registrar la passkey';

  @override
  String get profilePasskeyDeleteTitle => '¿Eliminar passkey?';

  @override
  String get profilePasskeyDeleteBody =>
      'Esta passkey será eliminada y ya no podrá usarse para iniciar sesión.';

  @override
  String get profilePasskeyDeleted => 'Passkey eliminada';

  @override
  String get profilePasskeyDeleteFailed => 'No se pudo eliminar la passkey';

  @override
  String get authLoginWelcomeTitle => 'Bienvenido a Kumoriya';

  @override
  String get authLoginSubtitle =>
      'Inicia sesión para sincronizar tu progreso entre dispositivos';

  @override
  String get authCouldNotOpenBrowser => 'No se pudo abrir el navegador';

  @override
  String get authContinueWithDiscord => 'Continuar con Discord';

  @override
  String get authContinueWithGoogle => 'Continuar con Google';

  @override
  String get authWaitingForBrowser => 'Esperando a que vuelva el navegador...';

  @override
  String get authCancelLogin => 'Cancelar inicio de sesión';

  @override
  String get authSkipForNow => 'Omitir por ahora';

  @override
  String get authLoginFailed => 'Falló el inicio de sesión';

  @override
  String get authGoBack => 'Volver';

  @override
  String get authConnecting => 'Conectando...';

  @override
  String get authMayTakeSeconds => 'Esto puede tardar unos segundos';

  @override
  String get updateAvailableTitle => 'Nueva actualización';

  @override
  String get updateWhatsNew => 'Novedades:';

  @override
  String get updateDownloading => 'Descargando actualización...';

  @override
  String get updateInstallingWindows =>
      'Instalando... la aplicación se cerrará.';

  @override
  String get updateOpeningInstaller => 'Abriendo instalador...';

  @override
  String get updateClose => 'Cerrar';

  @override
  String get updateLater => 'Más tarde';

  @override
  String get updateNow => 'Actualizar';

  @override
  String updateInstallerOpenFailed(Object error) {
    return 'No se pudo abrir el instalador: $error';
  }

  @override
  String get updateReleaseNotesAdded => 'Agregado';

  @override
  String get updateReleaseNotesChanged => 'Cambios';

  @override
  String get updateReleaseNotesFixed => 'Corregido';

  @override
  String get updateGotIt => 'Entendido';

  @override
  String get partyTitle => 'Watch Party';

  @override
  String get partyOpenBrowseTooltip => 'Abrir exploración de la party';

  @override
  String get partyViewDebugLogsTooltip => 'Ver logs debug de la party';

  @override
  String get partyRemovedByHost => 'El host te expulsó de la party.';

  @override
  String partyRemovedWithReason(Object reason) {
    return 'Fuiste expulsado de la party: $reason';
  }

  @override
  String get partyDebugLogsTitle => 'Logs Debug de la Party';

  @override
  String get partyClose => 'Cerrar';

  @override
  String get partyCopy => 'Copiar';

  @override
  String get partyLogsCopied => 'Logs copiados al portapapeles';

  @override
  String get partyWatchTogetherTitle => 'Mira junto a tus amigos';

  @override
  String get partyInviteIntro =>
      'Crea una sala o únete con un código de invitación. Hasta 4 personas pueden ver sincronizadas vía P2P.';

  @override
  String get partyInviteCodeLabel => 'Código de invitación';

  @override
  String get partyJoin => 'Unirse a la party';

  @override
  String partyStartRoomForAnime(Object animeTitle) {
    return 'O crea una sala para $animeTitle';
  }

  @override
  String get partyStartRoomFallbackAnime => 'este anime';

  @override
  String get partyCreateRoom => 'Crear sala';

  @override
  String get partyOpenAnimeToCreate =>
      'Abre la página de un anime para crear una sala';

  @override
  String get partyNowWatching => 'Viendo ahora';

  @override
  String partyEpisodeNumber(int episodeNumber) {
    return 'Episodio $episodeNumber';
  }

  @override
  String get partyChangeAnime => 'Cambiar anime';

  @override
  String get partyChangeEpisode => 'Cambiar ep.';

  @override
  String get partyInviteCodeCopied => '¡Código de invitación copiado!';

  @override
  String get partyShareInviteLinkTooltip => 'Compartir enlace de invitación';

  @override
  String get partyInviteLinkCopied => '¡Enlace de invitación copiado!';

  @override
  String get partyShareInviteSubject => 'Únete a mi watch party de Kumoriya';

  @override
  String partyShareInviteMessage(String title, String link) {
    return 'Únete a mi watch party de Kumoriya para $title: $link';
  }

  @override
  String partyMembersCount(int current, int max) {
    return 'Miembros ($current/$max)';
  }

  @override
  String get partyChangeEpisodeTitle => 'Cambiar episodio';

  @override
  String get partyEpisodeNumberLabel => 'Número de episodio';

  @override
  String get partyApply => 'Aplicar';

  @override
  String get partyReady => 'Listo';

  @override
  String get partyReadyConfirmed => '¡Listo!';

  @override
  String get partyStartWatching => 'Empezar a ver';

  @override
  String get partyWaitingForEveryone => 'Esperando a todos...';

  @override
  String get partyWaitingForHost => 'Esperando a que el host empiece...';

  @override
  String get partyTryAgain => 'Intentar de nuevo';

  @override
  String get partyHostActionsTooltip => 'Acciones del host';

  @override
  String get partyMakeHost => 'Hacer host';

  @override
  String get partyMemberDisconnected => 'El miembro está desconectado';

  @override
  String get partyRemoveFromParty => 'Expulsar de la party';

  @override
  String get partyRemoveMemberTitle => '¿Expulsar miembro?';

  @override
  String partyRemoveMemberBody(Object name) {
    return '¿Expulsar a \"$name\" de la party? Se desconectará de inmediato.';
  }

  @override
  String get partyRemove => 'Expulsar';

  @override
  String get partyTransferHostTitle => '¿Transferir host?';

  @override
  String partyTransferHostBody(Object name) {
    return '\"$name\" tomará el rol de host. Seguirás viendo, pero perderás los controles de host.';
  }

  @override
  String get partyTransfer => 'Transferir';

  @override
  String get partyPreparingStage => 'Preparando el escenario de la party...';

  @override
  String get partyCouldNotLoadAnime =>
      'No se pudo cargar este anime para la party.';

  @override
  String get partyBrowseModeBanner =>
      'Modo Watch Party: exploren juntos y luego vuelvan al lobby para confirmar el siguiente paso.';

  @override
  String get partyEpisodeModeBanner =>
      'Modo Watch Party: elijan el episodio juntos y luego vuelvan al lobby si el host necesita cambiar el objetivo de la sala.';

  @override
  String get partyHostSourceMissing =>
      'El host eligió una fuente que no tienes instalada.';

  @override
  String get partyHostEpisodeUnavailable =>
      'Ese episodio todavía no está disponible en tus fuentes instaladas.';

  @override
  String get partyHostServerUnavailable =>
      'Ese servidor del host no está disponible localmente. Elige otro.';

  @override
  String get partyHostResolverFailed =>
      'No se pudo resolver aquí el stream compartido. Elige otro servidor.';

  @override
  String partyEpisodeCta(int episodeNumber) {
    return 'Watch Party Ep. $episodeNumber';
  }

  @override
  String get partyStartWithParty => 'Iniciar con Party';

  @override
  String get partyOnlyHostCanSwitchAnime =>
      'Solo el host puede cambiar el anime de la party.';

  @override
  String partySwitchedToAnime(Object animeTitle) {
    return 'La party cambió a \"$animeTitle\".';
  }

  @override
  String get partyNoPlayableSourcesReady =>
      'Todavía no hay fuentes reproducibles listas.';

  @override
  String get partyGettingRoomStreamReady =>
      'Preparando el stream de la sala...';

  @override
  String get partyLoadingEpisodeBoard =>
      'Cargando el tablero de episodios de la party...';

  @override
  String get partyCouldNotLoadEpisodes =>
      'No se pudieron cargar los episodios de la party.';

  @override
  String get partyHostChoosesNextEpisode =>
      'El host elige el siguiente episodio de la party.';

  @override
  String partyMovedToEpisode(int episodeNumber) {
    return 'La party pasó al episodio $episodeNumber.';
  }

  @override
  String get partyOpeningEpisode => 'Abriendo el episodio de la party...';

  @override
  String get partyBackToLobbyTooltip => 'Volver al lobby de la party';

  @override
  String get partyEpisodesTitle => 'Episodios de la party';

  @override
  String partyLockedToEpisode(int episodeNumber) {
    return 'El host bloqueó la party en el episodio $episodeNumber.';
  }

  @override
  String get partyActiveTooltip => 'Party activa';

  @override
  String get partySetForPartyTooltip => 'Usar para la party';

  @override
  String get partyChangeAnimeTitle => 'Cambiar anime de la party';

  @override
  String partyChangeAnimeBody(Object animeTitle) {
    return '¿Cambiar la party a \"$animeTitle\"?\nTodos los miembros serán redirigidos.';
  }

  @override
  String get partySwitch => 'Cambiar';

  @override
  String get partyLobbyTooltip => 'Lobby de la party';

  @override
  String get partyChooseEpisode => 'Elegir episodio de la party';

  @override
  String get partyPreviewEpisodes => 'Previsualizar episodios';

  @override
  String get partyOpening => 'Abriendo...';

  @override
  String get partyWatchCurrentEpisode => 'Ver episodio actual';

  @override
  String get partyHostChoosesAnime => 'El host elige el anime';

  @override
  String get partyMaybeNext => 'Tal vez siga en la party';

  @override
  String get partyChooseRoomNext =>
      'Elige qué debería ver la sala a continuación.';

  @override
  String partyRoomCode(Object code) {
    return 'Código de sala $code';
  }

  @override
  String partyInRoomCount(int count) {
    return '$count en la sala';
  }

  @override
  String partyReadyCount(int count) {
    return '$count listos';
  }

  @override
  String partyConnectedCount(int count) {
    return '$count conectados';
  }

  @override
  String partyEpisodeCount(int count) {
    return '$count eps';
  }

  @override
  String partyRoomOnEpisode(int episodeNumber) {
    return 'Sala en ep $episodeNumber';
  }

  @override
  String get partyIntentCurrentTitle => 'Alineemos el siguiente episodio';

  @override
  String get partyIntentCurrentHost =>
      'Mantén la sala en movimiento: elige el episodio y luego entren juntos.';

  @override
  String get partyIntentCurrentMember =>
      'Estás navegando el anime activo de la sala. Cuando el host elija, todos siguen juntos.';

  @override
  String get partyIntentOtherTitle =>
      'Se siente como una buena elección para la sala';

  @override
  String partyIntentOtherHost(Object animeTitle) {
    return 'Cambia aquí la sala si la party quiere ver \"$animeTitle\" en su lugar.';
  }

  @override
  String get partyIntentOtherMember =>
      'Puedes explorar alternativas, pero solo el host puede cambiar el anime de la sala.';

  @override
  String get partyRoomReadySources => 'Fuentes listas para la sala';

  @override
  String get partyNeedPlayableSource =>
      'Todavía hace falta una fuente reproducible antes de que todos puedan ver juntos.';

  @override
  String get partyWhoIsHere => 'Quién está en el sofá';

  @override
  String get partyYouSuffix => 'Tú';

  @override
  String get partyEpisodesHostSubtitle =>
      'Elige el episodio que todos verán a continuación.';

  @override
  String get partyEpisodesMemberSubtitle =>
      'Sigue al host y entra cuando el episodio de la sala esté listo.';

  @override
  String partyOnlineCount(int count) {
    return '$count en línea';
  }

  @override
  String get partyNoEpisodesYet => 'Todavía no hay episodios disponibles.';

  @override
  String get partyRoomPick => 'Elección de sala';

  @override
  String get partyTapToQueue => 'Tocar para poner en cola';

  @override
  String get partyHostDecides => 'Decide el host';

  @override
  String get partyWatchTogether => 'Ver juntos';

  @override
  String get partyWaitingOnSource => 'Esperando fuente';

  @override
  String get partyLocked => 'Bloqueado';

  @override
  String get partyRoomEpisodeReady =>
      'Este es el episodio de la sala. Todos pueden entrar desde aquí.';

  @override
  String get partyRoomEpisodeNoSource =>
      'Este es el episodio de la sala, pero todavía no hay una fuente lista.';

  @override
  String partyTapToMoveEpisode(int episodeNumber) {
    return 'Toca para mover la sala al episodio $episodeNumber.';
  }

  @override
  String get partyOnlyHostChangesEpisode =>
      'Solo el host puede cambiar el episodio de la party.';
}
