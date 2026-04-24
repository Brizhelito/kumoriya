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
			Android: &service.AndroidDownloadsResponse{
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

func TestReleasePublishWithABIsplits(t *testing.T) {
	repo := newFakeReleaseRepo()
	svc := service.NewReleaseService(repo, "")
	h := NewReleaseHandler(svc, "test-token")

	app := fiber.New()
	app.Post("/internal/releases/publish", h.Publish)
	app.Get("/releases/latest", h.GetManifest)
	app.Get("/releases/:tag", h.GetByTag)

	universalURL := "https://cdn.example/kumoriya-0.2.1-universal.apk"
	arm64URL := "https://cdn.example/kumoriya-0.2.1-arm64-v8a.apk"
	armv7URL := "https://cdn.example/kumoriya-0.2.1-armeabi-v7a.apk"
	x8664URL := "https://cdn.example/kumoriya-0.2.1-x86_64.apk"

	body := service.PublishReleaseInput{
		Version:              "0.2.1",
		Tag:                  "v0.2.1",
		Date:                 "2026-04-24",
		Channel:              "alpha",
		ManifestReleaseNotes: "v0.2.1 available",
		Summary: service.ReleaseSummary{
			ES: "Resumen",
			EN: "Summary",
		},
		NotesMarkdown: service.ReleaseMarkdownNotes{
			ES: "# v0.2.1\n",
			EN: "# v0.2.1\n",
		},
		Downloads: service.ReleaseDownloadsResponse{
			Android: &service.AndroidDownloadsResponse{
				Universal: &service.ReleaseArtifactResponse{
					URL:       universalURL,
					FileName:  "kumoriya-0.2.1-universal.apk",
					SizeBytes: 50_000_000,
				},
				ABIs: map[string]*service.ReleaseArtifactResponse{
					"arm64_v8a":   {URL: arm64URL, FileName: "kumoriya-0.2.1-arm64-v8a.apk", SizeBytes: 42_000_000},
					"armeabi_v7a": {URL: armv7URL, FileName: "kumoriya-0.2.1-armeabi-v7a.apk", SizeBytes: 35_000_000},
					"x86_64":      {URL: x8664URL, FileName: "kumoriya-0.2.1-x86_64.apk", SizeBytes: 45_000_000},
				},
			},
		},
	}

	raw, err := json.Marshal(body)
	if err != nil {
		t.Fatalf("marshal: %v", err)
	}
	req := httptest.NewRequest("POST", "/internal/releases/publish", bytes.NewReader(raw))
	req.Header.Set("Authorization", "Bearer test-token")
	req.Header.Set("Content-Type", "application/json")
	resp, err := app.Test(req)
	if err != nil {
		t.Fatalf("publish: %v", err)
	}
	if resp.StatusCode != fiber.StatusOK {
		t.Fatalf("publish status = %d", resp.StatusCode)
	}

	// /releases/latest should expose url (= universal) + abis map.
	resp, err = app.Test(httptest.NewRequest("GET", "/releases/latest", nil))
	if err != nil {
		t.Fatalf("latest: %v", err)
	}
	var latest service.LatestManifestResponse
	if err := json.NewDecoder(resp.Body).Decode(&latest); err != nil {
		t.Fatalf("decode latest: %v", err)
	}
	if latest.Android == nil {
		t.Fatal("expected android manifest")
	}
	if latest.Android.URL != universalURL {
		t.Fatalf("latest.android.url = %q, want universal %q", latest.Android.URL, universalURL)
	}
	if latest.Android.Universal == nil || latest.Android.Universal.URL != universalURL {
		t.Fatal("expected universal artifact in latest")
	}
	for abi, expectedURL := range map[string]string{
		"arm64_v8a":   arm64URL,
		"armeabi_v7a": armv7URL,
		"x86_64":      x8664URL,
	} {
		got, ok := latest.Android.ABIs[abi]
		if !ok || got == nil {
			t.Fatalf("missing abi %s in latest manifest", abi)
		}
		if got.URL != expectedURL {
			t.Fatalf("abi %s url = %q, want %q", abi, got.URL, expectedURL)
		}
	}

	// /releases/:tag mirrors the same shape under downloads.android.
	resp, err = app.Test(httptest.NewRequest("GET", "/releases/v0.2.1", nil))
	if err != nil {
		t.Fatalf("by tag: %v", err)
	}
	var detail service.ReleaseDetailsResponse
	if err := json.NewDecoder(resp.Body).Decode(&detail); err != nil {
		t.Fatalf("decode detail: %v", err)
	}
	if detail.Downloads.Android == nil {
		t.Fatal("expected android downloads")
	}
	if detail.Downloads.Android.URL != universalURL {
		t.Fatalf("downloads.android.url = %q, want universal", detail.Downloads.Android.URL)
	}
	if detail.Downloads.Android.Universal == nil {
		t.Fatal("expected universal slot in downloads")
	}
	if len(detail.Downloads.Android.ABIs) != 3 {
		t.Fatalf("abis count = %d, want 3", len(detail.Downloads.Android.ABIs))
	}
}

func TestReleasePublishLegacyFlatAndroidShape(t *testing.T) {
	// Older publish scripts send `downloads.android: {url, file_name, r2_key}`
	// (no universal/abis). Ensure backward compatibility: the URL gets
	// promoted to the universal slot and `latest.android.url` echoes it.
	repo := newFakeReleaseRepo()
	svc := service.NewReleaseService(repo, "")
	h := NewReleaseHandler(svc, "test-token")

	app := fiber.New()
	app.Post("/internal/releases/publish", h.Publish)
	app.Get("/releases/latest", h.GetManifest)

	raw := []byte(`{
		"version": "0.2.2",
		"tag": "v0.2.2",
		"date": "2026-04-24",
		"channel": "alpha",
		"manifest_release_notes": "legacy publish",
		"summary": {"es": "es", "en": "en"},
		"notes_markdown": {"es": "# es", "en": "# en"},
		"downloads": {
			"android": {
				"url": "https://cdn.example/legacy.apk",
				"file_name": "legacy.apk",
				"r2_key": "artifacts/android/v0.2.2/legacy.apk"
			}
		}
	}`)

	req := httptest.NewRequest("POST", "/internal/releases/publish", bytes.NewReader(raw))
	req.Header.Set("Authorization", "Bearer test-token")
	req.Header.Set("Content-Type", "application/json")
	resp, err := app.Test(req)
	if err != nil {
		t.Fatalf("publish: %v", err)
	}
	if resp.StatusCode != fiber.StatusOK {
		t.Fatalf("publish status = %d", resp.StatusCode)
	}

	resp, err = app.Test(httptest.NewRequest("GET", "/releases/latest", nil))
	if err != nil {
		t.Fatalf("latest: %v", err)
	}
	var latest service.LatestManifestResponse
	if err := json.NewDecoder(resp.Body).Decode(&latest); err != nil {
		t.Fatalf("decode: %v", err)
	}
	if latest.Android == nil || latest.Android.URL != "https://cdn.example/legacy.apk" {
		t.Fatalf("legacy url not promoted; got %+v", latest.Android)
	}
	if latest.Android.Universal == nil || latest.Android.Universal.URL != "https://cdn.example/legacy.apk" {
		t.Fatal("expected legacy url to populate universal slot")
	}
	if len(latest.Android.ABIs) != 0 {
		t.Fatalf("expected no abis, got %d", len(latest.Android.ABIs))
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
