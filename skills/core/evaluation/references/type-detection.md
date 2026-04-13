# Type Detection

This reference explains how evaluation, validation, and generation determine component type.
It documents both existing-file classification and requested-target inference.
Use this file when the caller needs the classification procedure before loading criteria or validation rules.

## Two Detection Problems

Existing-file detection asks, "What kind of component is this file that already exists on disk."
Target-type inference asks, "What kind of component should `/generate` create from this request."
The two problems overlap, but they are not identical.
Existing-file detection leans on path and frontmatter.
Target-type inference in `/generate` starts from user input and only later returns to path and frontmatter.

## Existing-File Detection

`/evaluate` and the validation workflow classify existing files from their path and metadata.
Path is the primary signal because ouroboros has stable directory conventions.
Frontmatter is the confirmation and exception-handling signal.
If path and frontmatter disagree, the file is not treated as cleanly classified.
If the file sits outside canonical locations, frontmatter becomes more important.

## Canonical Path Map

Files under `commands/` default to `command`.
Files under `agents/` default to `agent`.
Files under `skills/` default to `skill`.
Files under `templates/` default to `template`.
`hooks.json` maps to `hook`.
`CLAUDE.md` maps to `claudemd`.
Files outside those locations need extra evidence before they can be classified confidently.

## Evaluate Command Usage

Mode A reads one target file and then detects its type from filename and frontmatter.
Mode B scans a module and builds a component list with detected types.
Mode C reads before and after files and requires both to resolve to the same type.
Mode D reads the component definition first, detects its type, and then loads the matching output criteria file.
Type detection in `/evaluate` happens before structural validation and before criteria loading.

## Validation Workflow Usage

Validation states the rule directly.
It identifies component type from location, structure, and frontmatter.
It then runs type-specific field checks for that class.
If the component still does not classify cleanly, validation stops instead of guessing.
This stop rule exists because wrong classification loads the wrong rule set and produces noisy errors.

## Path First

Path is the fastest discriminator because the repo layout is opinionated.
`commands/core/evaluate.md` is a command unless strong evidence proves otherwise.
`agents/swe/reviewer.md` is an agent unless the file is malformed.
`skills/core/evaluation/SKILL.md` is a skill because the directory and filename both match the skill pattern.
Path also determines some expected naming conventions before frontmatter is even read.

## Frontmatter Second

Frontmatter confirms that the file behaves like the type suggested by its path.
A command should expose command-style fields such as `name` and trigger-style `description`.
An agent should expose agent-style fields such as `model`, `color`, and usually `tools`.
A skill should expose skill-style fields such as `name`, trigger-rich `description`, and the expected skill body structure.
A template should expose `title` and `description` instead of executable metadata.
When those expectations fail, classification becomes suspect even if the path looks right.

## Command Signals

Command names derive from the file path.
`commands/core/evaluate.md` should resolve to `name: core:evaluate`.
Router commands are the exception because `commands/pa.md` maps to `name: pa`.
Command descriptions must start with `Use when`.
Workflow-summary descriptions are a validation smell even if the file still classifies as a command.

## Agent Signals

Agents use `name`, `description`, `model`, and `color` as required frontmatter.
Agent descriptions behave like trigger blocks rather than one-line summaries.
The usual optional confirmation signal is an explicit `tools` list.
Missing `color` is a structural error, but the file still points toward the `agent` class.
The presence of agent-only fields helps confirm classification when the path is ambiguous.

## Skill Signals

Skills use `name` and `description` as the required frontmatter pair.
Skill descriptions use third-person activation language with quoted trigger phrases.
The body normally includes `Core Rule`, `Gotchas`, `Workflow`, `Decision Rules`, `Reference Map`, and `See Also`.
That body structure is a strong secondary signal when path and frontmatter alone are insufficient.
`preamble_tier` is common in current skills, but it is not the primary classifier.

## Template Signals

Templates are the simplest class.
They are usually detected by path first because template frontmatter is intentionally minimal.
`title` and `description` are the expected metadata fields.
Templates do not advertise models, tools, or activation triggers.
That absence helps distinguish them from skills and agents.

## Hook Signals

Hooks are stored in `hooks.json`, not in markdown frontmatter.
Their schema uses fields such as `matcher`, `type`, `command`, and `timeout`.
Because hooks do not live under the markdown component directories, their location is the dominant signal.
Validation then applies hook-specific field checks and safety rules.

## CLAUDE.md Signals

`CLAUDE.md` is evaluated with its own criteria class.
It does not rely on component frontmatter because it is not a normal runtime component file.
Its special filename is the classification key.
If another markdown file imitates `CLAUDE.md` structure but is not actually `CLAUDE.md`, it should not inherit that type automatically.

## Outside-Normal-Directory Rule

The evaluation operating model defines the fallback rule for unusual paths.
If a markdown file sits outside the normal directories, frontmatter should be used to classify it.
If frontmatter still does not settle the type, the command should stop and ask the user.
This prevents silent mis-scoring under the wrong rubric.
It also prevents templates, docs, and knowledge entries from being mistaken for executable components.

## Generate Phase 1

`/generate` solves a different problem first.
It decides whether the request is Mode A module generation or Mode B component generation.
A target without `/` is treated as a module candidate.
A target with `/` is treated as a component candidate.
That first split is about scope, not component type.

## Generate Requested-Type Inference

Mode B accepts an explicit `--type` flag.
If `--type` is present, `/generate` uses it directly.
If `--type` is absent, `/generate` infers type from description keywords.
`"command that"` suggests `command`.
`"agent for"` suggests `agent`.
`"skill about"` suggests `skill`.
`"template for"` suggests `template`.
If the description stays ambiguous, `/generate` defaults to `command`.

## Generate Path Validation

Even during target inference, `/generate` still uses path to constrain legal outcomes.
The module segment must already exist for Mode B.
The component file must not already exist in any type directory for that module.
Those checks prevent the generator from inferring a type that conflicts with the existing module surface.
The generator therefore combines user intent with path feasibility before it writes anything.

## Generate Post-Write Classification

After Phase 5 writes files, `/generate` switches back to existing-file classification.
Phase 5.5 explicitly identifies each generated component type from file location and frontmatter.
It then applies type-specific validation.
This step is the bridge between inferred target type and actual file validity.
If the generated frontmatter does not match the expected class, auto-fix or validation catches it.

## Why Path And Frontmatter Both Matter

Path alone is fast but can be wrong for misplaced or malformed files.
Frontmatter alone is flexible but can be vague or partially broken.
Using both makes false classification harder.
The repo layout gives the default class.
Frontmatter and structure confirm whether the file actually satisfies the expectations of that class.

## Stop Conditions

Stop when the file is outside canonical component directories and frontmatter is inconclusive.
Stop when before and after files resolve to different types in `/evaluate`.
Stop when a requested Mode B target collides with an existing component path.
Stop when the caller would need criteria for two incompatible types at once.
Do not guess just to keep the workflow moving.

## Common Failure Patterns

A command file missing `name` is still probably a command, but validation should fail it structurally.
A skill file with a generic description is still probably a skill, but the trigger quality should fail.
A template with agent-style fields is suspicious because its metadata does not fit its directory.
A markdown doc outside component directories should not be forced into a runtime class without clear frontmatter evidence.
An ambiguous generate request without `--type` should not invent a niche class and instead falls back to `command`.

## Practical Procedure

Start with canonical path mapping.
Read the frontmatter and look for type-specific required fields.
Check whether body structure reinforces or weakens that classification.
Apply special-case rules for `hooks.json` and `CLAUDE.md`.
If the file is still ambiguous, stop and ask.
Only after type resolution should you load criteria, validation checks, or output rubrics.

## Related References

Use `evaluation-operating-model.md` for the criteria map that depends on the resolved type.
Use `frontmatter-and-fields.md` for the field-level rules that confirm each class.
Use `regeneration-loop.md` when generated files fail validation after their inferred type is materialized on disk.
