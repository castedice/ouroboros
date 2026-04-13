# Hook Static Evaluation Criteria

> Reference for the evaluation skill. 13 binary criteria (0 or 1) across 3 tiers.
> Tier 1 Foundation gates Tier 2/3: Foundation < 5 caps at Level 2.

## Tier 1: Foundation (5)

### F1: Event/Matcher Match

Does the hook use the correct event and matcher?

- **1**: Event type (PreToolUse, PostToolUse, SessionStart, Stop, etc.) matches the hook's purpose. Matcher targets only relevant tools (no wildcard `*`)
- **0**: Event type mismatches actual purpose, matcher uses `*` catching all tools, or matcher unspecified

### F2: Timeout Configuration

Is the timeout appropriately set?

- **1**: Timeout specified. Simple validation: 10-30s, security checks: 30-60s, formatting: under 30s. Proportional to task complexity
- **0**: Timeout unspecified (risk of infinite wait), or excessive values like 120s+ for simple tasks

### F3: Error Handling

Does the hook behave safely on failure?

- **1**: `exit 0` on JSON parse failure (allows tool to proceed). Defensive code exists to prevent Claude session interruption on script errors
- **0**: No error handling (risk of Claude session interruption on parse failure), or treats all errors as blocks

### F4: Portability

Is the hook portable without environment dependencies?

- **1**: Uses the plugin-root variable for hook script paths. Minimal external dependencies. No OS-specific commands, or conditional branching for different OS
- **0**: Hardcoded absolute paths, commands that work only on specific OS, assumes uninstalled tools

### F5: Necessity

Does the hook perform work that must be a hook?

- **1**: Tasks suited for unattended auto-execution: auto-formatting, security verification, session initialization. No user interaction needed
- **0**: Complex business logic (→ agent/skill is more appropriate), tasks requiring user input, or tasks achievable with existing tools

## Tier 2: Craft (5)

### Q1: Description Documentation

Does the hooks.json entry include clear documentation?

- **1**: `description` field present in hooks.json with specific purpose statement. The hook's role is understandable from hooks.json alone without reading the script
- **0**: No description field, or description too vague to understand the hook's purpose

### Q2: Exit Code Semantics

Does the script use meaningful exit codes following Claude Code conventions?

- **1**: Exit codes documented in script header or comments. PreToolUse hooks use exit 2 for blocking (not exit 1). Distinct codes for different failure modes (e.g., 0=pass, 1=error, 2=block)
- **0**: Only exit 0 used. No documentation of exit code meaning. Or incorrect blocking exit code for PreToolUse

### Q3: Input Parsing Safety

Does the script safely parse tool input from Claude Code?

- **1**: Uses `jq` with null-safe extraction (e.g., `// empty`). Handles missing fields gracefully. Empty/null input triggers early exit, not script error
- **0**: Assumes input structure without null checks. Missing field causes unhandled error

### Q4: Dependency Guards

Does the script gracefully handle missing external tools?

- **1**: Uses `command -v` or equivalent to check tool availability before invocation. Missing tools trigger skip with informational message (not error). No assumption about installed tools beyond POSIX baseline
- **0**: Calls external tools without checking availability. Missing tool causes script failure or silent malfunction

### Q5: Performance Awareness

Is the script designed to minimize execution time within timeout budget?

- **1**: Avoids slow operations (network calls, heavy compilation, package manager invocations) or documents their expected duration relative to timeout. Uses fast alternatives where possible (string operations over subprocess spawning)
- **0**: Contains potentially slow operations without considering timeout budget. No performance consideration documented

## Tier 3: Excellence (3)

### E1: Script Header Documentation

Does the script include comprehensive header documentation?

- **1**: Header documents purpose, usage context (which hook entry triggers it), exit code semantics, and side effects. Reading the header alone provides complete understanding of the script's behavior
- **0**: No header, or header only contains filename. Purpose/behavior must be inferred from code

### E2: Idempotency Guarantee

Is the hook safe to run multiple times on the same input?

- **1**: Script produces identical results on repeated execution. No cumulative side effects (no appending, no counter increments). Designed for re-execution safety
- **0**: Repeated execution could cause different results, append duplicate content, or accumulate side effects

### E3: Security Boundary Documentation

Does the hook document its security implications?

- **1**: For security-related hooks: threat model documented (what attacks it prevents and what it does NOT cover). For non-security hooks: explicitly states it has no security role. Coverage gaps acknowledged
- **0**: Security implications neither claimed nor disclaimed. Or claims security protection without documenting coverage gaps

## Severity Gate Thresholds

| F (0-5) | Q (0-5) | E (0-3) | Level |
|---|---|---|---|
| ≤ 3 | — | — | **1 — Poor** |
| 4 | — | — | **2 — Needs Work** (cap) |
| 5 | ≤ 2 | — | **2 — Needs Work** |
| 5 | 3 | — | **3 — Good** |
| 5 | ≥ 4 | ≤ 1 | **3 — Good** |
| 5 | ≥ 4 | ≥ 2 | **4 — Excellent** |
