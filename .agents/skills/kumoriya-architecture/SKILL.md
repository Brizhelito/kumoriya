---
name: kumoriya-architecture
description: Use when making or reviewing structural decisions for Kumoriya packages, boundaries, plugin contracts, or vertical slice scope.
---

You are enforcing Kumoriya architecture.

Goals:
- protect package boundaries
- keep plugin-first design intact
- prevent UI from depending on concrete plugin implementations
- keep playback, resolvers, storage, and scraping separated
- prefer pragmatic architecture, not ceremony

Checklist:
1. Identify packages touched.
2. Confirm whether the change crosses a boundary.
3. Reject unnecessary coupling.
4. Prefer explicit contracts.
5. Keep slices vertical and reviewable.
6. State what is intentionally left out.

Output:
- proposed package changes
- contract impacts
- risks
- minimal next step
