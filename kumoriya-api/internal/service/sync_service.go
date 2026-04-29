package service

import (
	"context"
	"sync"
	"time"

	"github.com/google/uuid"
	"github.com/rs/zerolog/log"

	"go-fiber-microservice/internal/model"
	"go-fiber-microservice/internal/repository"
)

// durableCursors tracks, per user, the highest client-assigned timestamp
// that has already been persisted to Neon for each sync entity. The client
// uses these cursors to prune its local sync queue without risk of data loss.
//
// On process start the map is empty; entries are lazy-rehydrated from Neon
// the first time a user pulls or pushes, and thereafter advanced only by
// successful Flush operations.
type durableCursors struct {
	mu         sync.Mutex
	perUser    map[uuid.UUID]*model.DurableUntil
	rehydrated map[uuid.UUID]bool
}

func newDurableCursors() *durableCursors {
	return &durableCursors{
		perUser:    make(map[uuid.UUID]*model.DurableUntil),
		rehydrated: make(map[uuid.UUID]bool),
	}
}

// get returns a snapshot of the cursors for a user. It rehydrates from the
// repository on first access after process start.
func (d *durableCursors) get(ctx context.Context, repo *repository.SyncRepo, userID uuid.UUID) model.DurableUntil {
	d.mu.Lock()
	if d.rehydrated[userID] {
		cur := d.perUser[userID]
		d.mu.Unlock()
		if cur == nil {
			return model.DurableUntil{}
		}
		return *cur
	}
	d.mu.Unlock()

	// Rehydrate outside the lock — reads Neon.
	max, err := repo.MaxDurableTimestamps(ctx, userID)
	if err != nil {
		log.Warn().Err(err).Str("user_id", userID.String()).Msg("durable cursor rehydrate failed; returning zero")
		return model.DurableUntil{}
	}

	d.mu.Lock()
	defer d.mu.Unlock()
	if existing, ok := d.perUser[userID]; ok {
		// Another caller rehydrated in parallel; take the max.
		mergeDurable(existing, max)
	} else {
		cp := max
		d.perUser[userID] = &cp
	}
	d.rehydrated[userID] = true
	return *d.perUser[userID]
}

// advance monotonically bumps the cursors for a user with observed timestamps
// that have just been upserted.
func (d *durableCursors) advance(userID uuid.UUID, ep, wh, pp, le, mle, mcp, mrh int64) {
	d.mu.Lock()
	defer d.mu.Unlock()
	cur, ok := d.perUser[userID]
	if !ok {
		cur = &model.DurableUntil{}
		d.perUser[userID] = cur
	}
	if ep > cur.EpisodeProgress {
		cur.EpisodeProgress = ep
	}
	if wh > cur.WatchHistory {
		cur.WatchHistory = wh
	}
	if pp > cur.PlaybackPreference {
		cur.PlaybackPreference = pp
	}
	if le > cur.LibraryEntry {
		cur.LibraryEntry = le
	}
	if mle > cur.MangaLibraryEntry {
		cur.MangaLibraryEntry = mle
	}
	if mcp > cur.MangaChapterProgress {
		cur.MangaChapterProgress = mcp
	}
	if mrh > cur.MangaReadHistory {
		cur.MangaReadHistory = mrh
	}
}

// clear drops the cached cursors for a user, e.g. on account deletion.
func (d *durableCursors) clear(userID uuid.UUID) {
	d.mu.Lock()
	defer d.mu.Unlock()
	delete(d.perUser, userID)
	delete(d.rehydrated, userID)
}

func mergeDurable(dst *model.DurableUntil, src model.DurableUntil) {
	if src.EpisodeProgress > dst.EpisodeProgress {
		dst.EpisodeProgress = src.EpisodeProgress
	}
	if src.WatchHistory > dst.WatchHistory {
		dst.WatchHistory = src.WatchHistory
	}
	if src.PlaybackPreference > dst.PlaybackPreference {
		dst.PlaybackPreference = src.PlaybackPreference
	}
	if src.LibraryEntry > dst.LibraryEntry {
		dst.LibraryEntry = src.LibraryEntry
	}
	if src.MangaLibraryEntry > dst.MangaLibraryEntry {
		dst.MangaLibraryEntry = src.MangaLibraryEntry
	}
	if src.MangaChapterProgress > dst.MangaChapterProgress {
		dst.MangaChapterProgress = src.MangaChapterProgress
	}
	if src.MangaReadHistory > dst.MangaReadHistory {
		dst.MangaReadHistory = src.MangaReadHistory
	}
}

type SyncService struct {
	repo     *repository.SyncRepo
	cache    *pullCache
	buffer   *writeBuffer
	durable  *durableCursors
	DebugLog bool
}

func NewSyncService(repo *repository.SyncRepo) *SyncService {
	return &SyncService{
		repo:    repo,
		cache:   newPullCache(),
		buffer:  newWriteBuffer(),
		durable: newDurableCursors(),
	}
}

func (s *SyncService) Pull(ctx context.Context, userID uuid.UUID, since int64) (*model.SyncPullResponse, error) {
	resp, err := s.pullCore(ctx, userID, since)
	if err != nil {
		return nil, err
	}
	resp.DurableUntil = s.durable.get(ctx, s.repo, userID)
	return resp, nil
}

func (s *SyncService) pullCore(ctx context.Context, userID uuid.UUID, since int64) (*model.SyncPullResponse, error) {
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
	mle, err := s.repo.PullMangaLibraryEntries(ctx, userID, since)
	if err != nil {
		return nil, err
	}
	mcp, err := s.repo.PullMangaChapterProgress(ctx, userID, since)
	if err != nil {
		return nil, err
	}
	mrh, err := s.repo.PullMangaReadHistory(ctx, userID, since)
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
	if mle == nil {
		mle = []model.MangaLibraryEntry{}
	}
	if mcp == nil {
		mcp = []model.MangaChapterProgress{}
	}
	if mrh == nil {
		mrh = []model.MangaReadHistory{}
	}

	return &model.SyncPullResponse{
		ServerTime:           nowMillis(),
		EpisodeProgress:      ep,
		WatchHistory:         wh,
		PlaybackPreferences:  pp,
		LibraryEntries:       le,
		MangaLibraryEntries:  mle,
		MangaChapterProgress: mcp,
		MangaReadHistory:     mrh,
	}, nil
}

func (s *SyncService) Push(ctx context.Context, userID uuid.UUID, req *model.SyncPushRequest) (*model.SyncPushResponse, error) {
	total := len(req.EpisodeProgress) + len(req.WatchHistory) +
		len(req.PlaybackPreferences) + len(req.LibraryEntries) +
		len(req.WatchHistoryDeletions) + len(req.LibraryEntryDeletions)

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

	// 3. Return the latest durability cursors so the client can prune its
	//    queue for rows already safe on Neon (possibly from previous flushes).
	durable := s.durable.get(ctx, s.repo, userID)

	return &model.SyncPushResponse{
		Applied:      absorbed,
		Conflicts:    nil,
		DurableUntil: durable,
	}, nil
}

// Flush drains the write buffer and persists all buffered data to Neon in one burst.
// On per-user success it advances the durable-cursor map so the next push/pull
// can tell the client which entries are safe to prune locally.
func (s *SyncService) Flush(ctx context.Context) {
	dirty := s.buffer.drainAll()
	if dirty == nil {
		return
	}

	log.Info().Int("users", len(dirty)).Msg("sync flush: starting")
	totalOps := 0
	totalErrs := 0

	for userID, bp := range dirty {
		var maxEP, maxWH, maxPP, maxLE int64
		var maxMLE, maxMCP, maxMRH int64

		for _, ep := range bp.Episodes {
			if _, err := s.repo.UpsertEpisodeProgress(ctx, userID, ep); err != nil {
				log.Error().Err(err).Str("user_id", userID.String()).Msg("sync flush: episode_progress error")
				totalErrs++
				continue
			}
			if ep.UpdatedAt > maxEP {
				maxEP = ep.UpdatedAt
			}
			totalOps++
		}
		for _, wh := range bp.History {
			if _, err := s.repo.UpsertWatchHistory(ctx, userID, wh); err != nil {
				log.Error().Err(err).Str("user_id", userID.String()).Msg("sync flush: watch_history error")
				totalErrs++
				continue
			}
			if wh.LastAccessedAt > maxWH {
				maxWH = wh.LastAccessedAt
			}
			totalOps++
		}
		for _, pp := range bp.Prefs {
			if _, err := s.repo.UpsertPlaybackPreference(ctx, userID, pp); err != nil {
				log.Error().Err(err).Str("user_id", userID.String()).Msg("sync flush: playback_preference error")
				totalErrs++
				continue
			}
			if pp.UpdatedAt > maxPP {
				maxPP = pp.UpdatedAt
			}
			totalOps++
		}
		for _, le := range bp.Library {
			if _, err := s.repo.UpsertLibraryEntry(ctx, userID, le); err != nil {
				log.Error().Err(err).Str("user_id", userID.String()).Msg("sync flush: library_entry error")
				totalErrs++
				continue
			}
			if le.UpdatedAt > maxLE {
				maxLE = le.UpdatedAt
			}
			totalOps++
		}
		for _, d := range bp.HistoryDel {
			if err := s.repo.DeleteWatchHistory(ctx, userID, d.AnilistID, d.UpdatedAt); err != nil {
				log.Error().Err(err).Str("user_id", userID.String()).Msg("sync flush: watch_history deletion error")
				totalErrs++
				continue
			}
			if d.UpdatedAt > maxWH {
				maxWH = d.UpdatedAt
			}
			totalOps++
		}
		for _, d := range bp.LibraryDel {
			if err := s.repo.DeleteLibraryEntry(ctx, userID, d.AnilistID, d.UpdatedAt); err != nil {
				log.Error().Err(err).Str("user_id", userID.String()).Msg("sync flush: library_entry deletion error")
				totalErrs++
				continue
			}
			if d.UpdatedAt > maxLE {
				maxLE = d.UpdatedAt
			}
			totalOps++
		}

		// --- Manga universe (Slice 10C-2) ---
		for _, le := range bp.MangaLibrary {
			if _, err := s.repo.UpsertMangaLibraryEntry(ctx, userID, le); err != nil {
				log.Error().Err(err).Str("user_id", userID.String()).Msg("sync flush: manga_library_entry error")
				totalErrs++
				continue
			}
			if le.UpdatedAt > maxMLE {
				maxMLE = le.UpdatedAt
			}
			totalOps++
		}
		for _, cp := range bp.MangaProgress {
			if _, err := s.repo.UpsertMangaChapterProgress(ctx, userID, cp); err != nil {
				log.Error().Err(err).Str("user_id", userID.String()).Msg("sync flush: manga_chapter_progress error")
				totalErrs++
				continue
			}
			if cp.UpdatedAt > maxMCP {
				maxMCP = cp.UpdatedAt
			}
			totalOps++
		}
		for _, rh := range bp.MangaHistory {
			if _, err := s.repo.UpsertMangaReadHistory(ctx, userID, rh); err != nil {
				log.Error().Err(err).Str("user_id", userID.String()).Msg("sync flush: manga_read_history error")
				totalErrs++
				continue
			}
			if rh.LastAccessedAt > maxMRH {
				maxMRH = rh.LastAccessedAt
			}
			totalOps++
		}
		for _, d := range bp.MangaLibraryDel {
			if err := s.repo.DeleteMangaLibraryEntry(ctx, userID, d.MangaAnilistID, d.UpdatedAt); err != nil {
				log.Error().Err(err).Str("user_id", userID.String()).Msg("sync flush: manga_library_entry deletion error")
				totalErrs++
				continue
			}
			if d.UpdatedAt > maxMLE {
				maxMLE = d.UpdatedAt
			}
			totalOps++
		}
		for _, d := range bp.MangaHistoryDel {
			if err := s.repo.DeleteMangaReadHistory(ctx, userID, d.MangaAnilistID, d.UpdatedAt); err != nil {
				log.Error().Err(err).Str("user_id", userID.String()).Msg("sync flush: manga_read_history deletion error")
				totalErrs++
				continue
			}
			if d.UpdatedAt > maxMRH {
				maxMRH = d.UpdatedAt
			}
			totalOps++
		}

		s.durable.advance(userID, maxEP, maxWH, maxPP, maxLE, maxMLE, maxMCP, maxMRH)
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
		EpisodeProgress:            make([]model.EpisodeProgress, 0, len(bp.Episodes)),
		WatchHistory:               make([]model.WatchHistory, 0, len(bp.History)),
		PlaybackPreferences:        make([]model.PlaybackPreference, 0, len(bp.Prefs)),
		LibraryEntries:             make([]model.LibraryEntry, 0, len(bp.Library)),
		WatchHistoryDeletions:      make([]model.WatchHistoryDeletion, 0, len(bp.HistoryDel)),
		LibraryEntryDeletions:      make([]model.LibraryEntryDeletion, 0, len(bp.LibraryDel)),
		MangaLibraryEntries:        make([]model.MangaLibraryEntry, 0, len(bp.MangaLibrary)),
		MangaChapterProgress:       make([]model.MangaChapterProgress, 0, len(bp.MangaProgress)),
		MangaReadHistory:           make([]model.MangaReadHistory, 0, len(bp.MangaHistory)),
		MangaLibraryEntryDeletions: make([]model.MangaLibraryEntryDeletion, 0, len(bp.MangaLibraryDel)),
		MangaReadHistoryDeletions:  make([]model.MangaReadHistoryDeletion, 0, len(bp.MangaHistoryDel)),
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
	for _, d := range bp.HistoryDel {
		req.WatchHistoryDeletions = append(req.WatchHistoryDeletions, model.WatchHistoryDeletion{AnilistID: d.AnilistID, UpdatedAt: d.UpdatedAt})
	}
	for _, d := range bp.LibraryDel {
		req.LibraryEntryDeletions = append(req.LibraryEntryDeletions, model.LibraryEntryDeletion{AnilistID: d.AnilistID, UpdatedAt: d.UpdatedAt})
	}
	for _, le := range bp.MangaLibrary {
		req.MangaLibraryEntries = append(req.MangaLibraryEntries, le)
	}
	for _, cp := range bp.MangaProgress {
		req.MangaChapterProgress = append(req.MangaChapterProgress, cp)
	}
	for _, rh := range bp.MangaHistory {
		req.MangaReadHistory = append(req.MangaReadHistory, rh)
	}
	for _, d := range bp.MangaLibraryDel {
		req.MangaLibraryEntryDeletions = append(req.MangaLibraryEntryDeletions,
			model.MangaLibraryEntryDeletion{MangaAnilistID: d.MangaAnilistID, UpdatedAt: d.UpdatedAt})
	}
	for _, d := range bp.MangaHistoryDel {
		req.MangaReadHistoryDeletions = append(req.MangaReadHistoryDeletions,
			model.MangaReadHistoryDeletion{MangaAnilistID: d.MangaAnilistID, UpdatedAt: d.UpdatedAt})
	}
	return req
}

func nowMillis() int64 {
	return time.Now().UnixMilli()
}
