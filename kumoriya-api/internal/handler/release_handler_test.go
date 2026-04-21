package handler

import (
	"bytes"
	"context"
	"encoding/json"
	"net/http/httptest"
	"sort"
	"testing"
	"time"

	"github.com/gofiber/fiber/v3"

	"go-fiber-microservice/internal/model"
	"go-fiber-microservice/internal/repository"
	"go-fiber-microservice/internal/service"
)

type fakeReleaseRepo struct {
	releases map[string]model.ReleaseRecord
}

func newFakeReleaseRepo() *fakeReleaseRepo {
	return &fakeReleaseRepo{releases: make(map[string]model.ReleaseRecord)}
}

func (f *fakeReleaseRepo) UpsertRelease(_ context.Context, release model.ReleaseRecord) error {
	if release.IsLatest {
		for tag, existing := range f.releases {
			existing.IsLatest = tag == release.Tag
			f.releases[tag] = existing
		}
	}
	now := time.Now().UTC()
	if existing, ok := f.releases[release.Tag]; ok {
		release.CreatedAt = existing.CreatedAt
	} else {
		release.CreatedAt = now
	}
	release.UpdatedAt = now
	f.releases[release.Tag] = release
	return nil
}

func (f *fakeReleaseRepo) GetLatestRelease(_ context.Context) (*model.ReleaseRecord, error) {
	for _, release := range f.releases {
		if release.IsLatest {
			copy := release
			return &copy, nil
		}
	}
	return nil, repository.ErrReleaseNotFound
}

func (f *fakeReleaseRepo) GetReleaseByTag(_ context.Context, tag string) (*model.ReleaseRecord, error) {
	release, ok := f.releases[tag]
	if !ok {
		return nil, repository.ErrReleaseNotFound
	}
	copy := release
	return &copy, nil
}

func (f *fakeReleaseRepo) ListReleases(_ context.Context, limit int) ([]model.ReleaseRecord, error) {
	if limit <= 0 {
		limit = 20
	}
	items := make([]model.ReleaseRecord, 0, len(f.releases))
	for _, release := range f.releases {
		items = append(items, release)
	}
	sort.Slice(items, func(i, j int) bool {
		if items[i].ReleaseDate.Equal(items[j].ReleaseDate) {
			return items[i].CreatedAt.After(items[j].CreatedAt)
		}
		return items[i].ReleaseDate.After(items[j].ReleaseDate)
	})
	if len(items) > limit {
		items = items[:limit]
	}
	return items, nil
}

func TestReleasePublishUpdatesLatestAndFeed(t *testing.T) {
	repo := newFakeReleaseRepo()
	svc := service.NewReleaseService(repo, "")
	h := NewReleaseHandler(svc, "test-token")

	app := fiber.New()
	app.Post("/internal/releases/publish", h.Publish)
	app.Get("/releases/latest", h.GetManifest)
	app.Get("/releases/feed", h.GetFeed)
	app.Get("/releases/:tag", h.GetByTag)

	body := service.PublishReleaseInput{
		Version:              "0.2.0",
		Tag:                  "v0.2.0",
		Date:                 "2026-04-18",
		Channel:              "alpha",
		ManifestReleaseNotes: "v0.2.0 available",
		Summary: service.ReleaseSummary{
			ES: "Resumen corto",
			EN: "Short summary",
		},
		NotesMarkdown: service.ReleaseMarkdownNotes{
			ES: "# Lanzamiento v0.2.0\n",
			EN: "# Release v0.2.0\n",
		},
		Downloads: service.ReleaseDownloadsResponse{
			Android: &service.ReleaseArtifactResponse{
				URL:      "https://cdn.example/android.apk",
				FileName: "kumoriya-0.2.0.apk",
				R2Key:    "artifacts/android/v0.2.0/kumoriya-0.2.0.apk",
			},
			Windows: &service.ReleaseArtifactResponse{
				URL:      "https://cdn.example/windows.exe",
				FileName: "Kumoriya-0.2.0-windows-x64-setup.exe",
				R2Key:    "artifacts/windows/v0.2.0/Kumoriya-0.2.0-windows-x64-setup.exe",
			},
		},
	}

	rawBody, err := json.Marshal(body)
	if err != nil {
		t.Fatalf("marshal publish body: %v", err)
	}

	req := httptest.NewRequest("POST", "/internal/releases/publish", bytes.NewReader(rawBody))
	req.Header.Set("Authorization", "Bearer test-token")
	req.Header.Set("Content-Type", "application/json")
	resp, err := app.Test(req)
	if err != nil {
		t.Fatalf("publish request failed: %v", err)
	}
	if resp.StatusCode != fiber.StatusOK {
		t.Fatalf("publish status = %d, want %d", resp.StatusCode, fiber.StatusOK)
	}

	resp, err = app.Test(httptest.NewRequest("GET", "/releases/latest", nil))
	if err != nil {
		t.Fatalf("latest request failed: %v", err)
	}
	if resp.StatusCode != fiber.StatusOK {
		t.Fatalf("latest status = %d, want %d", resp.StatusCode, fiber.StatusOK)
	}

	var latest service.LatestManifestResponse
	if err := json.NewDecoder(resp.Body).Decode(&latest); err != nil {
		t.Fatalf("decode latest: %v", err)
	}
	if latest.Android == nil || latest.Android.LatestVersion != "0.2.0" {
		t.Fatal("expected android manifest for v0.2.0")
	}
	if latest.Windows == nil || latest.Windows.URL == "" {
		t.Fatal("expected windows manifest URL")
	}

	resp, err = app.Test(httptest.NewRequest("GET", "/releases/feed", nil))
	if err != nil {
		t.Fatalf("feed request failed: %v", err)
	}
	if resp.StatusCode != fiber.StatusOK {
		t.Fatalf("feed status = %d, want %d", resp.StatusCode, fiber.StatusOK)
	}

	var feed service.ReleaseFeedResponse
	if err := json.NewDecoder(resp.Body).Decode(&feed); err != nil {
		t.Fatalf("decode feed: %v", err)
	}
	if feed.Latest == nil || feed.Latest.Tag != "v0.2.0" {
		t.Fatal("expected latest item in feed")
	}
	if len(feed.Items) != 1 {
		t.Fatalf("feed items = %d, want 1", len(feed.Items))
	}

	resp, err = app.Test(httptest.NewRequest("GET", "/releases/v0.2.0", nil))
	if err != nil {
		t.Fatalf("release by tag request failed: %v", err)
	}
	if resp.StatusCode != fiber.StatusOK {
		t.Fatalf("release by tag status = %d, want %d", resp.StatusCode, fiber.StatusOK)
	}

	var byTag service.ReleaseDetailsResponse
	if err := json.NewDecoder(resp.Body).Decode(&byTag); err != nil {
		t.Fatalf("decode release by tag: %v", err)
	}
	if byTag.Downloads.Android == nil || byTag.Downloads.Android.FileName == "" {
		t.Fatal("expected android artifact details")
	}
}

func TestReleasePublishRejectsBadToken(t *testing.T) {
	repo := newFakeReleaseRepo()
	svc := service.NewReleaseService(repo, "")
	h := NewReleaseHandler(svc, "correct-token")

	app := fiber.New()
	app.Post("/internal/releases/publish", h.Publish)

	req := httptest.NewRequest("POST", "/internal/releases/publish", bytes.NewReader([]byte(`{}`)))
	req.Header.Set("Authorization", "Bearer wrong-token")
	req.Header.Set("Content-Type", "application/json")

	resp, err := app.Test(req)
	if err != nil {
		t.Fatalf("publish request failed: %v", err)
	}
	if resp.StatusCode != fiber.StatusUnauthorized {
		t.Fatalf("status = %d, want %d", resp.StatusCode, fiber.StatusUnauthorized)
	}
}

func TestReleaseFeedNotFoundWhenEmpty(t *testing.T) {
	svc := service.NewReleaseService(newFakeReleaseRepo(), "")
	h := NewReleaseHandler(svc, "token")

	app := fiber.New()
	app.Get("/releases/feed", h.GetFeed)

	resp, err := app.Test(httptest.NewRequest("GET", "/releases/feed", nil))
	if err != nil {
		t.Fatalf("feed request failed: %v", err)
	}
	if resp.StatusCode != fiber.StatusNotFound {
		t.Fatalf("status = %d, want %d", resp.StatusCode, fiber.StatusNotFound)
	}

	var body map[string]any
	if err := json.NewDecoder(resp.Body).Decode(&body); err != nil {
		t.Fatalf("decode body: %v", err)
	}
}
