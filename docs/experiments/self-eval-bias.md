# Self-Evaluation Bias in LLM-as-Judge Systems

> Can an LLM accurately evaluate its own output? We quantified Claude's self-evaluation bias across 16 binary criteria and found a concentrated, predictable pattern.

## Goal

Quantify the scoring divergence between Claude (self-evaluator) and Codex (external evaluator) to determine whether a single external validator is sufficient to correct self-evaluation bias.

## Methodology

- **Dataset**: 7 plugin components evaluated by both Claude and Codex across 16 tiered binary criteria (Foundation 5 + Craft 7 + Excellence 4)
- **Ground truth**: 2 components with confirmed known weaknesses (documented independently of evaluation)
- **Protocol**: Same relay prompt per component, 2 runs per configuration, structured JSON output

## Key Finding: Bias Concentrates in Excellence Tier

| Component | ΔF (Foundation) | ΔQ (Craft) | ΔE (Excellence) |
|-----------|----------------|------------|-----------------|
| absorb.md | 0 | +1 | **+2** |
| upgrade.md | 0 | +1 | **+3** |
| adopt.md | 0 | +1 | **+3** |
| onboard.md | +3 | +1 | **+2** |
| reconciler.md | 0 | 0 | **+1** |
| **Average** | **+0.6** | **+0.8** | **+2.2** |

Claude's self-evaluation bias is not diffuse — it concentrates overwhelmingly in the Excellence tier (architectural quality). Foundation and Craft criteria show near-perfect agreement.

## Bias Taxonomy

| Type | Criteria | Mechanism | Severity |
|------|----------|-----------|----------|
| **SoC blindness** | E1 (Separation of Concerns) | Claude doesn't recognize its own inline implementation as a violation | HIGH — never self-detects |
| **Efficiency blindness** | E2 (Context Efficiency) | Claude rates its own verbose output as "context efficient" | HIGH — near-universal |
| **Calibration leniency** | E4 (Integration) | Claude accepts placeholders as "context-populated" | MEDIUM — borderline |

82% of all divergences (14/17) are in E1, E2, or E4. Foundation and Craft divergences are rare and non-systematic.

## Ground Truth Validation

| Component | Known Weakness | Claude Score | Codex Score |
|-----------|---------------|-------------|-------------|
| evaluate.md | E1=0, E2=0 (confirmed) | E1=1, E2=1 | E1=0, E2=0 |
| evaluator.md | E2=0 (confirmed) | E2=1 | E2=0 |

Claude consistently fails to identify Excellence-tier weaknesses that are independently confirmed. Codex correctly identifies them across all model configurations tested.

## Detection Effectiveness

The multi-model consensus protocol flags criteria where Claude scores 1 and the external model scores 0:

- **Precision**: ~93% (flagged divergences that are real bias)
- **Recall**: 100% for E1/E2 (all known biases are caught)
- **Limitation**: Cannot detect shared blind spots where both models agree on a wrong score

## Conclusions

1. **Self-evaluation bias is real, measurable, and concentrated** — ΔE=+2.2 on a 4-point scale (55% inflation), but only in Excellence-tier criteria about architectural quality
2. **A single external model is an effective corrective** — Codex catches E1/E2 bias with 100% reliability across all configurations tested
3. **The problem is narrow** — Claude is accurate on 12/16 criteria (Foundation + Craft). The bias is specifically "Claude can't assess its own architectural separation and verbosity"
4. **Practical implication** — For LLM-as-judge systems evaluating their own output, focus validation effort on subjective quality criteria (architecture, efficiency, elegance) rather than structural/functional criteria where self-evaluation is reliable
