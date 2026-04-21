# Kumoriya

Plugin-first otaku platform: anime streaming/download, manga, offline-first, Android + Windows.

## Non-negotiables

1. AniList is canonical metadata. Prefer no match over false match.
2. Prefer no stream over wrong stream.
3. Plugins are first-class. Source plugins, resolver plugins and the player are independent.
4. UI depends on contracts, never on concrete plugins or storage.
5. WebView is last-resort infra, not a UX primitive.
6. Work in vertical slices. No blind copy from legacy.

## How to work here

- Small scoped diffs. Conventional commits. One concern per commit.
- Before declaring a task done: run format, analyze, relevant tests. Report residual risk honestly.
- Use the matching skills for consult on specific areas — do not restate their rules here.

## Skills

Canonical skills live in `.agents/skills/`. They load on demand via progressive disclosure. Invoke them when the task matches their description. Key ones: `anilist-matching`, `source-plugin-jkanime`, `resolver-plugin`, `resolver-runtime-audit`, `player-slice`, `storage-drift`, `flutter-vertical-slice`, `uiux-review`, `validate-task`, `changelog-release-notes`, `dev-diary`.
