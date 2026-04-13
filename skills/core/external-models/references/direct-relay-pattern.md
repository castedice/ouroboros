# Direct Relay Pattern

This reference defines the specialist direct relay pattern that replaces the SWE Bridge Agent.

## Use Case

Use direct relay when an external model should produce a stage artifact but the host must still own validation, file writes, tests, and acceptance.
This is the default routed-stage pattern for `commands/swe/spiral.md`.

## Stage Loop

Read the assigned context files and upstream artifacts first.
Read the stage requirements from `skills/swe/methodology/references/agent-instructions.md`.
Build a stage prompt that states the stage purpose, expected artifact shape, depth, and required bindings.
Start a fresh external session for the stage and capture its `thread_id`, or resume the saved thread when the follow-up is still within the same stage scope.
Use `scripts/codex-relay.sh` with `--text-output` for markdown artifacts. The `--meta` sidecar is auto-generated whenever `--output` or `--text-output` is used, preserving `thread_id` for resume.
Evaluate the response against the stage pass condition before promoting it into `.swe/active/`.
If the response is incomplete or incorrect, send a targeted follow-up through resume on the same thread.
After an acceptable response, save the artifact to `.swe/active/{NN}-{stage}.md` and report completion back to the team flow.
No Bridge intermediary is involved.

## Pass Conditions

For spec stages, require named sections with substantive content and the stage-required fields.
For development stages, require code or guidance that satisfies interface contracts and leads to passing tests or checks.
Treat generic or placeholder output as a failed turn rather than as a partial success.

## Follow-Up Prompt Discipline

Resume prompts should describe the exact missing constraint, failed test, absent section, or contract violation.
Do not restart the whole stage prompt unless the thread has drifted beyond repair.
Keep one thread per stage so follow-up prompts refer to stable context.

## Host Ownership

The Director or host command owns local file operations, artifact writes, and test execution in the current design.
The external model supplies reasoning, draft content, or debugging guidance.
This keeps repository mutation under local control even when the external model contributes heavily to the solution.

## Circuit Breaker

Limit stage retries to three attempts unless the caller explicitly overrides the policy.
If the external loop fails repeatedly, escalate with the specific failure reason and a fallback recommendation.
If `codex` is unavailable at startup, escalate immediately instead of entering the stage loop.
