# Play Store Pre-Release Checklist

Use this file as the strict implementation order for pre-publication work. Do not start the next item until the current one is complete, tested, and the progress tracker has been updated.

## How To Work

1. Pick exactly one item from the checklist.
2. Make the smallest safe change that completes only that item.
3. Run the targeted tests for that item first.
4. If targeted tests pass, run the broader related test group.
5. Update [AUDIT_TRACKER.md](AUDIT_TRACKER.md) immediately after the item is complete.
6. Record the exact files changed, the tests run, and any remaining risk.
7. Move to the next item only after the tracker has been updated.

## Critical Blockers

### 1. Keep login flow clean and deterministic
1. LoginScreen back button must never route to MainScreen.
2. SplashScreen remains the only startup decision point.
3. Auto-login should reopen the app directly to MainScreen only when the saved session is valid.
4. If auto-login fails because the router changed, Wi-Fi changed, the device is on mobile data, or credentials are stale, the app must fall back to LoginScreen.
5. LoginScreen must remain the manual recovery path only.
6. Gateway IP autofill is allowed only as a helper for manual sign-in.
7. No back-button bypass or hidden shortcut into MainScreen is allowed.

Pass condition:
- Reopen with a valid saved session goes straight to MainScreen.
- Reopen after network or credential failure goes to LoginScreen.
- Back from LoginScreen never enters MainScreen.

### 2. Keep reviewer mode exit strict
1. Exiting reviewer mode must only disable reviewer mode and route to LoginScreen.
2. Do not re-select the live router in the background on exit.
3. Do not auto-login after leaving reviewer mode.
4. Do not reintroduce double logout or double reconfiguration.
5. Keep reviewer mode cleanup isolated in the session controller.

Pass condition:
- Exit reviewer mode leaves the app cleanly on LoginScreen.
- No hidden router reconnect occurs during reviewer exit.

### 3. Keep splash startup minimal
1. SplashScreen should only read the minimum signals needed for first routing.
2. Reviewer mode check stays.
3. Saved credential check stays.
4. Auto-login attempt stays.
5. Do not add gateway detection, extra delays, dashboard fetch, or extra refresh work back into splash.
6. Keep the splash transition short and one-way.

Pass condition:
- Splash makes one routing decision and stops.
- No extra startup work is performed before the first destination is chosen.

## Architecture Simplification

### 4. Avoid duplicated ownership
1. ParentalControlsController remains the owner for parental control storage sync, router sync, schedule checks, and lifecycle handling.
2. ParentalControlsStore remains state only.
3. ParentalControlsScreen remains presentational and event-driven.
4. Keep UI code from mutating store state directly when a controller path exists.
5. Keep AppState thin and delegating where possible.

Pass condition:
- UI does not own parental control business logic.
- The controller is the only orchestration layer for parental features.

### 5. Remove any remaining direct store mutation from UI
1. If the screen directly clears log entries, move that into the controller.
2. If the screen directly persists local state, move that into the controller.
3. If the screen directly decides sync order, move that into the controller.
4. Keep all parental control mutations behind one controller entry point.

Pass condition:
- The screen only emits actions and renders results.

### 6. Keep state results typed and explicit
1. Use ParentalActionResult for parental actions.
2. Use specific failure types for firewall denied, router unreachable, self-guard blocked, partial success, and storage error.
3. Do not collapse all failures into a generic error.
4. Partial failures must list the exact MAC addresses that failed.

Pass condition:
- The UI can show precise failure feedback.
- The controller communicates success and failure clearly.

## Edge Case Handling

### 7. Handle no-router and bad-network cases cleanly
1. Reopening on a different Wi-Fi network must fail auto-login if the router is not reachable.
2. Reopening on mobile data must fail auto-login and fall back to LoginScreen.
3. If saved credentials exist but the router is unreachable, the app must not hang on MainScreen.
4. If saved credentials are missing or invalid, the app must still route to LoginScreen.
5. If the app cannot validate the session, it must fail closed, not guess.

Pass condition:
- Network changes never leave the app in a broken authenticated shell.

### 8. Keep self-protection intact
1. SelfDeviceGuard must continue to block destructive actions against the active management device.
2. Check all MAC addresses in a parental profile before applying a destructive change.
3. Do not let partial target checking slip back in.
4. Keep guard behavior independent of UI timing and route timing.

Pass condition:
- The management device cannot accidentally cut itself off.

### 9. Preserve pause and schedule correctness
1. Pause expiry must resume exactly once.
2. Schedule windows must enforce and release access deterministically.
3. Resume checks must be idempotent.
4. Lifecycle changes must not duplicate timer work.
5. Timer-driven and resume-driven checks must not fight each other.

Pass condition:
- Parent or device restrictions transition cleanly without repeated toggles.

## UI and UX Polishing

### 10. Keep the app visually calm on startup
1. Splash to login transition should remain smooth and short.
2. Do not add extra frame jumps or redundant visual handoffs.
3. Preserve the existing fade/scale polish if it remains smooth.
4. Avoid adding more startup animations that delay access to the login form.

Pass condition:
- The app opens without visible churn or jitter.

### 11. Keep the login screen clear and useful
1. LoginScreen should continue to support gateway autofill for manual recovery.
2. Keep password visibility toggle, autofill, and helpful hints.
3. Keep error messages visible and actionable.
4. Do not make the login screen feel like a hidden router manager.
5. Keep the back button behavior simple and safe.

Pass condition:
- The user can recover from bad sessions quickly.
- The login screen stays a focused recovery page.

### 12. Keep parental control UI responsive
1. The parental controls screen should not block the UI while loading if it can render a useful skeleton or loading state.
2. Dialogs should remain scroll-safe on smaller screens.
3. Long profile names, MAC lists, and activity log entries must not overflow.
4. Toasts should communicate only one result at a time.

Pass condition:
- The feature remains readable and usable on smaller devices.

## Release Hardening

### 13. Keep release-critical tests passing
1. Run the targeted auth tests after login or startup changes.
2. Run the targeted parental controls tests after parental changes.
3. Run the full flutter test suite before release sign-off.
4. If any test fails, fix only that area before continuing.

Pass condition:
- Targeted tests pass for the touched area.
- Full suite passes before release.

### 14. Keep tracker updates mandatory
1. After each completed task, update [AUDIT_TRACKER.md](AUDIT_TRACKER.md).
2. Record what changed, why it changed, and what was verified.
3. Record the tests run and their result.
4. Record any remaining optional polish, if any.
5. Do not wait until the end of the whole refactor to update the tracker.

Pass condition:
- The tracker always reflects the current state of work.

## Suggested Execution Order

1. Lock login back-button behavior and reopen auto-login behavior.
2. Confirm splash startup remains minimal and correct.
3. Verify reviewer-mode exit remains strict and non-bypass.
4. Clean up any remaining parental-control ownership leaks.
5. Tighten edge-case handling for network changes and partial failures.
6. Polish UI and animation smoothness.
7. Run the full test suite and update the tracker.

## Final Release Criteria

1. No back-button bypass to MainScreen.
2. Reopen on valid saved session goes directly to MainScreen.
3. Reopen after router or network failure goes to LoginScreen.
4. Parental controls are controller-owned and deterministic.
5. Partial failures are reported clearly.
6. Self-guardrails remain intact.
7. Startup is minimal and smooth.
8. The full test suite passes.
9. The progress tracker is current and complete.
