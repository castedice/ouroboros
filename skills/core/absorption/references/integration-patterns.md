# Integration Patterns

How external concepts map to ouroboros module components. Applied during Step 2 (Knowledge Mapping) and Step 4 (Component Design) of the absorption workflow.

## Concept → Component Type Mapping

When absorbing external capabilities, the first question is: "What type of ouroboros component should this become?" The mapping depends on what the capability does, not what it's called in the source.

### Decision Procedure

For each external capability:

1. **Describe what it does** in one sentence, without source-specific terminology
2. **Match against component type definitions**:

| If the capability... | It maps to... | Because... |
|---------------------|--------------|-----------|
| Orchestrates a multi-step user-facing workflow | **Command** | Commands are user entry points that coordinate phases |
| Performs specialized analysis or content generation | **Agent** | Agents execute focused procedures delegated by commands |
| Provides domain knowledge or methodology reference | **Skill** | Skills are consumed by agents for decision-making during procedures |
| Defines a structured output format | **Template** | Templates standardize repeatable document structures |

3. **Validate against existing patterns**: Does the target module already have this type of component? Does it follow the same pattern? If not, check whether the capability might be better served by extending an existing component.

### Ambiguous Cases

| Ambiguity | Resolution | Rationale |
|-----------|-----------|-----------|
| Could be command or agent | Check if it needs user interaction → command; if purely delegated → agent | Commands own the user interface; agents own procedures |
| Could be agent or skill | Check if it involves tool use → agent; if it's reference knowledge → skill | Agents act; skills inform |
| Could be skill or template | Check if it's methodology → skill; if it's output structure → template | Skills guide process; templates guide format |
| Capability spans multiple types | Split into component per type | A "review workflow" might become: review command + reviewer agent + review-methodology skill |

### Type Validation Checklist

Before confirming a mapping, verify:

- [ ] The capability's type matches the component type's role in the ouroboros architecture
- [ ] An existing component of this type in the module follows a similar scope
- [ ] The capability is not too large for a single component (split if >200 lines expected for skills, >300 for commands)
- [ ] The capability is not too small for its own component (merge with related capability if <30 lines)

## Module Completeness Model

A module is complete when it covers its domain without gaps in the component pipeline. Completeness is evaluated per the minimum viable module rule and the pipeline integrity check.

### Minimum Viable Module

| Component | Required | Rationale |
|-----------|---------|-----------|
| 1+ Command | Yes | Every module needs at least one user entry point |
| Agent strategy | Yes | Either reuse core agents or create module-specific ones |
| README | Yes | Module overview with command listing |
| Skills | Optional | Only if agents need domain-specific methodology |
| Templates | Optional | Only if commands produce structured output |

### Pipeline Integrity Check

A module's command-agent-skill chain should have no broken links:

```
Command phases → delegate to → Agent procedures → consume → Skill references
     ↓                              ↓                          ↓
  Error handling              Output format                 See Also
```

Check each link:

1. **Command → Agent**: Every delegation in a command phase references an agent that exists
2. **Agent → Skill**: Every skill reference in an agent procedure points to a skill that exists
3. **Agent → Template**: Every structured output references a template that exists (or uses inline format)
4. **Skill → References**: Every reference file mentioned in a skill exists in the `references/` directory

Broken links indicate missing components that need generation.

## Overlap Detection

Before generating a new component, verify that the capability isn't already covered by an existing component. Overlap can be exact (same capability, same component) or partial (capability is a subset of an existing component's scope).

### Overlap Detection Procedure

1. **Name check**: Does any existing component have a similar name?
2. **Capability check**: Read existing component contents — does any section cover this capability?
3. **Scope check**: Is the existing component's scope broad enough to absorb this capability without exceeding its coherence boundary?

### Overlap Classification

| Type | Detection | Action |
|------|-----------|--------|
| **Exact overlap** | Existing component covers this capability completely | Skip generation; note in overlaps |
| **Partial overlap** | Existing component covers 30-70% of this capability | Evaluate: evolve existing component or create new + cross-reference |
| **Naming overlap** | Similar name but different capability | Generate with a disambiguated name; add cross-reference |
| **No overlap** | No existing component covers this capability | Generate new component |

### Scope Check

When considering whether to extend an existing component:

- **Extension is safe** if the new capability is a natural specialization of the existing component's domain
- **Extension is risky** if the new capability introduces a different concern (e.g., adding authentication logic to a formatting agent)
- **Rule of thumb**: If adding the capability increases the component by >30%, create a new component instead

## Integration Strategies

### Incremental Integration

Add components one at a time, validating each before proceeding. Best for Mode B (integrating into existing module) where each new component must fit with existing ones.

**Procedure**:

1. Sort gaps by priority and dependency order
2. Generate and validate the highest-priority independent gap first
3. After validation, check if subsequent gaps need adjustment based on what was generated
4. Repeat until all selected gaps are filled

**Advantage**: Each component is validated in context of what exists. Errors are caught early.
**Cost**: Slower than wholesale; multiple generation cycles.

### Wholesale Integration

Generate all components at once from a unified module spec. Best for Mode A (new module) where there are no existing components to integrate with.

**Procedure**:

1. Design the full module architecture
2. Generate all components in a single Module Spec
3. Validate all components together
4. Resolve any inter-component inconsistencies

**Advantage**: Faster; components are designed to work together from the start.
**Cost**: Harder to debug quality failures; a single inconsistency can cascade.

### Strategy Selection

| Situation | Strategy | Rationale |
|-----------|----------|-----------|
| Mode A: New module, 3+ components | Wholesale | No existing context to conflict with; design holistically |
| Mode A: New module, 1-2 components | Either | Small enough for wholesale; simple enough for incremental |
| Mode B: 1 gap to fill | Incremental | Single component, validate against existing module |
| Mode B: 2-3 gaps, independent | Incremental | Each gap can be generated and validated independently |
| Mode B: 2-3 gaps, interdependent | Wholesale | Interdependencies require simultaneous design |

## Post-Absorption Integration Plan

After new components are generated and validated, identify existing components that should be evolved to properly integrate the additions:

### Integration Points to Check

| New Component Type | Check Existing... | For... |
|-------------------|-------------------|--------|
| New command | Agents in same module | Agent procedures should acknowledge the new command's existence |
| New agent | Commands in same module | Command phases should delegate to the new agent where appropriate |
| New skill | Agents in same module | Agent procedures should reference the new skill for methodology |
| New template | Commands/agents that produce similar output | Output sections should reference the new template |

### Integration Plan Format

For each integration point found:

```markdown
| New Component | Existing Component | Integration Point | Suggested `/evolve` Focus |
|---------------|-------------------|-------------------|---------------------------|
| `{new path}` | `{existing path}` | {section/phase where reference should be added} | {specific change description} |
```

The integration plan feeds directly into the absorption report's "Next Actions" section as specific `/evolve` invocations.
