# Testing Strategy

> **Comprehensive testing approach across all tiers of the Kumoriya platform.**

---

## Table of Contents

1. [Testing Philosophy](#testing-philosophy)
2. [Flutter App Tests](#flutter-app-tests)
3. [Go API Tests](#go-api-tests)
4. [Cloudflare Worker Tests](#cloudflare-worker-tests)
5. [Test Fixtures](#test-fixtures)
6. [Property-Based Testing](#property-based-testing)
7. [Integration Testing](#integration-testing)
8. [Test Utilities](#test-utilities)

---

## Testing Philosophy

Kumoriya's testing strategy follows these principles:

1. **Test behavior, not implementation** — Tests validate contracts and outcomes
2. **Fast feedback** — Unit tests run in milliseconds, no external dependencies
3. **Realistic fixtures** — Use real HTML/JSON samples from actual sources
4. **Property-based for state machines** — Durable Objects tested with invariant properties
5. **Graceful degradation** — Tests verify error states, not just happy paths

---

## Flutter App Tests

### Test Location

All Flutter tests in `apps/kumoriya_app/test/` — **65+ test files**.

### Test Categories

#### Domain & Use Case Tests

| Test File | What It Validates |
|:---|:---|
| `check_source_availability_use_case_test.dart` | Source availability checking logic |
| `check_jkanime_availability_use_case_test.dart` | JKAnime-specific availability |
| `get_source_episode_server_links_use_case_test.dart` | Server link extraction orchestration |
| `resolve_source_server_link_use_case_test.dart` | Resolver selection and resolution |
| `start_episode_playback_use_case_test.dart` | Playback launch orchestration |
| `load_source_availability_summary_use_case_test.dart` | Availability summary loading |
| `save_progress_use_case_test.dart` | Progress persistence logic |
| `seasonal_discovery_catalog_use_case_test.dart` | Seasonal catalog discovery |

#### Plugin & Resolver Tests

| Test File | What It Validates |
|:---|:---|
| `plugin_runtime_catalog_test.dart` | Plugin registration and lookup |
| `resolver_registry_test.dart` | Resolver selection algorithm |
| `resolver_registry_real_plugins_test.dart` | Real plugin integration |
| `resolver_multi_selection_test.dart` | Multi-resolver ambiguity handling |
| `stream_selection_policy_test.dart` | Stream quality selection |

#### Storage & Sync Tests

| Test File | What It Validates |
|:---|:---|
| `storage_providers_test.dart` | Storage provider wiring |
| `sync_coordinator_test.dart` | Sync coordinator lifecycle |
| `fcm_aware_library_store_test.dart` | FCM topic management |
| `fcm_topic_test.dart` | FCM topic formatting |
| `local_user_data_cleaner_test.dart` | Account data cleanup |
| `unified_library_entry_test.dart` | Library entry unification |

#### Download Tests

| Test File | What It Validates |
|:---|:---|
| `download_manager_service_test.dart` | Download queue management |
| `download_manager_smoke_test.dart` | End-to-end download flow |
| `download_directory_service_test.dart` | Directory selection logic |
| `download_error_classifier_test.dart` | Error classification |
| `download_server_scorer_test.dart` | Server quality scoring |
| `download_library_index_service_test.dart` | Download library indexing |
| `hls_segment_downloader_test.dart` | HLS segment downloading |
| `download_hls_encoding_smoke_test.dart` | HLS encoding verification |
| `native_download_manager_service_test.dart` | Android native downloader |

#### Player Tests

| Test File | What It Validates |
|:---|:---|
| `player_session_orchestrator_test.dart` | Player session lifecycle |
| `seek_reopen_unit_test.dart` | Seek + reopen behavior |
| `seek_reopen_integration_test.dart` | Seek + reopen integration |
| `seek_reopen_preservation_test.dart` | Seek state preservation |
| `seek_reopen_pbt_test.dart` | Property-based seek testing |
| `probe_audio_kinds_test.dart` | Audio track detection |

#### Watch Party Tests

| Test File | What It Validates |
|:---|:---|
| `party_realtime_reducer_test.dart` | State reducer logic |
| `watch_party_session_guard_test.dart` | Session validation |
| `watch_party_p2p_sync_bug_exploration_test.dart` | P2P sync edge cases |
| `watch_party_p2p_sync_preservation_test.dart` | P2P sync state preservation |

#### UI & Integration Tests

| Test File | What It Validates |
|:---|:---|
| `home_airing_today_test.dart` | Home page airing section |
| `home_continue_watching_section_test.dart` | Continue watching UI |
| `home_continue_watching_desktop_test.dart` | Desktop continue watching |
| `paginated_anime_feed_notifier_test.dart` | Infinite scroll pagination |
| `offline_banner_integration_test.dart` | Offline fallback banner |
| `universe_theming_test.dart` | Universe theme switching |
| `vertical_slice_1a_app_test.dart` | App-level smoke test |
| `widget_test.dart` | Basic widget test |

#### Matching Tests

| Test File | What It Validates |
|:---|:---|
| `bulk_matching_dataset_regression_test.dart` | Bulk matching regression |
| `browser_dataset_probe_test.dart` | Browser-based matching probe |

#### Service Tests

| Test File | What It Validates |
|:---|:---|
| `app_update_service_test.dart` | OTA update checking |
| `auto_download_new_episodes_service_test.dart` | Auto-download logic |
| `background_source_availability_warmup_service_test.dart` | Cache prewarming |
| `backend_first_anilist_gateway_test.dart` | API gateway fallback |
| `dynamic_translation_service_test.dart` | Title translation |
| `episode_display_title_test.dart` | Episode title formatting |
| `mal_metadata_bridge_service_test.dart` | Metadata bridge |
| `playback_launch_flow_test.dart` | Playback launch orchestration |
| `current_airing_availability_probe_test.dart` | Airing status probing |
| `composite_manga_catalog_repository_test.dart` | Manga catalog composition |

#### Manga Tests

| Test File | What It Validates |
|:---|:---|
| `manga_library_providers_test.dart` | Manga library providers |
| `cbz_packer_test.dart` | CBZ archive creation |
| `manga_download_manager_test.dart` | Manga download flow |
| `sync_aware_manga_stores_test.dart` | Manga sync integration |

---

## Go API Tests

### Test Location

Tests co-located with source files in `kumoriya-api/internal/`.

### Test Categories

#### Handler Tests

| Test File | What It Validates |
|:---|:---|
| `auth_handler_test.go` | Registration, OAuth, passkey endpoints |
| `sync_handler_test.go` | Push/pull sync endpoints |
| `profile_handler_test.go` | Profile CRUD operations |
| `release_handler_test.go` | Release manifest, publish |
| `notifications_admin_handler_test.go` | Admin notification test endpoint |
| `health_handler_test.go` | AniList health proxy |

#### Service Tests

| Test File | What It Validates |
|:---|:---|
| `auth_service_test.go` | Authentication business logic |
| `jwt_service_test.go` | Token creation, validation, expiry |
| `sync_buffer_test.go` | Write-behind buffer behavior |
| `sync_buffer_manga_test.go` | Manga sync buffer |
| `party_broker_test.go` | Worker HTTP client |
| `party_session_test.go` | Session token issuance |
| `home_service_test.go` | Home feed aggregation |

#### Model Tests

| Test File | What It Validates |
|:---|:---|
| `sync_validation_test.go` | Sync entity validation |
| `sync_normalize_test.go` | Entity normalization |
| `sync_manga_test.go` | Manga sync models |

#### Middleware Tests

| Test File | What It Validates |
|:---|:---|
| `ratelimit_test.go` | Rate limiting behavior |

#### Integration Tests

| Test File | What It Validates |
|:---|:---|
| `home_service_integration_test.go` | AniList API integration |
| `fcm_sender_integration_test.go` | Firebase Cloud Messaging |
| `upstash_integration_test.go` | Redis operations |

#### Worker Tests

| Test File | What It Validates |
|:---|:---|
| `airing_worker_test.go` | Airing notification logic |

#### Cache Tests

| Test File | What It Validates |
|:---|:---|
| `swr_test.go` | Stale-While-Revalidate cache |

---

## Cloudflare Worker Tests

### Test Location

Tests in `infra/watch-party-realtime/src/__tests__/`.

### Unit Tests (Vitest)

| Test File | Coverage |
|:---|:---|
| `session-token.test.ts` | Token creation, verification, expiry, invalid signatures |
| `PartyRegistryDO.test.ts` | Room creation, invite resolution, duplicate prevention |
| `PartyRoomDO-presence.test.ts` | Join, leave, heartbeat, grace periods |
| `playback-sync.test.ts` | Play/pause/seek state synchronization |
| `host-authority.test.ts` | Host transfer, host-only operations |
| `ready-state.test.ts` | Ready persistence, effective ready computation |
| `media-episode-change.test.ts` | Media state transitions |
| `rate-limit.test.ts` | Token bucket behavior, rate limit enforcement |
| `ack-errors.test.ts` | Message ACK, error responses |
| `heartbeat-auto-response.test.ts` | Hibernation bypass verification |

### Property-Based Tests

| Test File | Property Verified |
|:---|:---|
| `room-creation-uniqueness.test.ts` | No two rooms share an invite code |
| `invite-code-determinism.test.ts` | Same room ID → same invite code |
| `playback-monotonicity.test.ts` | Playback position never goes backward |
| `ready-state-consistency.test.ts` | effectiveReady implies readyPersisted |
| `host-authority.test.ts` | Exactly one host exists at all times |
| `grace-period-preservation.test.ts` | Grace period expires exactly on schedule |
| `media-change-resets.test.ts` | Media change resets ready states |
| `reconnection-state-restoration.test.ts` | Reconnecting member receives full state |

---

## Test Fixtures

### HTML Fixtures

Source and resolver plugins use **real HTML samples** from actual websites:

- Stored alongside plugin code
- Represent known-good page structures
- Enable offline testing without network calls
- Updated when source websites change their DOM

### JSON Fixtures

API and sync tests use fixture JSON:

- AniList GraphQL responses
- Sync push/pull payloads
- Release manifest examples

### Matching Datasets

Curated datasets for matching engine validation:

| Dataset | Source | Entries |
|:---|:---|:---|
| `browser_validated_matching_dataset_2026-03-17.json` | Browser-validated matches | Manual verification |
| `bulk_matching_observation_dataset_2026-03-12.json` | Bulk scrape observation | Automated collection |
| `manual_search_seed_dataset_2026-03-12.json` | Manual search seeds | Hand-picked test cases |
| `emulator_chrome_runtime_probe_2026-03-12.json` | Emulator Chrome probe | Runtime verification |

---

## Property-Based Testing

### Concept

Instead of testing specific inputs, property-based tests verify **invariants** that must hold for all valid states:

```
Traditional test:
  "When host leaves, member X becomes host"

Property-based test:
  "For any room state with ≥1 member, exactly one member has role='host'"
```

### Durable Object Properties

The Watch Party Durable Objects are ideal candidates for property-based testing because they are **state machines with clear invariants**:

1. **Host uniqueness:** Exactly one host at all times
2. **Playback monotonicity:** Position never decreases within same episode
3. **Ready consistency:** effectiveReady → readyPersisted
4. **Grace period determinism:** Expiry time = disconnect_time + grace_period
5. **Room identity:** Room ID ↔ Invite code is bijective
6. **State restoration:** Reconnecting member receives complete state

---

## Integration Testing

### Flutter Integration

- **AniList API:** Tests verify real API responses match expected schemas
- **Source plugins:** Tests with live (or recently cached) HTML
- **Resolver plugins:** Tests with live hosting service pages
- **Player:** Seek/reopen integration tests with real media files

### Go API Integration

- **AniList GraphQL:** Integration tests hit real AniList API
- **FCM:** Integration tests send real push notifications (test device)
- **Redis:** Integration tests verify Upstash Redis operations

### Worker Integration

- **WebSocket lifecycle:** Full connect → message → disconnect flows
- **Multi-member scenarios:** 2+ concurrent WebSocket connections
- **Grace period behavior:** Time-based integration tests

---

## Test Utilities

### `kumoriya_testing` Package

Shared testing utilities in `packages/kumoriya_testing/`:

- **`FakeClock`:** Controllable clock for time-dependent tests
- **Test fixtures:** Common test data factories
- **Mock helpers:** Streamlined mock creation

### Resolver CLI (`tools/resolver_cli/`)

Command-line tool for resolver testing:

- **`benchmark_all.dart`:** Benchmark all resolvers against test URLs
- **`download_playground.dart`:** Test download pipeline end-to-end
- **`resolver_cli.dart`:** Interactive resolver testing

### Runtime Analysis (`tools/anime-nexus-runtime-node/`)

Node.js tools for runtime behavior analysis:

- **`liveMatrix.mjs`:** Live testing matrix
- **`smoke.mjs`:** Quick smoke tests
- **`ws-auth-test.mjs`:** WebSocket auth testing
