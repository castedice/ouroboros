# Multi-Model Report Template

Base report structure for multi-model evaluation results. Mode-specific sections are appended as specified in `commands/core/evaluate.md` Phase 6.

## Base Template (all modes)

```markdown
## Multi-Model Evaluation: {component name}

**Type**: {type}
**Models**: Claude {model} + Codex {codex_model} [+ Gemini {gemini_model}]
**Mode**: Consensus ({majority|unanimous})
**Agreement Rate**: {n}/{total} ({percentage}%)
**Consensus Score**: {consensus_score}

### Per-Criterion Consensus

| # | Criterion | Claude | Codex | Gemini | Consensus | Agreement |
|---|-----------|--------|-------|--------|-----------|-----------|
| C1 | {name} | {0|1} | {0|1} | {0|1|-} | {0|1} | {unanimous|majority|split} |
| ... | ... | ... | ... | ... | ... | ... |

### Divergence Analysis

{For each non-unanimous criterion:}

#### C{n}: {criterion name} — {agreement level}

**Claude (score: {s})**:
> {Claude's reasoning excerpt}

**Codex (score: {s})**:
> {Codex's reasoning excerpt}

{If Gemini available:}
**Gemini (score: {s})**:
> {Gemini's reasoning excerpt}

**Resolution**: {majority rule|unanimous after {n} rounds|user decision} → score {0|1}
{If bias detected: "⚠ Potential self-enhancement bias — Claude scored higher than all external models"}

### Strengths (Consensus)

- {merged positive points from all models}

### Improvements (Consensus)

- **[HIGH]** {from any model}
- **[MED]** {from any model}
- **[LOW]** {from any model}

### Context Verification

| Model | Skills/Instructions Applied |
|-------|---------------------------|
| Claude | evaluator agent, evaluation-methodology skill |
| Codex | {context_used from response} |
| Gemini | {context_used from response} |
```

## Mode-Specific Additions

### Mode B: Module Scan

Replace the base template's header section with a summary table:

```markdown
## Module Evaluation Summary: {module} (Multi-Model)

| Component | Type | Consensus Score | Agreement | Key Issue |
|-----------|------|----------------|-----------|-----------|
| {name} | {type} | {n}/{max} | {n}/{total} ({pct}%) | {most important improvement} |

**Module Average**: {avg}/{max}
**Model Agreement**: {overall agreement rate}%
**Bias Alerts**: {count of self-enhancement flags, if any}
```

### Mode C: Before/After

Prepend a Verdict Consensus table before the Per-Criterion Consensus section:

```markdown
### Verdict Consensus

| Model | Before Score | After Score | Verdict |
|-------|-------------|-------------|---------|
| Claude | {n}/{max} | {n}/{max} | {improved|degraded|lateral} |
| Codex | {n}/{max} | {n}/{max} | {improved|degraded|lateral} |
| Gemini | {n}/{max} | {n}/{max} | {improved|degraded|lateral} |
| **Consensus** | **{n}/{max}** | **{n}/{max}** | **{verdict}** |
```

Append a Regression Analysis section after Divergence Analysis:

```markdown
### Regression Analysis

{For each regression flagged by any model:}

#### C{n}: {criterion name} — Regression

**Before score**: {consensus before} → **After score**: {consensus after}

| Model | Flagged Regression? | Reasoning |
|-------|-------------------|-----------|
| Claude | {yes|no} | {reasoning excerpt} |
| Codex | {yes|no} | {reasoning excerpt} |
| Gemini | {yes|no} | {reasoning excerpt} |

**Consensus**: {confirmed regression|disputed — majority says no regression}
```

### Mode D: Output

Append a Dual-Axis Summary if static evaluation is available:

```markdown
### Dual-Axis Summary

| Axis | Score | Models | Agreement |
|------|-------|--------|-----------|
| Static (definition) | {consensus}/{max} | {n} models | {rate}% |
| Dynamic (output) | {consensus}/5 | {n} models | {rate}% |

**Gap Analysis**: {same logic as single-model Mode D gap analysis}
```
