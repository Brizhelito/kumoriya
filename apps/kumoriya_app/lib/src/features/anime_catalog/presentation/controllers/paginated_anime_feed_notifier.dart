import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kumoriya_core/kumoriya_core.dart';
import 'package:kumoriya_domain/kumoriya_domain.dart';

import '../../application/use_cases/anime_catalog_use_cases.dart';
import '../providers/anime_catalog_providers.dart';

const int paginatedAnimeFeedPerPage = 24;

final paginatedAnimeFeedProvider = NotifierProvider.autoDispose
    .family<
      PaginatedAnimeFeedNotifier,
      PaginatedAnimeFeedState,
      AnimeBrowseRequest
    >((request) => PaginatedAnimeFeedNotifier(request));

final class PaginatedAnimeFeedState {
  const PaginatedAnimeFeedState({
    required this.request,
    this.items = const <Anime>[],
    this.isLoadingFirstPage = false,
    this.isLoadingMore = false,
    this.hasReachedEnd = false,
    this.error,
  });

  final AnimeBrowseRequest request;
  final List<Anime> items;
  final bool isLoadingFirstPage;
  final bool isLoadingMore;
  final bool hasReachedEnd;
  final KumoriyaError? error;

  bool get isInitialEmpty => items.isEmpty && !isLoadingFirstPage;

  PaginatedAnimeFeedState copyWith({
    AnimeBrowseRequest? request,
    List<Anime>? items,
    bool? isLoadingFirstPage,
    bool? isLoadingMore,
    bool? hasReachedEnd,
    Object? error = _sentinel,
  }) {
    return PaginatedAnimeFeedState(
      request: request ?? this.request,
      items: items ?? this.items,
      isLoadingFirstPage: isLoadingFirstPage ?? this.isLoadingFirstPage,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasReachedEnd: hasReachedEnd ?? this.hasReachedEnd,
      error: identical(error, _sentinel) ? this.error : error as KumoriyaError?,
    );
  }
}

const Object _sentinel = Object();

final class PaginatedAnimeFeedNotifier
    extends Notifier<PaginatedAnimeFeedState> {
  PaginatedAnimeFeedNotifier(this._initialRequest);

  final AnimeBrowseRequest _initialRequest;
  late BrowseAnimeUseCase _browseAnime;

  @override
  PaginatedAnimeFeedState build() {
    _browseAnime = ref.watch(browseAnimeUseCaseProvider);
    final request = _initialRequest.copyWith(
      page: 1,
      perPage: paginatedAnimeFeedPerPage,
    );
    Future<void>.microtask(loadFirstPage);
    return PaginatedAnimeFeedState(request: request, isLoadingFirstPage: true);
  }

  Future<void> refresh() => loadFirstPage();

  Future<void> loadFirstPage() async {
    final request = state.request.copyWith(page: 1);
    state = PaginatedAnimeFeedState(request: request, isLoadingFirstPage: true);
    final result = await _browseAnime.call(request);
    if (!ref.mounted) return;
    result.fold(
      onSuccess: (items) {
        state = PaginatedAnimeFeedState(
          request: request,
          items: _dedupe(items),
          hasReachedEnd: items.length < request.perPage,
        );
      },
      onFailure: (error) {
        state = PaginatedAnimeFeedState(request: request, error: error);
      },
    );
  }

  Future<void> loadNextPage() async {
    if (state.isLoadingFirstPage ||
        state.isLoadingMore ||
        state.hasReachedEnd ||
        state.error != null && state.items.isEmpty) {
      return;
    }
    final request = state.request.copyWith(page: state.request.page + 1);
    state = state.copyWith(isLoadingMore: true, error: null);
    final result = await _browseAnime.call(request);
    if (!ref.mounted) return;
    result.fold(
      onSuccess: (items) {
        state = state.copyWith(
          request: request,
          items: _dedupe(<Anime>[...state.items, ...items]),
          isLoadingMore: false,
          hasReachedEnd: items.length < request.perPage,
          error: null,
        );
      },
      onFailure: (error) {
        state = state.copyWith(isLoadingMore: false, error: error);
      },
    );
  }

  List<Anime> _dedupe(List<Anime> items) {
    final seen = <int>{};
    final deduped = <Anime>[];
    for (final item in items) {
      if (seen.add(item.anilistId)) {
        deduped.add(item);
      }
    }
    return List<Anime>.unmodifiable(deduped);
  }
}
