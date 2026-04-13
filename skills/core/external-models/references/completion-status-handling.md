# Completion Status Handling

This reference defines how parse-heavy callers should treat ouroboros terminal completion blocks.

## Core Rule

Treat the terminal completion block as transport metadata rather than as payload content.
Strip only the final matching block before JSON parsing, section extraction, file capture, score extraction, or regex-based parsing.
If no terminal block is present, continue with the existing parser unchanged.

## Where It Matters

Current callers that already strip or ignore the block include `commands/core/adopt.md`, `commands/core/research.md`, `commands/core/generate.md`, `commands/core/absorb.md`, `commands/core/upgrade.md`, `commands/core/evaluate.md`, and `skills/core/validation/references/quality-gate-procedure.md`.
These flows parse structured content from host-agent responses, so terminal metadata must not leak into extraction logic.

## JSON Relay Channels

Strict JSON relay prompts must not include the terminal completion block at all.
`scripts/codex-relay.sh --output` expects a clean model payload and already provides a separate transport boundary through files and exit codes.
Do not ask external JSON relays to emit completion metadata.

## Host-Agent Outputs

Host agents may still append the terminal block on human-readable responses.
When a command parses those responses, strip the trailing block before looking for sections, JSON, or generated file bodies.
Keep earlier literal examples intact by stripping only the final block.

## Practical Rule

If the payload is meant for a machine parser, remove terminal metadata first.
If the payload is meant for a human and no downstream parser will inspect it, leave the block in place.
