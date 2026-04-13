# Divergent Techniques — Systems Set

This reference covers divergence techniques that work best when constraints, end states, or contradictions dominate the problem.

## 5. Constraint Removal

**Definition**: Temporarily remove a dominant constraint, explore what becomes possible, and then reintroduce the constraint to see what survives.

**When to use**: Use it when one limitation is shaping every idea before ideation even starts.

**Procedure**:

1. List the main technical, time, cost, or compatibility constraints.
2. Remove the most restrictive one.
3. Generate three to five ideas in the unconstrained space.
4. Reintroduce the constraint and keep only the ideas that still work or can be adapted.
5. Repeat with a different dominant constraint if needed.

**Example**: Removing latency or cost constraints from multi-model evaluation reveals panel-review or reproducibility-check ideas that can later be scaled back to something practical.

**Pitfalls**:

- Removing trivial constraints instead of the ones truly shaping the space.
- Forgetting to bring reality back in after ideation.

## 6. Reverse Engineering

**Definition**: Start from the ideal end state and work backward until the path reaches the current state.

**When to use**: Use it when the destination is clear but the sequence to reach it is not.

**Procedure**:

1. Describe the ideal outcome concretely.
2. Ask what must already be true for that outcome to exist.
3. Repeat the question until the chain reaches an actionable starting point.
4. Read the backward chain as the critical path.

**Example**: If the goal is `all core components at 16/16`, the backward chain exposes baseline reliability, criteria calibration, and systematic evaluate → evolve loops as prerequisites.

**Pitfalls**:

- Defining the target too vaguely.
- Stopping the backward chain before it reaches actionable ground.

## 7. TRIZ

**Definition**: Resolve contradictions by applying a proven set of inventive principles rather than accepting a trade-off as fixed.

**When to use**: Use TRIZ when the problem is clearly shaped like `improving A worsens B`.

**Procedure**:

1. State the contradiction explicitly.
2. Walk through the relevant inventive principles and generate at least one idea per plausible principle.
3. Record all ideas before judging them.
4. Check whether each idea truly resolves the contradiction or only moves it elsewhere.

**Top principles for ouroboros-style work**:

- Segmentation
- Taking Out
- Merging
- Prior Action
- Inversion
- Dynamicity
- Self-service
- Replace Mechanical System
- Parameter Change

**Example**: The contradiction `evaluation depth versus speed` can yield split fast-pass and deep-pass flows, precomputed baselines, or dynamic depth selection by change magnitude.

**Pitfalls**:

- Using TRIZ without first stating the contradiction.
- Treating every principle as mandatory.
- Accepting ideas that merely shift the trade-off instead of resolving it.
