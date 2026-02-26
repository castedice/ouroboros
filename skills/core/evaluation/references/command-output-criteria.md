# Command Dynamic Evaluation Criteria (Output)

> Evaluates the quality of the complete workflow when a command is executed.
> 5 binary criteria (0 or 1). Sum 0~5 → Level 1~4.

## Test Method

1. Execute the command with test input ($ARGUMENTS)
2. Observe the entire workflow (phase progression, agent delegation, user interaction)
3. Score the final results and process using criteria below

User may directly provide execution logs/results.

## C1: Phase Completion

Were all defined phases completed normally?

- **1 point**: Phases defined in the command executed in order. Each phase's output connects as input to the next phase. No phase skipped (except optional ones)
- **0 points**: Phases interrupted midway, order reversed, or required phase missing

## C2: Agent Delegation Success

Did agent delegations actually occur and return valid results?

- **1 point**: Agent delegations specified in the command actually occurred. Agent returned meaningful results and command utilized them
- **0 points**: Agent delegation failed (not called, error, empty result), or agent results ignored while command self-processed

## C3: Output Relevance

Is the final output an appropriate response to $ARGUMENTS?

- **1 point**: Relevant and specific results generated for the user's input. Results change meaningfully when input changes
- **0 points**: Generic results unrelated to input, or template response ignoring the input

## C4: User Checkpoint Handling

Do user checkpoints actually function?

- **1 point**: Checkpoints defined in the command actually provide confirmation/choice opportunities to the user. User responses are reflected in subsequent workflow
- **0 points**: Checkpoints defined but actually skipped, or workflow proceeds regardless of user response

## C5: Error Resilience

Does it handle abnormal input or exceptions gracefully?

- **1 point**: Clear error messages or fallback behavior for wrong file paths, empty input, unexpected formats, etc.
- **0 points**: Infinite loops on abnormal input, meaningless output, or incorrect results generated without error
