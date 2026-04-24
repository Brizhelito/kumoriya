package model

import "time"

// Canonical ABI identifiers used across the release pipeline.
// Keep in sync with:
//   - migrations/013_app_releases_android_abis.sql (CHECK constraint)
//   - the Flutter updater ABI selection map.
const (
	AndroidABIUniversal  = "universal"
	AndroidABIArm64V8a   = "arm64_v8a"
	AndroidABIArmeabiV7a = "armeabi_v7a"
	AndroidABIX86_64     = "x86_64"
)

type ReleaseArtifact struct {
	URL       string `json:"url"`
	FileName  string `json:"file_name,omitempty"`
	R2Key     string `json:"r2_key,omitempty"`
	SizeBytes int64  `json:"size_bytes,omitempty"`
	SHA256    string `json:"sha256,omitempty"`
}

// AndroidArtifacts groups the universal APK plus any per-ABI splits for a
// release. Consumers should prefer the most-specific ABI match and fall back
// to Universal when nothing matches.
type AndroidArtifacts struct {
	Universal *ReleaseArtifact
	ABIs      map[string]*ReleaseArtifact
}

// Primary returns the URL that clients unaware of ABI splits should download.
// Prefers the universal APK; falls back to arm64-v8a (modern phones) when no
// universal is published.
func (a *AndroidArtifacts) Primary() *ReleaseArtifact {
	if a == nil {
		return nil
	}
	if a.Universal != nil && a.Universal.URL != "" {
		return a.Universal
	}
	for _, abi := range []string{AndroidABIArm64V8a, AndroidABIArmeabiV7a, AndroidABIX86_64} {
		if art, ok := a.ABIs[abi]; ok && art != nil && art.URL != "" {
			return art
		}
	}
	return nil
}

// IsEmpty reports whether no artifacts at all are present.
func (a *AndroidArtifacts) IsEmpty() bool {
	if a == nil {
		return true
	}
	if a.Universal != nil && a.Universal.URL != "" {
		return false
	}
	for _, art := range a.ABIs {
		if art != nil && art.URL != "" {
			return false
		}
	}
	return true
}

type ReleaseRecord struct {
	Tag                  string
	Version              string
	Channel              string
	ReleaseDate          time.Time
	ManifestReleaseNotes string
	SummaryES            string
	SummaryEN            string
	NotesESMarkdown      string
	NotesENMarkdown      string
	Android              *AndroidArtifacts
	Windows              *ReleaseArtifact
	IsLatest             bool
	CreatedAt            time.Time
	UpdatedAt            time.Time
}
