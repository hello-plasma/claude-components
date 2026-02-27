---
description: Load and render a saved PLASMA organism
argument-hint: "<organism name>"
---

Load the PLASMA organism "$ARGUMENTS" and render it on the Plasma Surface.

## Steps

1. If no name provided, call `plasma_list` and present options to the user.

2. Call `plasma_load` with the organism name.

3. Determine if the organism is interactive (has button/input activities with dataProviders).

4. If interactive, start the `wait_for_ui_event` loop:
   - Tell the user the app is ready
   - Call `wait_for_ui_event(timeout_seconds: 120)`
   - Process events and update UI as needed

5. If display-only, just confirm it's rendered.
