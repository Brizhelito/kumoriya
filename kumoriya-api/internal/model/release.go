package model

import "time"

type ReleaseArtifact struct {
	URL      string `json:"url"`
	FileName string `json:"file_name,omitempty"`
	R2Key    string `json:"r2_key,omitempty"`
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
	Android              *ReleaseArtifact
	Windows              *ReleaseArtifact
	IsLatest             bool
	CreatedAt            time.Time
	UpdatedAt            time.Time
}
