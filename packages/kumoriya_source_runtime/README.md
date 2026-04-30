# kumoriya_source_runtime

Shared runtime helpers for Kumoriya source plugins.

## Scope

- **MirrorList** — ordered, non-empty list of equivalent base URIs for a single source.
- **MirrorRotator** — wraps a request closure so a transport-classified failure on the current mirror transparently retries the next one.
- **TransportFailure** — classifies an exception as either "transport" (retryable across mirrors) or "non-transport" (parse, 4xx, 5xx-with-body — surfaced unchanged).

Source plugins consume this package to honor user base-URL overrides and to survive mirror outages without exposing rotation to upstream callers.

Out of scope (future):
- Per-mirror health probing / circuit breaker (M4).
- Settings UI / persistence — handled at the app layer.
