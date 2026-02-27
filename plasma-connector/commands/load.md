---
name: plasma:load
description: Load and render a saved PLASMA organism
---

Load the PLASMA organism named "$ARGUMENTS" and render it on the Plasma Surface.

Steps:
1. If no name provided, call `plasma_list` first and ask the user which organism to load
2. Call `plasma_load` with the organism name
3. Respond naturally confirming the organism is now displayed
