# Session Input Recovery

## Decision

Q-012 was replaced on 2026-10-08: unfinished activity, sleep, and review input is recoverable only within the current app or browser-page session. Android background/foreground transitions and in-app navigation keep the session; process restart, cold launch, Web reload, and reopening the page create an empty session.

The product no longer exposes a draft state, count, list, switch, keep-on-exit action, or cleanup error. Existing `RecordingDraft`, `SleepDraft`, and `ReviewDraft` names remain internal DTO/API names to avoid a non-functional rename. They are not domain states.

## Delivery order

1. `INPUT-RECOVERY-01` — update the Source of Truth, Q-012, domain, architecture, MVP, implementation plan, current UI handoff, and task contract. Historical COMPLETE reports remain unchanged.
2. `INPUT-RECOVERY-02` — provide app-owned in-memory stores for activity, sleep, and review; clear legacy input rows at upgrade startup; preserve persistent sleep-learning feedback; keep the formal five-table schema unchanged.
3. `INPUT-RECOVERY-03` — add the shared recovery choice and baseline lifecycle to all new, Gap, review, and edit contexts; remove user-visible draft language and preserve input on formal-save failure.
4. `INPUT-RECOVERY-04` — verify controller, widget, migration, Android, and Web session boundaries plus formatting, analysis, tests, builds, and diff hygiene.

## Runtime contract

- A snapshot is created only after input differs from its opening baseline. Returning every value to baseline clears it.
- Re-entering the same context asks whether to continue or restart before accepting form interaction. Edit contexts use continue modifying / restart editing language.
- Continue restores text, choices, and the activity presentation step. New-entry and Gap time endpoints are still recalculated under Q-036; edit contexts start from the current formal fact.
- Restart clears the session snapshot and uses current formal facts, goals, and time suggestions.
- A committed residual is recognized and finished without offering recovery or creating another fact. Missing originals and invalid contexts clear their session snapshot.
- Formal-save failure stays on the page with the current input. Snapshot synchronization failure says the current input may not be retained; leaving requires an explicit leave-anyway choice.
- Advanced clear includes current-session input and sleep-learning auxiliary data, while ordinary preferences remain. Data overview does not display an unfinished-input count.

## Storage and compatibility

`AppBootstrap` owns one `SessionRecordingDraftStore`, `SessionSleepDraftStore`, and `SessionReviewDraftStore` for its lifetime. No new unfinished input is written to SQLite. On startup, legacy recording, sleep, and review input rows are deleted. `sleep_learning_feedback` remains in its dedicated auxiliary database and is injected separately through `SleepLearningStore`.

The formal `Goal`, `TimeBlock`, `SleepSession`, `RhythmAnnotation`, and `DailyReview` tables and their schema remain unchanged.

## Verification matrix

- Controller: untouched open, same-session recovery prompt, continue, restart, return-to-baseline cleanup, missing context, committed residual, save failure, duplicate-submit prevention.
- Flow: activity/sleep/review new and edit contexts, Gap context, return/close language, synchronization-failure exit choice, and advanced clear.
- Compatibility: three legacy input stores cleared, sleep learning retained, session input absent from persistent stores.
- Platform: Android navigation/background versus force-stop restart; Web navigation versus reload/reopen.

