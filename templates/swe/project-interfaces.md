# Project Interfaces

> Living document. Updated after each spiral turn.
> Last updated: {date} (Turn {NNN}: {slug})

## Summary

{3-5 sentences: current interface landscape — key module boundaries, public APIs, and type system overview.}

## Module Contracts

### {Module Name}

**Responsibility**: {what this module owns}

#### Public API

```
{function/method signatures with types}
```

#### Types

```
{type definitions used in the public API}
```

#### Invariants

- {invariant 1: condition that must always hold}
- {invariant 2}

#### Error Conditions

| Error | Trigger | Consumer Action |
|-------|---------|----------------|
| {error type} | {when it occurs} | {what caller should do} |

## Cross-Module Dependencies

| Consumer | Provider | Interface | Introduced |
|----------|----------|-----------|------------|
| {module A} | {module B} | {which API/type} | Turn {NNN} |

## Change Log

| Turn | Feature | Changes |
|------|---------|---------|
| {NNN} | {slug} | {what was added/modified} |
