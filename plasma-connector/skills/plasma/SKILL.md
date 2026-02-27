---
name: plasma
description: Event-sourced dynamic UI system for AI-generated interactive interfaces with HTML/CSS/JS
user-invocable: true
command-dispatch: true
---

# PLASMA — Dynamic UI System for Claude

**Plasma** allows you to generate and control fully custom HTML/CSS/JS interfaces rendered on the user's desktop via the Plasma Surface app.

Unlike template-based UI systems, Plasma gives you complete freedom to create any interface using standard web technologies, external libraries (Three.js, D3.js, Chart.js), and your own custom code.

---

## Agent Usage Guidelines

**IMPORTANT**: You (the agent) call these tools based on the user's natural language requests. The user NEVER types tool calls directly.

### When to Use Which Tool

| User Says | You Do |
|-----------|--------|
| "Create a form for customers" | Call `plasma_create` with appropriate HTML/CSS/JS |
| "Build a dashboard" | Call `plasma_create` with dashboard layout |
| "Make a calculator app" | Call `plasma_create` with calculator UI |
| "Add validation to the form" | Call `plasma_mutate` with validation JS |
| "Change the button color to blue" | Call `plasma_mutate` with color change JS |
| "Fix the layout" | Call `plasma_mutate` with layout fix JS |
| "Show me the customer form" | Call `plasma_load` with organism name |
| "Open the dashboard" | Call `plasma_load` with organism name |
| "What apps do I have?" | Call `plasma_list` |
| "Delete the old form" | Call `plasma_delete` with organism name |
| "What's in the form right now?" | Call `dynamic_ui_query` with JS to read values |

### Naming Organisms

When creating organisms, generate descriptive names following BASIC convention:
- **Format**: a-zA-Z0-9_ only, max 4 words
- **Style**: snake_case preferred
- **Descriptive**: Name reflects content

**Good names**: `customer_form`, `sales_dashboard`, `task_manager`, `chat_ui`
**Bad names**: `form1`, `app`, `my-form`, `very_long_descriptive_name_here`

### Response Style

After calling tools, respond in natural language:

Bad: "I called plasma_create with parameters {name: 'customer_form', ...}"
Good: "I've created a customer entry form with name and email fields. It's ready on your Plasma Surface!"

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
  button { background: #e91e8c; color: white; padding: 10px 20px; }
  input { width: 100%; padding: 8px; margin: 4px 0; }

js: |
  window.app = {
    resetForm: function() {
      document.getElementById('name-input').value = '';
      document.getElementById('email-input').value = '';
    }
  };
```

---

## Activities & Feedback Loop

Activities bridge the UI and you (the agent). They let you receive user interactions.

### Activity Types

| Type | Auto-Wired Event | What Gets Sent |
|------|------------------|----------------|
| `button` | `click` (preventDefault) | activityId, type, context, provided |
| `input` | `change` | activityId, type, value, context, provided |
| `canvas` | None (manual) | Whatever you send via `window.sendAction()` |
| `custom` | None (manual) | Whatever you send via `window.sendAction()` |

### The `dataProvider` Field

Use `dataProvider` to attach a JS expression evaluated at event time:

```yaml
activities:
  - id: btn-submit
    type: button
    context: {action: submit_form}
    dataProvider: "({name: document.getElementById('name').value, email: document.getElementById('email').value})"
```

### window.sendAction(activityId, type, data)

For `canvas` and `custom` types, call `window.sendAction()` from your JS:

```javascript
window.sendAction("btn-submit", "submit", {
  name: document.getElementById("name").value,
  email: document.getElementById("email").value
});
```

---

## Available Tools

### 1. `plasma_create`
Create a new organism. Parameters: name, description, html, css, js, activities, tags.

### 2. `plasma_mutate`
Apply incremental mutation. Parameters: name, mutation_name, js.

### 3. `plasma_load`
Load and render a saved organism. Parameters: name.

### 4. `plasma_list`
List all organisms. No parameters.

### 5. `plasma_delete`
Delete an organism. Parameters: name.

### 6. `dynamic_ui_render`
Ad-hoc render (no persistence). Parameters: html, css, js, activities.

### 7. `dynamic_ui_update`
Incremental JS update. Parameters: js.

### 8. `dynamic_ui_query`
Execute JS and return result. Parameters: js.

---

## Design Patterns

### Expose State for Updates
```javascript
// In initial render (plasma_create or dynamic_ui_render):
window.app = { scene, camera, records: [], count: 0 };

// In mutations (plasma_mutate or dynamic_ui_update):
window.app.count++;
document.getElementById('counter').textContent = window.app.count;
```

### Form with Data Collection
```javascript
// Use custom type + sendAction for forms:
document.getElementById('btn-submit').addEventListener('click', function(e) {
  e.preventDefault();
  window.sendAction('btn-submit', 'submit', {
    name: document.getElementById('name').value,
    email: document.getElementById('email').value
  });
});
```

### External Libraries
Load via CDN script tags in your JS:
```javascript
var script = document.createElement('script');
script.src = 'https://cdnjs.cloudflare.com/ajax/libs/three.js/r128/three.min.js';
script.onload = function() { /* initialize Three.js */ };
document.head.appendChild(script);
```
