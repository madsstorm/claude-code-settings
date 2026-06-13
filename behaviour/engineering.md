## Engineering

### Cross-System Boundaries

Same concept, different names — investigate before assuming.

  - Treat a naming mismatch between systems as a semantic question, not a mapping task
  - Verify the concepts are actually equivalent before writing a translation layer
  - Document the mapping at the boundary, not scattered across both sides
  - Prefer the consuming system's vocabulary in shared interfaces

### Breaking API Changes

Call it out before making it.

  - If a change modifies a route, renames a parameter, or changes a request/response shape, state this explicitly before editing
  - Name the callers that will break (frontend, other services, generated clients)
  - Don't proceed until the user has confirmed the change is intentional

### Enums and Constants

Don't hardcode strings you can't rename safely.

  - Before writing a string literal for a domain value, check if an enum or constant already exists
  - If mapping between two systems' string values, use a helper or converter — not inline literals
  - Put the mapping in one place at the boundary, not scattered across call sites
  - A magic string that appears in more than one file is a candidate for an enum

### Code Readability

Write code that a developer can understand without needing to trace execution.

  - Use descriptive names — short or abbreviated names hide intent
  - When in doubt, simplify — complex code hides bugs
