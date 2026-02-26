# Hook Dynamic Evaluation Criteria (Output)

> Evaluates the behavioral quality of a hook when triggered.
> 5 binary criteria (0 or 1). Sum 0~5 → Level 1~4.

## Test Method

1. Simulate the trigger situation (use the relevant tool, start session, etc.)
2. Observe the hook's actual behavior (block/transform/log)
3. Score observations using criteria below

User may directly provide execution logs.

## C1: Trigger Reliability

Does it trigger reliably on the intended event?

- **1 point**: Hook triggers 100% on defined event + matcher conditions. Trigger conditions work precisely
- **0 points**: Fails to trigger when it should, or intermittent trigger failures

## C2: Effect Correctness

Does the intended effect (block/transform/log) occur accurately?

- **1 point**: Effect matches hook's purpose. Blocking hook blocks correctly, transform hook transforms correctly, logging hook records accurate information
- **0 points**: Effect doesn't occur, wrong effect occurs (should block but passes), or transformation produces incorrect results

## C3: False Positive Rate

Does it avoid triggering in unnecessary situations?

- **1 point**: Does not trigger on unrelated tool usage, unrelated file access, etc. Matcher properly bounds the scope
- **0 points**: Frequently triggers in unintended situations. Degrades user experience

## C4: Performance Impact

Is execution time within timeout with no perceptible delay?

- **1 point**: Hook execution time within 50% of configured timeout. No perceptible delay for the user
- **0 points**: Approaches or exceeds timeout. Or frequent triggering causes cumulative perceptible delay

## C5: Graceful Failure

Does hook failure avoid interrupting the Claude session?

- **1 point**: Claude session continues normally on exceptions like script errors, network failures. Errors are properly logged or silently handled
- **0 points**: Hook failure interrupts the Claude session. Or unpredictable behavior on error
