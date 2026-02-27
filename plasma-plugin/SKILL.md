---
name: plasma
description: Event-sourced dynamic UI system for AI-generated interactive interfaces with HTML/CSS/JS
user-invocable: true
---

# PLASMA — Event-Sourced Dynamic UI System

**Plasma** allows you to generate and control fully custom HTML/CSS/JS interfaces rendered on the user's desktop via the Plasma Surface app.

Unlike template-based UI systems, Plasma gives you complete freedom to create any interface using standard web technologies, external libraries (Three.js, D3.js, Chart.js), and your own custom code.

---

## CRITICAL: Interactive vs Display-Only

**Before building any PLASMA UI, you MUST determine whether the user wants an interactive application or a display-only visualization.** This distinction fundamentally changes how you build the UI.

### Decision Rule

| User Request | Classification | What You Do |
|-------------|---------------|-------------|
| "Create a form for customers" | **Interactive** | Add dataProviders + use wait_for_ui_event loop |
| "Build an app to manage tasks" | **Interactive** | Add dataProviders + use wait_for_ui_event loop |
| "Make a calculator" | **Interactive** | Add dataProviders + use wait_for_ui_event loop |
| "Show me a chart of sales data" | **Display-only** | Render without activities, no wait loop |
| "Display a 3D cube" | **Display-only** | Render without wait loop |
| "Build something for X" | **Ambiguous** | ASK the user to clarify |

**When ambiguous**, ask:
> "Do you want this to be interactive (you can click buttons and I'll process the data) or just a visualization to display?"

### Interactive Application Pattern (MANDATORY)

When the user requests an interactive application, you MUST follow this exact pattern:

1. **Add `dataProvider` to every button that collects data.** The dataProvider is a JS expression evaluated at click time that gathers form values, app state, or computed data. Without it, you only receive the static context — not the actual user input.

2. **Render the UI** with `plasma_create` or `dynamic_ui_render`.

3. **Immediately call `wait_for_ui_event`** to block and wait for user interaction.

4. **Process the returned data** (validate, compute, call APIs, etc.).

5. **Update the UI** with the result via `dynamic_ui_update` or `plasma_mutate`.

6. **Loop back to step 3** — call `wait_for_ui_event` again for the next interaction.

**Example — Interactive form:**
```
1. plasma_create with dataProvider on submit button
2. wait_for_ui_event(timeout_seconds: 120)
   → user fills form, clicks Submit
   → returns: {activityId: "btn-submit", type: "click", data: {provided: {name: "Lorenzo", email: "..."}}}
3. Process data, call APIs, etc.
4. dynamic_ui_update → show confirmation in the UI
5. wait_for_ui_event(timeout_seconds: 120) → wait for next interaction
```

**NEVER render an interactive UI and then just say "it's ready" without calling wait_for_ui_event. The user expects you to react to their clicks.**

---

## Agent Usage Guidelines

**IMPORTANT**: You (the agent) call these tools based on the user's natural language requests. The user NEVER types tool calls directly.

### When to Use Which Tool

| User Says | You Do |
|-----------|--------|
| "Create a form for customers" | `plasma_create` + `wait_for_ui_event` loop |
| "Build a dashboard" | `plasma_create` (interactive if has buttons, display if not) |
| "Make a calculator app" | `plasma_create` + `wait_for_ui_event` loop |
| "Add validation to the form" | `plasma_mutate` (+ `wait_for_ui_event` if interactive) |
| "Change the button color to blue" | `plasma_mutate` |
| "Show me the customer form" | `plasma_load` + `wait_for_ui_event` loop |
| "Open the dashboard" | `plasma_load` |
| "What apps do I have?" | `plasma_list` |
| "Delete the old form" | `plasma_delete` |
| "What's in the form right now?" | `dynamic_ui_query` |
| "Take a screenshot" | `plasma_screenshot` |
| "Show a quick visualization" | `dynamic_ui_render` (no persistence) |

### Discovery Flow

When the user asks to load/open an app but you're not sure which one:

1. Call `plasma_list` to see available organisms
2. Check folder names (BASIC convention: descriptive, a-zA-Z0-9_)
3. If uncertain, ask user to clarify
4. Call `plasma_load` with selected organism
5. If the organism is interactive, start the `wait_for_ui_event` loop

### Naming Organisms

When creating organisms, generate descriptive names following BASIC convention:
- **Format**: a-zA-Z0-9_ only, max 4 words
- **Style**: snake_case preferred
- **Descriptive**: Name reflects content

**Good names**: `customer_form`, `sales_dashboard`, `task_manager`, `chat_ui`
**Bad names**: `form1`, `app`, `my-form`, `very_long_descriptive_name_here`

### Response Style

After calling tools, respond to the user in natural language:

Bad: "I called plasma_create with parameters {name: 'customer_form', ...}"
Good: "I've created a customer entry form. Go ahead and fill in the fields — I'm watching for your submission."

Bad: "Tool returned: Organism 'customer_form' created successfully..."
Good: "The form is live on your Plasma Surface. Fill it out and click Submit — I'll process your data."

---

## Core Concept: Event Sourcing

**Create once, mutate incrementally, replay from history.**

- **main.code**: Initial app version (YAML structured: HTML/CSS/JS/activities)
- **Mutations**: Incremental JavaScript updates (1_add_validation.code, 2_change_color.code, ...)
- **Snapshots**: Automatic mechanical snapshots every 20 mutations for fast loading
- **No reloads**: Maintain animations, timers, Three.js scenes, canvas state during mutations

---

## Organism Architecture

### File Structure
```
~/.plasma/organisms/customer_form/
├── manifest.yaml
├── main.code
├── 1_add_validation.code
├── 2_change_theme.code
├── ...
├── snapshot_20.code
├── 20_add_button.code
└── state.json (optional)
```

### main.code (YAML structured)
```yaml
---
activities:
  - id: btn-submit
    type: button
    context: {action: submit_customer}
    dataProvider: "({name: document.getElementById('name-input').value, email: document.getElementById('email-input').value})"
  - id: name-input
    type: input
    context: {field: name}
---
html: |
  <div class="form">
    <input id="name-input" placeholder="Name">
    <input id="email-input" placeholder="Email">
    <button id="btn-submit">Submit</button>
    <div id="result"></div>
  </div>

css: |
  .form { padding: 20px; max-width: 400px; }
  button { background: #e91e8c; color: white; padding: 10px 20px; border: none; border-radius: 4px; cursor: pointer; }
  input { width: 100%; padding: 8px; margin: 4px 0; background: #1a1a1a; border: 1px solid #333; color: #e5e5e5; border-radius: 4px; }

js: |
  window.app = {
    resetForm: function() {
      document.getElementById('name-input').value = '';
      document.getElementById('email-input').value = '';
    }
  };
```

### Mutation Files (JavaScript only)
```javascript
// 1_add_validation.code
window.app.validate = function() {
  const name = document.getElementById('name-input').value;
  if (!name) {
    alert('Name is required');
    return false;
  }
  return true;
};
```

---

## Activities & Feedback Loop

Activities bridge the UI and you (the agent). They let you receive user interactions and respond.

### Activity Types

| Type | Auto-Wired Event | What Gets Sent |
|------|------------------|----------------|
| `button` | `click` (with preventDefault) | activityId, type, context, provided |
| `input` | `change` | activityId, type, value, context, provided |
| `canvas` | None (manual) | Whatever you send via `window.sendAction()` |
| `custom` | None (manual) | Whatever you send via `window.sendAction()` |

### The `dataProvider` Field (CRITICAL for Interactive Apps)

Use `dataProvider` to attach a **JS expression** to a `button` or `input` activity. The expression is evaluated **at event time** (when the user clicks/changes), and its result is included as `provided` in the event payload.

**Without dataProvider**, you only receive the static `context` — NOT the user's actual input. This is the #1 mistake when building interactive forms.

```yaml
activities:
  - id: btn-submit
    type: button
    context: {action: submit_form}
    dataProvider: "({name: document.getElementById('name').value, email: document.getElementById('email').value})"
```

When clicked, via `wait_for_ui_event` you receive:
```json
{
  "activityId": "btn-submit",
  "type": "click",
  "data": {"provided": {"name": "Mario", "email": "mario@email.com"}},
  "context": {"action": "submit_form"}
}
```

**Key points**:
- The expression is wrapped in `eval('(' + expr + ')')` — return an object literal by wrapping in parentheses
- Errors in dataProvider are caught and logged; provided will be undefined on failure
- Works on both button and input activity types
- `context` is static metadata (set at creation), `provided` is dynamic data (evaluated at event time)

**Examples**:

```yaml
# Single field value
dataProvider: "document.getElementById('search').value"

# Multiple fields as object
dataProvider: "({name: document.getElementById('name').value, qty: parseInt(document.getElementById('qty').value)})"

# App state
dataProvider: "window.app.getFormData()"

# Computed value
dataProvider: "document.querySelectorAll('.item.selected').length"

# All records from a table
dataProvider: "JSON.parse(JSON.stringify(window.app.records))"
```

### window.sendAction(activityId, type, data)

For `canvas` and `custom` activity types, a global `window.sendAction()` function is available. Call it from your JS to send any action back to the agent:

```javascript
// Send a click with form data
window.sendAction("btn-submit", "submit", {
  name: document.getElementById("name").value,
  email: document.getElementById("email").value
});
```

### Which type to use — decision guide

| Scenario | Activity Type | Why |
|----------|--------------|-----|
| Button that needs form values | `button` + `dataProvider` | Auto-wired with runtime data |
| Simple "notify agent" button | `button` (no dataProvider) | Auto-wired, no data needed |
| Complex event handling (debounce, multi-event) | `custom` + `window.sendAction()` | Full control |
| Button doing client-side-only work | Don't declare as activity | No agent involvement |
| Input whose value matters to agent | `input` | Auto-sends on change |
| Complex interactive element | `custom` + `window.sendAction()` | Full control |

---

## The wait_for_ui_event Flow

This is the core pattern for interactive applications. The tool blocks execution until the user interacts with the UI.

### Basic Flow

```
1. Render UI (plasma_create / dynamic_ui_render)
     ↓
2. wait_for_ui_event(timeout_seconds: 120)
     ↓  ← BLOCKS HERE until user acts
3. Receive event: {activityId, type, data: {provided: {...}}, context}
     ↓
4. Process the data (validate, compute, API calls, etc.)
     ↓
5. dynamic_ui_update → show result in UI
     ↓
6. Go back to step 2
```

### Multi-Button Pattern

When the UI has multiple buttons, check `activityId` to determine which was clicked:

```
wait_for_ui_event(120) →
  if activityId === "btn-save"    → save logic
  if activityId === "btn-delete"  → delete logic
  if activityId === "btn-export"  → export logic

→ update UI → wait_for_ui_event again
```

### Timeout Handling

If `wait_for_ui_event` times out (no interaction within the specified seconds):
- The tool returns a timeout message (not an error)
- You can inform the user: "I stopped watching for interactions. Let me know when you're ready."
- Or silently call wait_for_ui_event again if you want to keep waiting

### Complete Interactive Example

```
User: "Create a form to add customers"

You:
1. Call plasma_create({
     name: "customer_form",
     description: "Customer entry form",
     html: '<div class="form">
              <input id="name" placeholder="Name">
              <input id="email" placeholder="Email">
              <button id="btn-submit">Submit</button>
              <div id="result"></div>
            </div>',
     css: '...',
     js: 'window.app = {};',
     activities: [{
       id: "btn-submit",
       type: "button",
       context: {action: "submit"},
       dataProvider: "({name: document.getElementById('name').value, email: document.getElementById('email').value})"
     }]
   })

2. Respond: "The form is ready on your Plasma Surface. Fill it out and click Submit."

3. Call wait_for_ui_event({timeout_seconds: 120})
   → Blocks until user clicks Submit

4. Receive: {activityId: "btn-submit", type: "click", data: {provided: {name: "Lorenzo", email: "lorenzo@example.com"}}, context: {action: "submit"}}

5. Process: validate data, save to DB, etc.

6. Call dynamic_ui_update({
     js: "document.getElementById('result').innerHTML = '<div style=\"color: #4ade80;\">Saved: Lorenzo (lorenzo@example.com)</div>'; window.app.resetForm && window.app.resetForm();"
   })

7. Respond: "Customer Lorenzo saved. The form is ready for the next entry."

8. Call wait_for_ui_event({timeout_seconds: 120})
   → Loop continues...
```

---

## Available Tools

### 1. `plasma_create`
Create a new organism (persistent app). Parameters: name, description, html, css, js, activities, tags.

### 2. `plasma_mutate`
Apply incremental JS mutation. Parameters: name, mutation_name, js.

### 3. `plasma_load`
Load and render saved organism. Parameters: name.

### 4. `plasma_list`
List all organisms. No parameters.

### 5. `plasma_delete`
Delete an organism. Parameters: name.

### 6. `plasma_screenshot`
Capture PNG screenshot of the surface. No parameters.

### 7. `dynamic_ui_render`
Ad-hoc render (no persistence). Parameters: html, css, js, activities.

### 8. `dynamic_ui_update`
Incremental JS update without reload. Parameters: js.

### 9. `dynamic_ui_query`
Execute JS in surface and return result. Parameters: js.

### 10. `dynamic_ui_clear`
Clear the surface. No parameters.

### 11. `wait_for_ui_event`
Block until user interaction, return event data. Parameters: timeout_seconds (1-600, default 120).

---

## Design Patterns

### Expose State for Updates
```javascript
// In initial render:
window.app = { records: [], count: 0 };

// In mutations:
window.app.count++;
document.getElementById('counter').textContent = window.app.count;
```

### Form with Data Collection (Recommended Pattern)
```yaml
activities:
  - id: btn-submit
    type: button
    context: {action: submit}
    dataProvider: "({name: document.getElementById('name').value, email: document.getElementById('email').value})"
```
Then use `wait_for_ui_event` to receive the complete form data at click time.

### Multi-Record Table
```javascript
// Client-side: accumulate records
window.app = { records: [] };
window.app.addRecord = function(data) {
  window.app.records.push(data);
  // update table UI...
};

// Button to send all records to agent
// dataProvider: "JSON.parse(JSON.stringify(window.app.records))"
```

### External Libraries
Load via CDN script tags in your JS:
```javascript
var script = document.createElement('script');
script.src = 'https://cdnjs.cloudflare.com/ajax/libs/three.js/r128/three.min.js';
script.onload = function() { /* initialize Three.js */ };
document.head.appendChild(script);
```

### Dark Theme (Default)
The surface uses a dark background (#0f0f0f). Design your UIs accordingly:
- Light text (#e5e5e5) on dark backgrounds
- Accent colors: #e91e8c (pink), #4ade80 (green), #60a5fa (blue)
- Input backgrounds: #1a1a1a with #333 borders
