## Workflow

### Persist Plans

Write it down before you build it.

  - For any non-trivial task, create a plan file before coding
  - Record: chosen approach, key files to change, tests
  - Update the plan if the approach changes mid-execution — don't let it go stale
  - Save only the decision direction to memory, not plan content

### Name Plan Artifacts, Don't Number Them

Anything referenced across sections needs a name that reads cold.

  - Name decisions, questions, slices and stages for what they do — never `Q6`, `A2`, `J1`, `S3`
  - The test: a sentence citing it reads weeks later without scrolling to a definition
  - Never let a label imply an order the work doesn't have — `Stage 1b` before `Stage 1` is a trap
  - When renaming, map old→new in one place and mark the old labels retired

### Complexity Estimates

Express complexity in terms relevant to the type of work being estimated.

  - For tasks performed by automated execution: estimate in terms of design clarity, error risk, and number of moving parts.
  - For runtime performance: use concrete time estimates — seconds, minutes.

### Evaluate Alternative Approaches

Consider alternatives before committing to an implementation strategy.

  - Before settling on an approach, identify at least one meaningful alternative and compare tradeoffs explicitly
  - Look for existing infrastructure in the codebase that could serve the same goal — a solution that reuses what's already there deserves serious consideration
  - Present the comparison to the user when the choice materially affects accuracy, maintainability, or correctness

### Unit Tests

Before implementing, identify tests to write or expand.

  - Search for existing tests covering the files you plan to change
  - Note gaps: missing tests, untested edge cases, new operations with no coverage
  - Enumerate tests per product/feature in scope — a shared implementation path does not mean shared coverage
  - Include a Tests section in the plan: what to expand, what to create, where they live

### Resolve Open Questions

Don't offer to execute until the plan is unambiguous.

  - Before presenting a plan for approval, identify any open questions in it
  - Ask the user to resolve them one by one
  - Only present the plan for approval once all open questions are answered or explicitly deferred

### Keep the Plan Consistent

Propagate every decision through the entire plan as it is made — not just the section being discussed.

  - When any detail changes, update all sections that reference it
  - When scope is reduced, remove the item everywhere it appears
  - Before presenting the plan, do a full read-through to catch contradictions between sections
