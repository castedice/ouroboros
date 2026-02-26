# Interface Contracts Template (Stage 4 — Interface)

Depth markers: `[Light+]` = Light, Standard, Deep. `[Standard+]` = Standard, Deep. `[Deep]` = Deep only.

---

## Header <!-- [Light+] -->

```markdown
# Interface Contracts: {title}

**Stage**: 4 — Interface (SDD)
**Depth**: {Light | Standard | Deep}
**Task**: {task description}
**Upstream**: {path to Architecture Spec}, {path to Constraint Profile}
**Date**: {YYYY-MM-DD}
```

---

## Delta from Design <!-- [Light+] -->

Record every type, signature, or decision that changed from Stage 3 (Architecture Spec). If nothing changed, state "No changes from Architecture Spec." This section prevents silent inconsistencies between stages.

```markdown
| Item | Stage 3 (Design) | Stage 4 (Interface) | Reason for Change |
|------|-------------------|---------------------|-------------------|
| {type or field name} | {original definition} | {new definition} | {why it changed} |
```

If no changes: `No deltas — all types and signatures match Architecture Spec.`

---

## Type Definitions <!-- [Light+] -->

At Light depth: signatures with docstrings only. At Standard+: full type definitions with invariants in comments.

Group by category: Value Objects, Entities, Transient types, Configuration types.

```markdown
### Value Objects

{code block — each type with:
  - derive/attribute annotations
  - doc comment stating invariant
  - constructor that enforces invariant
  - accessor methods
}

### Entities

{code block}

### Search/Query Types

{code block}

### Configuration Types

{code block}
```

Naming rule: use named structs, not tuples. Every public return type must be a named type.

---

## Error Contract <!-- [Standard+] -->

Unified error enum with caller vs system classification.

```markdown
### Error Enum

{code block — error enum with:
  - #[error("...")] messages
  - Caller errors grouped first
  - System errors grouped second
  - type alias for Result
}

### Error Recovery

| Variant | Category | Recovery |
|---------|----------|----------|
| {variant name} | Caller / System | {what the consumer should do} |
```

---

## Core Trait/Interface Definitions <!-- [Standard+] -->

One subsection per trait. Each trait includes: signature, doc comments with performance contracts, invariants as prose, pre/post conditions.

```markdown
### {Trait Name}

{code block — full trait definition with:
  - doc comments referencing constraint IDs for performance contracts
  - method signatures with descriptive parameter names
  - default implementations where applicable
}

**Invariants**:
- {invariant 1}
- {invariant 2}

**Pre/Post Conditions**:
| Method | Pre | Post |
|--------|-----|------|
| {method} | {what must be true before call} | {what is guaranteed after call} |
```

---

## Public API <!-- [Standard+] -->

The primary entry point struct/class that consumers use. This is the facade that composes traits.

```markdown
{code block — public API struct with:
  - constructor
  - each public method with doc comments
  - performance contracts in doc comments
}

**Concurrency**: {which methods are safe for concurrent access, which require exclusive access}
```

---

## Concurrency Model <!-- [Standard+] -->

Explicit thread safety and access pattern documentation.

```markdown
| Operation | Access | Safe to Parallelize | Notes |
|-----------|--------|-------------------|-------|
| {operation} | {shared/exclusive} | {Yes/No} | {e.g., "multiple searches OK, indexing serialized"} |
```

Ownership rules: {which component owns mutable state, how state transitions are synchronized.}

---

## Invariants Summary <!-- [Standard+] -->

All invariants from all types and traits in one reference table.

```markdown
| Scope | Invariant |
|-------|-----------|
| {type or trait name} | {condition that must always hold} |
```

---

## Usage Examples <!-- [Standard+] -->

Minimum: 1 happy path + 1 error path. At Deep depth: add edge cases.

```markdown
### Happy Path: {scenario}

{code block — complete usage from construction through result}

### Error Path: {scenario}

{code block or bullet list — what triggers each error, expected behavior}
```

---

## Test Suggestions <!-- [Standard+] -->

Seed test cases for Stage 5 (Test). Each suggestion must include enough implementation detail for the test writer to produce accurate tests without guessing. This section bridges the gap between interface specification and test authoring — ambiguity here causes test-contract mismatches that must be fixed during implementation.

```markdown
| # | Test Name | Target | Module Path | Scenario | Key Assertion |
|---|-----------|--------|-------------|----------|---------------|
| 1 | {test_name following test_<behavior>_when_<condition>_should_<expected>} | {function or class} | {source file path where the target is exported — tests mock this path} | {happy/error/edge} | {what to assert} |
```

### Implementation Detail Requirements

For each type/class with a constructor or factory:

```markdown
| Type | Constructor Signature | Parameter Order | Notes |
|------|----------------------|-----------------|-------|
| {ClassName} | `new ClassName(param1: Type1, param2: Type2, param3: Type3)` | {describe each param's role} | {any defaults, optional params} |
```

For functions that accept object/struct parameters vs positional arguments:

```markdown
| Function | Parameter Style | Signature |
|----------|----------------|-----------|
| {functionName} | Object destructuring / Positional | `functionName(input: InputType): OutputType` or `functionName(a: A, b: B): OutputType` |
```

These tables prevent the most common test-contract mismatches: constructor arity (tests passing wrong number of arguments), mock path errors (tests mocking the wrong module), and parameter style confusion (tests passing separate arguments when the function expects an object).

---

## CLI/Command Interface <!-- [Standard+] -->

Include only if the system has a CLI. Define using the target language's CLI framework idiom.

```markdown
{code block — CLI struct/enum definition with:
  - subcommands
  - arguments with defaults
  - output format options
}

**Exit codes**: {0=success, 1=caller error, 2=system error, etc.}
```

---

## Contract Tests <!-- [Deep] -->

Pseudo-code test cases derived from invariants. These are seeds for Stage 5 (Test).

```markdown
### {Invariant being tested}

{pseudo-code:
  given: {setup}
  when: {action}
  then: {assertion referencing invariant}
}
```

---

## Compatibility Matrix <!-- [Deep] -->

Version compatibility and migration paths. Include only if the system has versioned data or external consumers.

```markdown
| Version | Compatible With | Migration Path | Breaking Changes |
|---------|----------------|---------------|-----------------|
| {version} | {compatible versions} | {how to migrate} | {what breaks} |
```

---

## Artifact Summary <!-- [Light+] -->

```markdown
| Category | Count |
|----------|-------|
| Type definitions | {n} |
| Trait/Interface definitions | {n} |
| Public API methods | {n} |
| Error variants | {n} (caller: {n}, system: {n}) |
| Invariants | {n} |
| Usage examples | {n} |
| Deltas from Design | {n} |
```

---

## Exit Criteria Checklist <!-- [Light+] -->

```markdown
- [ ] All types have explicit definitions — no `any` or untyped structures
- [ ] All public return types are named structs (no raw tuples)
- [ ] Delta from Design section complete (even if "no changes")
- [ ] {At Standard+} Error contract covers caller vs system with recovery
- [ ] {At Standard+} Every trait has invariants and pre/post conditions
- [ ] {At Standard+} Concurrency model explicitly documented
- [ ] {At Standard+} Usage examples cover happy + error paths
- [ ] {At Deep} Contract tests cover all invariants
```
