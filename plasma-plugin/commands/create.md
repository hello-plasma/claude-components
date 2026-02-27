---
description: Create a new PLASMA organism (interactive UI app)
argument-hint: "<description of what to build>"
---

Create a new PLASMA organism based on the user's request: "$ARGUMENTS"

## Steps

1. **Classify the request**: Is this interactive (form, app with buttons) or display-only (chart, visualization)?
   - If ambiguous, ask: "Do you want this to be interactive (you click buttons, I process the data) or just a display?"

2. **Design the UI**: Create HTML/CSS/JS for the interface. Follow the dark theme (bg #0f0f0f, text #e5e5e5).

3. **Define activities**: For interactive apps:
   - Add `dataProvider` to every button that needs to collect user data
   - The dataProvider must gather all relevant form values as a JS object expression
   - Use `type: button` for clickable actions, `type: input` for fields where change events matter

4. **Create the organism**: Call `plasma_create` with name (snake_case, max 4 words), description, html, css, js, activities.

5. **Start the interaction loop** (interactive apps only):
   - Tell the user the UI is ready
   - Call `wait_for_ui_event(timeout_seconds: 120)` to wait for interaction
   - Process returned data
   - Update UI with `dynamic_ui_update`
   - Loop back to wait_for_ui_event

6. **Respond naturally**: Don't expose tool internals. Say "The form is ready, go ahead and fill it out" not "I called plasma_create with..."
