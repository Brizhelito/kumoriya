package repository

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"go-fiber-microservice/internal/model"
)

var ErrReleaseNotFound = errors.New("release not found")

type ReleaseRepo struct {
	pool *pgxpool.Pool
}

func NewReleaseRepo(pool *pgxpool.Pool) *ReleaseRepo {
	return &ReleaseRepo{pool: pool}
}

func (r *ReleaseRepo) UpsertRelease(ctx context.Context, release model.ReleaseRecord) error {
	tx, err := r.pool.BeginTx(ctx, pgx.TxOptions{})
	if err != nil {
		return fmt.Errorf("begin release tx: %w", err)
	}
	defer func() {
		_ = tx.Rollback(ctx)
	}()

	if release.IsLatest {
		if _, err := tx.Exec(
			ctx,
			`UPDATE app_releases
			 SET is_latest = FALSE,
			     updated_at = now()
			 WHERE is_latest = TRUE
			   AND tag <> $1`,
			release.Tag,
		); err != nil {
			return fmt.Errorf("clear latest release: %w", err)
		}
	}

	// Mirror the universal APK (or best fallback) into the legacy android_*
	// columns so older consumers keep working without reading the child
	// table.
	legacyAndroid := release.Android.Primary()

	_, err = tx.Exec(
		ctx,
		`INSERT INTO app_releases (
			tag, version, channel, release_date, manifest_release_notes,
			summary_es, summary_en, notes_es_markdown, notes_en_markdown,
			android_url, android_file_name, android_r2_key,
			windows_url, windows_file_name, windows_r2_key,
			is_latest, updated_at
		) VALUES (
			$1, $2, $3, $4, $5,
			$6, $7, $8, $9,
			$10, $11, $12,
			$13, $14, $15,
			$16, now()
		)
		ON CONFLICT (tag) DO UPDATE SET
			version = EXCLUDED.version,
			channel = EXCLUDED.channel,
			release_date = EXCLUDED.release_date,
			manifest_release_notes = EXCLUDED.manifest_release_notes,
			summary_es = EXCLUDED.summary_es,
			summary_en = EXCLUDED.summary_en,
			notes_es_markdown = EXCLUDED.notes_es_markdown,
			notes_en_markdown = EXCLUDED.notes_en_markdown,
			android_url = EXCLUDED.android_url,
			android_file_name = EXCLUDED.android_file_name,
			android_r2_key = EXCLUDED.android_r2_key,
			windows_url = EXCLUDED.windows_url,
			windows_file_name = EXCLUDED.windows_file_name,
			windows_r2_key = EXCLUDED.windows_r2_key,
			is_latest = EXCLUDED.is_latest,
			updated_at = now()`,
		release.Tag,
		release.Version,
		release.Channel,
		release.ReleaseDate.UTC(),
		release.ManifestReleaseNotes,
		release.SummaryES,
		release.SummaryEN,
		release.NotesESMarkdown,
		release.NotesENMarkdown,
		artifactURL(legacyAndroid),
		artifactFileName(legacyAndroid),
		artifactR2Key(legacyAndroid),
		artifactURL(release.Windows),
		artifactFileName(release.Windows),
		artifactR2Key(release.Windows),
		release.IsLatest,
	)
	if err != nil {
		return fmt.Errorf("upsert release: %w", err)
	}

	// Rewrite the Android artifact child rows for this tag.
	if _, err := tx.Exec(
		ctx,
		`DELETE FROM app_release_android_artifacts WHERE tag = $1`,
		release.Tag,
	); err != nil {
		return fmt.Errorf("clear android artifacts: %w", err)
	}

	if release.Android != nil {
		if err := insertAndroidArtifact(ctx, tx, release.Tag, model.AndroidABIUniversal, release.Android.Universal); err != nil {
			return err
		}
		for _, abi := range []string{model.AndroidABIArm64V8a, model.AndroidABIArmeabiV7a, model.AndroidABIX86_64} {
			if err := insertAndroidArtifact(ctx, tx, release.Tag, abi, release.Android.ABIs[abi]); err != nil {
				return err
			}
		}
	}

	if err := tx.Commit(ctx); err != nil {
		return fmt.Errorf("commit release tx: %w", err)
	}
	return nil
}

func insertAndroidArtifact(ctx context.Context, tx pgx.Tx, tag, abi string, artifact *model.ReleaseArtifact) error {
	if artifact == nil || artifact.URL == "" {
		return nil
	}
	_, err := tx.Exec(
		ctx,
		`INSERT INTO app_release_android_artifacts (
			tag, abi, url, file_name, r2_key, size_bytes, sha256, updated_at
		) VALUES ($1, $2, $3, $4, $5, $6, $7, now())`,
		tag,
		abi,
		artifact.URL,
		artifact.FileName,
		artifact.R2Key,
		artifact.SizeBytes,
		artifact.SHA256,
	)
	if err != nil {
		return fmt.Errorf("insert android artifact %s: %w", abi, err)
	}
	return nil
}

func (r *ReleaseRepo) GetLatestRelease(ctx context.Context) (*model.ReleaseRecord, error) {
	release, err := r.getOne(
		ctx,
		`SELECT tag, version, channel, release_date, manifest_release_notes,
		        summary_es, summary_en, notes_es_markdown, notes_en_markdown,
		        android_url, android_file_name, android_r2_key,
		        windows_url, windows_file_name, windows_r2_key,
		        is_latest, created_at, updated_at
		   FROM app_releases
		  WHERE is_latest = TRUE
		  LIMIT 1`,
	)
	if err != nil {
		return nil, err
	}
	if err := r.loadAndroidArtifacts(ctx, []*model.ReleaseRecord{release}); err != nil {
		return nil, err
	}
	return release, nil
}

func (r *ReleaseRepo) GetReleaseByTag(ctx context.Context, tag string) (*model.ReleaseRecord, error) {
	release, err := r.getOne(
		ctx,
		`SELECT tag, version, channel, release_date, manifest_release_notes,
		        summary_es, summary_en, notes_es_markdown, notes_en_markdown,
		        android_url, android_file_name, android_r2_key,
		        windows_url, windows_file_name, windows_r2_key,
		        is_latest, created_at, updated_at
		   FROM app_releases
		  WHERE tag = $1
		  LIMIT 1`,
		tag,
	)
	if err != nil {
		return nil, err
	}
	if err := r.loadAndroidArtifacts(ctx, []*model.ReleaseRecord{release}); err != nil {
		return nil, err
	}
	return release, nil
}

func (r *ReleaseRepo) ListReleases(ctx context.Context, limit int) ([]model.ReleaseRecord, error) {
	if limit <= 0 {
		limit = 20
	}
	rows, err := r.pool.Query(
		ctx,
		`SELECT tag, version, channel, release_date, manifest_release_notes,
		        summary_es, summary_en, notes_es_markdown, notes_en_markdown,
		        android_url, android_file_name, android_r2_key,
		        windows_url, windows_file_name, windows_r2_key,
		        is_latest, created_at, updated_at
		   FROM app_releases
		  ORDER BY release_date DESC, created_at DESC
		  LIMIT $1`,
		limit,
	)
	if err != nil {
		return nil, fmt.Errorf("list releases: %w", err)
	}
	defer rows.Close()

	var releases []model.ReleaseRecord
	for rows.Next() {
		release, err := scanRelease(rows)
		if err != nil {
			return nil, err
		}
		releases = append(releases, release)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterate releases: %w", err)
	}

	pointers := make([]*model.ReleaseRecord, len(releases))
	for i := range releases {
		pointers[i] = &releases[i]
	}
	if err := r.loadAndroidArtifacts(ctx, pointers); err != nil {
		return nil, err
	}

	return releases, nil
}

func (r *ReleaseRepo) loadAndroidArtifacts(ctx context.Context, releases []*model.ReleaseRecord) error {
	if len(releases) == 0 {
		return nil
	}
	tags := make([]string, 0, len(releases))
	index := make(map[string]*model.ReleaseRecord, len(releases))
	for _, rec := range releases {
		if rec == nil {
			continue
		}
		tags = append(tags, rec.Tag)
		index[rec.Tag] = rec
		// Ensure every record starts with the fallback from legacy columns
		// (populated by scanRelease) promoted into the new container. This
		// guarantees the universal slot is set even for rows whose child
		// artifacts have not been migrated yet.
		if rec.Android == nil {
			rec.Android = &model.AndroidArtifacts{ABIs: map[string]*model.ReleaseArtifact{}}
		}
	}

	rows, err := r.pool.Query(
		ctx,
		`SELECT tag, abi, url, file_name, r2_key, size_bytes, sha256
		   FROM app_release_android_artifacts
		  WHERE tag = ANY($1)`,
		tags,
	)
	if err != nil {
		return fmt.Errorf("load android artifacts: %w", err)
	}
	defer rows.Close()

	for rows.Next() {
		var (
			tag, abi, url, fileName, r2Key, sha256 string
			size                                   int64
		)
		if err := rows.Scan(&tag, &abi, &url, &fileName, &r2Key, &size, &sha256); err != nil {
			return fmt.Errorf("scan android artifact: %w", err)
		}
		rec, ok := index[tag]
		if !ok {
			continue
		}
		artifact := &model.ReleaseArtifact{
			URL:       url,
			FileName:  fileName,
			R2Key:     r2Key,
			SizeBytes: size,
			SHA256:    sha256,
		}
		if abi == model.AndroidABIUniversal {
			rec.Android.Universal = artifact
		} else {
			if rec.Android.ABIs == nil {
				rec.Android.ABIs = map[string]*model.ReleaseArtifact{}
			}
			rec.Android.ABIs[abi] = artifact
		}
	}
	if err := rows.Err(); err != nil {
		return fmt.Errorf("iterate android artifacts: %w", err)
	}

	// If no child rows were present and the container is empty, drop it so
	// consumers can distinguish "no android" from "empty container".
	for _, rec := range releases {
		if rec.Android != nil && rec.Android.IsEmpty() {
			rec.Android = nil
		}
	}
	return nil
}

func (r *ReleaseRepo) getOne(ctx context.Context, sql string, args ...any) (*model.ReleaseRecord, error) {
	row := r.pool.QueryRow(ctx, sql, args...)
	release, err := scanRelease(row)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrReleaseNotFound
		}
		return nil, err
	}
	return &release, nil
}

type releaseScanner interface {
	Scan(dest ...any) error
}

func scanRelease(scanner releaseScanner) (model.ReleaseRecord, error) {
	var (
		release                             model.ReleaseRecord
		releaseDate                         time.Time
		androidURL, androidFile, androidKey sqlNullString
		windowsURL, windowsFile, windowsKey sqlNullString
	)

	err := scanner.Scan(
		&release.Tag,
		&release.Version,
		&release.Channel,
		&releaseDate,
		&release.ManifestReleaseNotes,
		&release.SummaryES,
		&release.SummaryEN,
		&release.NotesESMarkdown,
		&release.NotesENMarkdown,
		&androidURL,
		&androidFile,
		&androidKey,
		&windowsURL,
		&windowsFile,
		&windowsKey,
		&release.IsLatest,
		&release.CreatedAt,
		&release.UpdatedAt,
	)
	if err != nil {
		return model.ReleaseRecord{}, err
	}

	release.ReleaseDate = releaseDate.UTC()
	if legacyAndroid := toArtifact(androidURL, androidFile, androidKey); legacyAndroid != nil {
		release.Android = &model.AndroidArtifacts{
			Universal: legacyAndroid,
			ABIs:      map[string]*model.ReleaseArtifact{},
		}
	}
	release.Windows = toArtifact(windowsURL, windowsFile, windowsKey)
	return release, nil
}

type sqlNullString struct {
	String string
	Valid  bool
}

func (s *sqlNullString) Scan(src any) error {
	switch v := src.(type) {
	case nil:
		s.String = ""
		s.Valid = false
	case string:
		s.String = v
		s.Valid = true
	case []byte:
		s.String = string(v)
		s.Valid = true
	default:
		return fmt.Errorf("unsupported null string type %T", src)
	}
	return nil
}

func toArtifact(url, fileName, r2Key sqlNullString) *model.ReleaseArtifact {
	if !url.Valid || url.String == "" {
		return nil
	}
	return &model.ReleaseArtifact{
		URL:      url.String,
		FileName: fileName.String,
		R2Key:    r2Key.String,
	}
}

func artifactURL(a *model.ReleaseArtifact) any {
	if a == nil || a.URL == "" {
		return nil
	}
	return a.URL
}

func artifactFileName(a *model.ReleaseArtifact) any {
	if a == nil || a.FileName == "" {
		return nil
	}
	return a.FileName
}

func artifactR2Key(a *model.ReleaseArtifact) any {
	if a == nil || a.R2Key == "" {
		return nil
	}
	return a.R2Key
}
