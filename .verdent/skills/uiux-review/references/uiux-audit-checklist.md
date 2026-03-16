# UI/UX Audit Checklist (Kumoriya)

## Screen-Level

- Is the primary action visually dominant?
- Is the information order aligned with the user decision flow?
- Is section spacing consistent and intentional (using theme tokens)?
- Are labels explicit about outcomes (not generic "OK" or "Continue")?
- Is there a clear next step in every branch?
- Is cognitive load managed (reduce simultaneous choices, remove non-essential noise)?

## State-Level

- Loading: Is progress visible and contextual? Is page structure preserved (skeleton/shimmer)?
- Empty: Is absence explained with a recovery action?
- Error: Is cause communicated in user language without leaking technical details?
- Retry: Is retry visible, clearly labeled, and safe to repeat?
- Unavailable: Is fallback or alternative path offered?

## Interaction

- Do tappable elements have proper touch targets (48dp minimum)?
- Are action affordances visible (buttons look tappable, links look clickable)?
- Is post-action feedback visible (loading indicators, success confirmation)?
- Are there dead ends where no clear next action exists?

## Consistency

- Typography levels follow Material 3 intent and project tokens.
- Buttons, cards, chips, and list items behave consistently across screens.
- Similar flows use similar interaction patterns.
- EN/ES copy remains concise and clear in both languages.

## Kumoriya Failure Cases

- Source unavailable state is explicit and non-blocking.
- No match state avoids false confidence ("No match found" not "Match failed").
- No server links state prevents user confusion about next action.
- Resolver error state offers retry and fallback messaging.
- Multiple failures in sequence do not create confusing stacked error states.

## Platform

- Android-first touch ergonomics (thumb-friendly primary actions).
- Windows mouse interaction is usable (hover states, click targets).
- No horizontal scrolling required for primary content.
