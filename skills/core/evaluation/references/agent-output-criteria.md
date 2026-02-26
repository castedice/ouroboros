# Agent Dynamic Evaluation Criteria (Output)

> Evaluates the quality of results produced by running an agent.
> 5 binary criteria (0 or 1). Sum 0~5 → Level 1~4.

## Test Method

1. Evaluator constructs a test prompt suited to the agent's role
2. Invoke the agent via Task tool and collect results
3. Score the collected results using criteria below

User may directly provide the output (skipping steps 1–2).

## C1: Role Adherence

Does the output align with the agent's stated role/purpose?

- **1 point**: Content and tone match the role defined in agent's persona/description. Analysis/generation performed from the expected perspective
- **0 points**: Role violation (reviewer generating code, generator performing evaluation, etc.). Or generic response lacking specialization

## C2: Output Format Compliance

Is the defined output format followed?

- **1 point**: Output format specified in agent definition (tables, section structure, classification scheme, etc.) is reflected in the results. Output is parseable and usable
- **0 points**: Defined format ignored, free-form prose only. Or format is defined but not followed

## C3: Reasoning Depth

Is the reasoning depth appropriate for the task complexity?

- **1 point**: Complex tasks include multi-step reasoning, evidence, trade-off analysis. Simple tasks have appropriately proportioned depth
- **0 points**: Superficial responses for complex tasks ("this is good"), or unnecessarily verbose for simple tasks

## C4: Scope Boundary Respect

Did the agent stay within its scope?

- **1 point**: Actions stay within agent's tools and role boundaries. Read-only agent only suggests modifications without making them. Does not encroach on other agents' domains
- **0 points**: Actions beyond authority (analysis agent modifying files), or judgments outside role (evaluator making implementation decisions)

## C5: Actionability

Can the output lead to next actions?

- **1 point**: Contains specific next steps, improvement directions, or executable suggestions. The command/user receiving the output can act immediately
- **0 points**: Only conclusions like "this looks good." Next actions unclear. Or only abstract suggestions listed
