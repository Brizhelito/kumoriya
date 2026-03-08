# Codex Prompt - Playback Pipeline

Goal:
After source plugins are stable, implement:
- episode -> server links
- resolver selection
- playback session creation
- player handoff

Constraints:
- WebView remains last-resort infrastructure
- do not mix resolver logic into UI or player widgets
