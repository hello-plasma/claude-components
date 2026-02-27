---
name: plasma:create
description: Create a new PLASMA organism (UI app)
---

Create a new PLASMA organism with the name "$ARGUMENTS" (or ask the user for a name if none provided).

Steps:
1. Ask the user what kind of UI they want if not clear from context
2. Design the HTML/CSS/JS for the interface
3. Define activities for interactive elements
4. Call `plasma_create` with the generated code
5. Respond naturally confirming the organism was created and rendered
