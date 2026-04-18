package service

import (
	"context"
	"time"

	"github.com/google/uuid"
	"github.com/rs/zerolog/log"

	"go-fiber-microservice/internal/model"
	"go-fiber-microservice/internal/repository"
)

type SyncService struct {
	repo     *repository.SyncRepo
	cache    *pullCache
	buffer   *writeBuffer
	DebugLog bool
}

func NewSyncService(repo *repository.SyncRepo) *SyncService {
	return &SyncService{repo: repo, cache: newPullCache(), buffer: newWriteBuffer()}
}

func (s *SyncService) Pull(ctx context.Context, userID uuid.UUID, since int64) (*model.SyncPullResponse, error) {
	// Try the in-memory cache first to avoid hitting Neon.
	if snap, ok := s.cache.get(userID); ok {
		if s.DebugLog {
			log.Debug().Str("user_id", userID.String()).Int64("since", since).Msg("sync pull: cache hit")
		}
		return filterBySince(snap.resp, since), nil
	}

	if s.DebugLog {
		log.Debug().Str("user_id", userID.String()).Int64("since", since).Msg("sync pull: cache miss, fetching from DB")
	}

	// Cache miss — fetch full snapshot (since=0) from Neon.
	full, err := s.pullFromDB(ctx, userID, 0)
	if err != nil {
		return nil, err
	}

	s.cache.set(userID, full)

	// If this user has buffered writes not yet flushed to Neon, merge them
	// into the cached snapshot so pulls include recent pushes.
	if buf := s.buffer.peek(userID); buf != nil {
		s.cache.merge(userID, bufferedPushToRequest(buf))
		if s.DebugLog {
			log.Debug().Str("user_id", userID.String()).Msg("sync pull: merged buffered writes into cache")
		}
	}

	// Re-read the (possibly merged) snapshot.
	if snap, ok := s.cache.get(userID); ok {
		if since > 0 {
			return filterBySince(snap.resp, since), nil
		}
		return snap.resp, nil
	}

	// Return filtered if caller requested a delta.
	if since > 0 {
		return filterBySince(full, since), nil
	}
	return full, nil
}

// pullFromDB performs the raw Pull queries against Neon.
func (s *SyncService) pullFromDB(ctx context.Context, userID uuid.UUID, since int64) (*model.SyncPullResponse, error) {
	ep, err := s.repo.PullEpisodeProgress(ctx, userID, since)
	if err != nil {
		return nil, err
	}
	wh, err := s.repo.PullWatchHistory(ctx, userID, since)
	if err != nil {
		return nil, err
	}
	pp, err := s.repo.PullPlaybackPreferences(ctx, userID, since)
	if err != nil {
		return nil, err
	}
	le, err := s.repo.PullLibraryEntries(ctx, userID, since)
	if err != nil {
		return nil, err
	}

	if ep == nil {
		ep = []model.EpisodeProgress{}
	}
	if wh == nil {
		wh = []model.WatchHistory{}
	}
	if pp == nil {
		pp = []model.PlaybackPreference{}
	}
	if le == nil {
		le = []model.LibraryEntry{}
	}

	return &model.SyncPullResponse{
		ServerTime:          nowMillis(),
		EpisodeProgress:     ep,
		WatchHistory:        wh,
		PlaybackPreferences: pp,
		LibraryEntries:      le,
	}, nil
}

func (s *SyncService) Push(ctx context.Context, userID uuid.UUID, req *model.SyncPushRequest) (*model.SyncPushResponse, error) {
	total := len(req.EpisodeProgress) + len(req.WatchHistory) +
		len(req.PlaybackPreferences) + len(req.LibraryEntries) +
		len(req.WatchHistoryDeletions)

	// 1. Absorb into RAM buffer (LWW merge).
	absorbed := s.buffer.absorb(userID, req)

	// 2. Update the pull cache so subsequent reads include this data.
	s.cache.merge(userID, req)

	if s.DebugLog {
		log.Debug().
			Str("user_id", userID.String()).
			Int("total", total).
			Int("absorbed", absorbed).
			Msg("sync push: buffered (write-behind)")
	}

	return &model.SyncPushResponse{
		Applied:   absorbed,
		Conflicts: nil,
	}, nil
}

// Flush drains the write buffer and persists all buffered data to Neon in one burst.
func (s *SyncService) Flush(ctx context.Context) {
	dirty := s.buffer.drainAll()
	if dirty == nil {
		return
	}

	log.Info().Int("users", len(dirty)).Msg("sync flush: starting")
	totalOps := 0
	totalErrs := 0

	for userID, bp := range dirty {
		for _, ep := range bp.Episodes {
			if _, err := s.repo.UpsertEpisodeProgress(ctx, userID, ep); err != nil {
				log.Error().Err(err).Str("user_id", userID.String()).Msg("sync flush: episode_progress error")
				totalErrs++
			} else {
				totalOps++
			}
		}
		for _, wh := range bp.History {
			if _, err := s.repo.UpsertWatchHistory(ctx, userID, wh); err != nil {
				log.Error().Err(err).Str("user_id", userID.String()).Msg("sync flush: watch_history error")
				totalErrs++
			} else {
				totalOps++
			}
		}
		for _, pp := range bp.Prefs {
			if _, err := s.repo.UpsertPlaybackPreference(ctx, userID, pp); err != nil {
				log.Error().Err(err).Str("user_id", userID.String()).Msg("sync flush: playback_preference error")
				totalErrs++
			} else {
				totalOps++
			}
		}
		for _, le := range bp.Library {
			if _, err := s.repo.UpsertLibraryEntry(ctx, userID, le); err != nil {
				log.Error().Err(err).Str("user_id", userID.String()).Msg("sync flush: library_entry error")
				totalErrs++
			} else {
				totalOps++
			}
		}
		for anilistID := range bp.Deletions {
			if err := s.repo.DeleteWatchHistory(ctx, userID, anilistID); err != nil {
				log.Error().Err(err).Str("user_id", userID.String()).Msg("sync flush: watch_history deletion error")
				totalErrs++
			} else {
				totalOps++
			}
		}
	}

	log.Info().Int("ops", totalOps).Int("errors", totalErrs).Msg("sync flush: completed")
}

// FlushLoop runs Flush every flushInterval until ctx is cancelled.
// On cancellation it performs one final flush before returning.
func (s *SyncService) FlushLoop(ctx context.Context, flushInterval time.Duration) {
	ticker := time.NewTicker(flushInterval)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			log.Info().Msg("sync flush loop: shutting down, final flush")
			s.Flush(context.Background())
			return
		case <-ticker.C:
			s.Flush(ctx)
		}
	}
}

// bufferedPushToRequest converts a bufferedPush back into a SyncPushRequest
// for use with cache.merge().
func bufferedPushToRequest(bp *bufferedPush) *model.SyncPushRequest {
	req := &model.SyncPushRequest{
		EpisodeProgress:       make([]model.EpisodeProgress, 0, len(bp.Episodes)),
		WatchHistory:          make([]model.WatchHistory, 0, len(bp.History)),
		PlaybackPreferences:   make([]model.PlaybackPreference, 0, len(bp.Prefs)),
		LibraryEntries:        make([]model.LibraryEntry, 0, len(bp.Library)),
		WatchHistoryDeletions: make([]model.WatchHistoryDeletion, 0, len(bp.Deletions)),
	}
	for _, ep := range bp.Episodes {
		req.EpisodeProgress = append(req.EpisodeProgress, ep)
	}
	for _, wh := range bp.History {
		req.WatchHistory = append(req.WatchHistory, wh)
	}
	for _, pp := range bp.Prefs {
		req.PlaybackPreferences = append(req.PlaybackPreferences, pp)
	}
	for _, le := range bp.Library {
		req.LibraryEntries = append(req.LibraryEntries, le)
	}
	for anilistID := range bp.Deletions {
		req.WatchHistoryDeletions = append(req.WatchHistoryDeletions, model.WatchHistoryDeletion{AnilistID: anilistID})
	}
	return req
}

func nowMillis() int64 {
	return time.Now().UnixMilli()
}
