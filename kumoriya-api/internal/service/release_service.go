package service

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"strings"
	"sync"
	"time"

	"go-fiber-microservice/internal/model"
	"go-fiber-microservice/internal/repository"
)

type ReleaseRepo interface {
	UpsertRelease(ctx context.Context, release model.ReleaseRecord) error
	GetLatestRelease(ctx context.Context) (*model.ReleaseRecord, error)
	GetReleaseByTag(ctx context.Context, tag string) (*model.ReleaseRecord, error)
	ListReleases(ctx context.Context, limit int) ([]model.ReleaseRecord, error)
}

type ReleaseService struct {
	repo        ReleaseRepo
	fallbackURL string
	client      *http.Client

	mu     sync.RWMutex
	latest *LatestManifestResponse
	feed   *ReleaseFeedResponse
	byTag  map[string]ReleaseDetailsResponse
}

func NewReleaseService(repo ReleaseRepo, fallbackURL string) *ReleaseService {
	return &ReleaseService{
		repo:        repo,
		fallbackURL: fallbackURL,
		client:      &http.Client{Timeout: 10 * time.Second},
		byTag:       make(map[string]ReleaseDetailsResponse),
	}
}

type PlatformLatestManifest struct {
	LatestVersion string `json:"latest_version"`
	URL           string `json:"url"`
	ReleaseNotes  string `json:"release_notes"`
}

type LatestManifestResponse struct {
	Android *PlatformLatestManifest `json:"android,omitempty"`
	Windows *PlatformLatestManifest `json:"windows,omitempty"`
}

type ReleaseSummary struct {
	ES string `json:"es"`
	EN string `json:"en"`
}

type ReleaseMarkdownNotes struct {
	ES string `json:"es"`
	EN string `json:"en"`
}

type ReleaseArtifactResponse struct {
	URL      string `json:"url"`
	FileName string `json:"file_name,omitempty"`
	R2Key    string `json:"r2_key,omitempty"`
}

type ReleaseDownloadsResponse struct {
	Android *ReleaseArtifactResponse `json:"android,omitempty"`
	Windows *ReleaseArtifactResponse `json:"windows,omitempty"`
}

type ReleaseDetailsResponse struct {
	Version   string                   `json:"version"`
	Tag       string                   `json:"tag"`
	Date      string                   `json:"date"`
	Channel   string                   `json:"channel"`
	IsLatest  bool                     `json:"is_latest"`
	Manifest  string                   `json:"manifest_release_notes"`
	Summary   ReleaseSummary           `json:"summary"`
	Notes     ReleaseMarkdownNotes     `json:"notes_markdown"`
	Downloads ReleaseDownloadsResponse `json:"downloads"`
}

type ReleaseFeedResponse struct {
	GeneratedAt string                   `json:"generated_at"`
	Latest      *ReleaseDetailsResponse  `json:"latest,omitempty"`
	Items       []ReleaseDetailsResponse `json:"items"`
}

type PublishReleaseInput struct {
	Version              string                   `json:"version"`
	Tag                  string                   `json:"tag"`
	Date                 string                   `json:"date"`
	Channel              string                   `json:"channel"`
	ManifestReleaseNotes string                   `json:"manifest_release_notes"`
	Summary              ReleaseSummary           `json:"summary"`
	NotesMarkdown        ReleaseMarkdownNotes     `json:"notes_markdown"`
	Downloads            ReleaseDownloadsResponse `json:"downloads"`
	IsLatest             *bool                    `json:"is_latest,omitempty"`
}

func (s *ReleaseService) Warm(ctx context.Context) error {
	if s.repo == nil {
		return nil
	}
	latest, err := s.repo.GetLatestRelease(ctx)
	if err != nil {
		if errors.Is(err, repository.ErrReleaseNotFound) {
			return nil
		}
		return fmt.Errorf("load latest release: %w", err)
	}
	releases, err := s.repo.ListReleases(ctx, 50)
	if err != nil {
		return fmt.Errorf("load release feed: %w", err)
	}
	s.storeSnapshots(latest, releases)
	return nil
}

func (s *ReleaseService) Publish(ctx context.Context, input PublishReleaseInput) error {
	record, err := validatePublishInput(input)
	if err != nil {
		return err
	}
	if err := s.repo.UpsertRelease(ctx, record); err != nil {
		return err
	}

	latest, err := s.repo.GetLatestRelease(ctx)
	if err != nil {
		return fmt.Errorf("reload latest release: %w", err)
	}
	releases, err := s.repo.ListReleases(ctx, 50)
	if err != nil {
		return fmt.Errorf("reload release feed: %w", err)
	}
	s.storeSnapshots(latest, releases)
	return nil
}

func (s *ReleaseService) GetLatestManifest(ctx context.Context) (*LatestManifestResponse, error) {
	s.mu.RLock()
	latest := s.latest
	s.mu.RUnlock()
	if latest != nil {
		return cloneLatestManifest(latest), nil
	}
	if s.fallbackURL == "" {
		return nil, repository.ErrReleaseNotFound
	}
	return s.fetchFallbackManifest(ctx)
}

func (s *ReleaseService) GetFeed() (*ReleaseFeedResponse, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	if s.feed == nil {
		return nil, repository.ErrReleaseNotFound
	}
	out := *s.feed
	out.Items = append([]ReleaseDetailsResponse(nil), s.feed.Items...)
	return &out, nil
}

func (s *ReleaseService) GetRelease(tag string) (*ReleaseDetailsResponse, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	release, ok := s.byTag[tag]
	if !ok {
		return nil, repository.ErrReleaseNotFound
	}
	out := release
	return &out, nil
}

func (s *ReleaseService) storeSnapshots(latest *model.ReleaseRecord, releases []model.ReleaseRecord) {
	latestManifest := buildLatestManifest(latest)
	feed := ReleaseFeedResponse{
		GeneratedAt: time.Now().UTC().Format(time.RFC3339),
		Items:       make([]ReleaseDetailsResponse, 0, len(releases)),
	}
	byTag := make(map[string]ReleaseDetailsResponse, len(releases))
	for _, release := range releases {
		item := buildReleaseDetails(release)
		if release.IsLatest {
			itemCopy := item
			feed.Latest = &itemCopy
		}
		feed.Items = append(feed.Items, item)
		byTag[release.Tag] = item
	}
	if feed.Latest == nil && latest != nil {
		item := buildReleaseDetails(*latest)
		feed.Latest = &item
	}

	s.mu.Lock()
	defer s.mu.Unlock()
	s.latest = latestManifest
	s.feed = &feed
	s.byTag = byTag
}

func buildLatestManifest(release *model.ReleaseRecord) *LatestManifestResponse {
	if release == nil {
		return nil
	}
	resp := &LatestManifestResponse{}
	if release.Android != nil && release.Android.URL != "" {
		resp.Android = &PlatformLatestManifest{
			LatestVersion: release.Version,
			URL:           release.Android.URL,
			ReleaseNotes:  release.ManifestReleaseNotes,
		}
	}
	if release.Windows != nil && release.Windows.URL != "" {
		resp.Windows = &PlatformLatestManifest{
			LatestVersion: release.Version,
			URL:           release.Windows.URL,
			ReleaseNotes:  release.ManifestReleaseNotes,
		}
	}
	return resp
}

func buildReleaseDetails(release model.ReleaseRecord) ReleaseDetailsResponse {
	return ReleaseDetailsResponse{
		Version:  release.Version,
		Tag:      release.Tag,
		Date:     release.ReleaseDate.UTC().Format("2006-01-02"),
		Channel:  release.Channel,
		IsLatest: release.IsLatest,
		Manifest: release.ManifestReleaseNotes,
		Summary: ReleaseSummary{
			ES: release.SummaryES,
			EN: release.SummaryEN,
		},
		Notes: ReleaseMarkdownNotes{
			ES: release.NotesESMarkdown,
			EN: release.NotesENMarkdown,
		},
		Downloads: ReleaseDownloadsResponse{
			Android: buildArtifactResponse(release.Android),
			Windows: buildArtifactResponse(release.Windows),
		},
	}
}

func buildArtifactResponse(artifact *model.ReleaseArtifact) *ReleaseArtifactResponse {
	if artifact == nil || artifact.URL == "" {
		return nil
	}
	return &ReleaseArtifactResponse{
		URL:      artifact.URL,
		FileName: artifact.FileName,
		R2Key:    artifact.R2Key,
	}
}

func validatePublishInput(input PublishReleaseInput) (model.ReleaseRecord, error) {
	version := strings.TrimSpace(input.Version)
	tag := strings.TrimSpace(input.Tag)
	if version == "" || tag == "" {
		return model.ReleaseRecord{}, errors.New("version and tag are required")
	}
	if !strings.HasPrefix(tag, "v") || strings.TrimPrefix(tag, "v") != version {
		return model.ReleaseRecord{}, errors.New("tag must match version as vX.Y.Z")
	}
	releaseDate, err := time.Parse("2006-01-02", strings.TrimSpace(input.Date))
	if err != nil {
		return model.ReleaseRecord{}, errors.New("date must use YYYY-MM-DD")
	}
	channel := strings.TrimSpace(input.Channel)
	if channel == "" {
		channel = "alpha"
	}
	manifest := strings.TrimSpace(input.ManifestReleaseNotes)
	if manifest == "" {
		return model.ReleaseRecord{}, errors.New("manifest_release_notes is required")
	}
	if strings.TrimSpace(input.Summary.ES) == "" || strings.TrimSpace(input.Summary.EN) == "" {
		return model.ReleaseRecord{}, errors.New("summary.es and summary.en are required")
	}
	if strings.TrimSpace(input.NotesMarkdown.ES) == "" || strings.TrimSpace(input.NotesMarkdown.EN) == "" {
		return model.ReleaseRecord{}, errors.New("notes_markdown.es and notes_markdown.en are required")
	}
	if input.Downloads.Android == nil && input.Downloads.Windows == nil {
		return model.ReleaseRecord{}, errors.New("at least one download artifact is required")
	}

	isLatest := true
	if input.IsLatest != nil {
		isLatest = *input.IsLatest
	}

	return model.ReleaseRecord{
		Tag:                  tag,
		Version:              version,
		Channel:              channel,
		ReleaseDate:          releaseDate.UTC(),
		ManifestReleaseNotes: manifest,
		SummaryES:            strings.TrimSpace(input.Summary.ES),
		SummaryEN:            strings.TrimSpace(input.Summary.EN),
		NotesESMarkdown:      input.NotesMarkdown.ES,
		NotesENMarkdown:      input.NotesMarkdown.EN,
		Android:              toModelArtifact(input.Downloads.Android),
		Windows:              toModelArtifact(input.Downloads.Windows),
		IsLatest:             isLatest,
	}, nil
}

func toModelArtifact(artifact *ReleaseArtifactResponse) *model.ReleaseArtifact {
	if artifact == nil || strings.TrimSpace(artifact.URL) == "" {
		return nil
	}
	return &model.ReleaseArtifact{
		URL:      strings.TrimSpace(artifact.URL),
		FileName: strings.TrimSpace(artifact.FileName),
		R2Key:    strings.TrimSpace(artifact.R2Key),
	}
}

func (s *ReleaseService) fetchFallbackManifest(ctx context.Context) (*LatestManifestResponse, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, s.fallbackURL, nil)
	if err != nil {
		return nil, fmt.Errorf("build fallback request: %w", err)
	}
	resp, err := s.client.Do(req)
	if err != nil {
		return nil, fmt.Errorf("fetch fallback manifest: %w", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("fallback manifest returned %s", resp.Status)
	}
	body, err := io.ReadAll(io.LimitReader(resp.Body, 64*1024))
	if err != nil {
		return nil, fmt.Errorf("read fallback manifest: %w", err)
	}
	var manifest LatestManifestResponse
	if err := json.Unmarshal(body, &manifest); err != nil {
		return nil, fmt.Errorf("decode fallback manifest: %w", err)
	}
	return &manifest, nil
}

func cloneLatestManifest(in *LatestManifestResponse) *LatestManifestResponse {
	if in == nil {
		return nil
	}
	out := *in
	if in.Android != nil {
		android := *in.Android
		out.Android = &android
	}
	if in.Windows != nil {
		windows := *in.Windows
		out.Windows = &windows
	}
	return &out
}
