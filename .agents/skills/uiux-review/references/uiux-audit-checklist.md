# UI/UX Audit Checklist (Kumoriya)

## Screen-Level

- Is the primary action visually dominant?
- Is the information order aligned with the user decision flow?
- Is section spacing consistent and intentional?
- Are labels explicit about outcomes?
- Is there a clear next step in every branch?

## State-Level

- Loading: Is progress visible and contextual?
- Empty: Is absence explained with a recovery action?
- Error: Is cause communicated without leaking technical noise?
- Retry: Is retry visible and safe to repeat?
- Unavailable: Is fallback or alternative path offered?

## Consistency

- Typography levels follow Material 3 intent and project tokens.
- Buttons, cards, chips, and list items behave consistently across screens.
- Similar flows use similar interaction patterns.
- EN/ES copy remains concise and clear in both languages.

## Kumoriya Failure Cases

- Source unavailable state is explicit and non-blocking.
- No match state avoids false confidence.
- No server links state prevents user confusion about next action.
- Resolver error state offers retry and fallback messaging.
