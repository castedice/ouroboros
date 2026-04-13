# Divergent Techniques — Classic Set

This reference covers the classic divergence techniques used for incremental variation, assumption breaking, and ground-up reframing.

## 1. SCAMPER

**Definition**: A checklist-based technique that modifies an existing concept through Substitute, Combine, Adapt, Modify or Magnify, Put to other use, Eliminate, and Reverse.

**When to use**: Use SCAMPER when you already have an artifact and want structured variation on it.

**Procedure**:

1. Identify the exact artifact you are modifying.
2. Walk through the relevant SCAMPER lenses and skip any lens that stays unproductive after about 30 seconds.
3. Record every viable variation, even if it is only partial.
4. Pair SCAMPER with a more radical technique when the output stays too incremental.

**Example**: On `/evaluate` input parsing, SCAMPER might suggest diff-based targets, merged detection and context gathering, or evaluator-led target suggestion.

**Pitfalls**:

- Applying all seven lenses mechanically when only three or four matter.
- Treating SCAMPER as a radical technique when it mostly produces adjacent moves.

## 2. What-if

**Definition**: A technique that challenges assumptions by removing, inverting, or changing them in the form `What if [assumption] were different?`

**When to use**: Use it when the option space feels trapped by unspoken givens.

**Procedure**:

1. List five to eight assumptions about the situation.
2. Convert each assumption into a `What if` question.
3. Follow each question to a concrete consequence instead of stopping at the prompt.
4. Keep the ideas that still make sense when the original constraint returns.

**Example**: On plugin architecture, `What if commands were executable scripts?` or `What if multiple agents collaborated on one procedure?`

**Pitfalls**:

- Asking the question without exploring consequences.
- Challenging only safe assumptions instead of the high-leverage ones.

## 3. Analogy

**Definition**: A technique that borrows solutions from other domains by matching structural similarities rather than surface similarity.

**When to use**: Use it when the team feels stuck inside the local domain language.

**Procedure**:

1. Abstract the current problem down to its structure.
2. Identify two or three outside domains with the same structure.
3. Describe how those domains solve the analogous problem.
4. Translate the useful principles back into the original context.

**Example**: Evaluation can borrow gates from restaurant inspection, revise-and-resubmit loops from peer review, and reviewer plurality from code review.

**Pitfalls**:

- Forcing analogies that do not actually share structure.
- Importing mechanisms literally instead of translating principles.

## 4. First Principles

**Definition**: A technique that decomposes a problem to its fundamental truths and rebuilds from them instead of inheriting current implementation assumptions.

**When to use**: Use it when the current approach feels fundamentally misframed rather than merely under-optimized.

**Procedure**:

1. State the core goal in plain terms.
2. List the truths that remain valid even if the current implementation disappears.
3. Rebuild a fresh design from those truths.
4. Compare that ground-up design with the current state.
5. Extract bridge ideas that can be adopted without a full rewrite.

**Example**: Quality assurance can be reframed as continuous measurement plus human override instead of periodic on-demand evaluation only.

**Pitfalls**:

- Labeling assumptions as if they were first principles.
- Producing radical designs with no realistic bridge back to current constraints.
