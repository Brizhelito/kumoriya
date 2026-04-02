package service

import (
	"context"
	"time"

	"github.com/google/uuid"

	"go-fiber-microservice/internal/model"
	"go-fiber-microservice/internal/repository"
)

type SyncService struct {
	repo *repository.SyncRepo
}

func NewSyncService(repo *repository.SyncRepo) *SyncService {
	return &SyncService{repo: repo}
}

func (s *SyncService) Pull(ctx context.Context, userID uuid.UUID, since int64) (*model.SyncPullResponse, error) {
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
	applied := 0
	var conflicts []string

	for _, ep := range req.EpisodeProgress {
		ok, err := s.repo.UpsertEpisodeProgress(ctx, userID, ep)
		if err != nil {
			conflicts = append(conflicts, err.Error())
			continue
		}
		if ok {
			applied++
		}
	}

	for _, wh := range req.WatchHistory {
		ok, err := s.repo.UpsertWatchHistory(ctx, userID, wh)
		if err != nil {
			conflicts = append(conflicts, err.Error())
			continue
		}
		if ok {
			applied++
		}
	}

	for _, pp := range req.PlaybackPreferences {
		ok, err := s.repo.UpsertPlaybackPreference(ctx, userID, pp)
		if err != nil {
			conflicts = append(conflicts, err.Error())
			continue
		}
		if ok {
			applied++
		}
	}

	for _, le := range req.LibraryEntries {
		ok, err := s.repo.UpsertLibraryEntry(ctx, userID, le)
		if err != nil {
			conflicts = append(conflicts, err.Error())
			continue
		}
		if ok {
			applied++
		}
	}

	return &model.SyncPushResponse{
		Applied:   applied,
		Conflicts: conflicts,
	}, nil
}

func nowMillis() int64 {
	return time.Now().UnixMilli()
}
