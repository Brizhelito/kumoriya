# kumoriya_manga_domain

Domain entities and repository contracts for the manga universe (manga,
manhwa, manhua, one-shots).

Parallel to `kumoriya_domain` (anime). Cross-cutting concerns shared by
both universes (library, downloads, history, sync) live in
`kumoriya_core` via `MediaKind` and dedicated unified repositories.

This package is **pure Dart**. No Flutter, no plugins, no storage, no I/O.
