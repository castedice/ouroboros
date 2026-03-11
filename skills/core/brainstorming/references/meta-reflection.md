# Meta-Reflection Techniques

Three structured techniques for reflecting on the brainstorming process itself after the Select stage. Meta-reflection asks not "Did we pick the right idea?" but "Did we solve the right problem?" and "What did our process miss?"

## When to Apply

Meta-reflection is **optional** and triggered after the Select stage. It adds value when:

- The brainstorming session produced unexpectedly few ideas (< 8) or unexpectedly homogeneous clusters
- The top 3 ideas all came from the same technique or the same person/model
- The problem was reframed during the session (suggesting the original framing was wrong)
- The stakes are high — a wrong direction is costly to reverse
- The session used the Triple Diamond framework (which includes Reflect as a built-in phase)

Skip meta-reflection when the session was straightforward, the results are clear, and the cost of being wrong is low. Not every brainstorm needs introspection — apply it selectively.

**Duration**: 3-5 minutes. Meta-reflection should be a quick checkpoint, not a second brainstorming session. If reflection reveals significant concerns, the appropriate response is to re-run the brainstorm with a revised frame, not to extend reflection indefinitely.

---

## 1. Double Loop Learning

**Definition**: Single-loop learning asks "Are we doing things right?" Double-loop learning asks "Are we doing the right things?" Applied to brainstorming, it means questioning not just the ideas selected but the problem definition, the techniques used, and the assumptions that shaped the entire session.

**When to use**: After any brainstorming session where the results feel unsatisfying despite a well-executed process. If the process was followed correctly but the output still feels wrong, the issue is likely in the framing or assumptions, not the techniques.

**Procedure**:

1. Review the Frame stage output: "Was the problem we brainstormed actually the right problem?"
2. Review the technique selection: "Did our choice of techniques bias the results?" (e.g., SCAMPER-heavy sessions produce incremental ideas)
3. Identify governing assumptions: "What did we take for granted that we never questioned?"
4. Test each assumption: "If this assumption were wrong, would our top 3 change?"
5. If any assumption failure would change the results, flag it as a risk and consider re-running with the assumption explicitly challenged

**Example**: Double Loop Learning after brainstorming "how to improve multi-model evaluation reliability":

- *Single loop*: We generated 12 ideas for improving relay scripts, prompt formatting, and output parsing. Top 3 are all about making Codex output more consistent. Process was solid.
- *Double loop*: Wait — we assumed "reliability" means "cross-model agreement." But what if reliability means "correlation with human judgment"? Three models agreeing on a wrong answer is reliable but useless. We should re-run with the reframed question: "How might we ensure evaluation results correlate with actual component quality?"
- *Governing assumption identified*: "Model consensus = quality" — this assumption shaped every idea in the session

**Pitfalls**:

- Using double-loop as an excuse to reject results you simply dislike — the question is "did we solve the right problem?", not "do I like the answer?"
- Infinite regress — you can always question assumptions further; stop when the check is actionable

---

## 2. Assumption Mapping

**Definition**: A structured audit of the hidden assumptions that shaped the brainstorming session. Every brainstorm operates within a frame, and every frame includes unexamined assumptions. Assumption Mapping makes them visible so they can be challenged, validated, or accepted consciously.

**When to use**: When the brainstorming results feel internally consistent but potentially blind to important factors. Assumption Mapping is especially valuable when the brainstorm topic involves cross-cutting concerns (architecture, workflow, multi-user) where implicit assumptions about one aspect constrain thinking about another.

**Procedure**:

1. List every assumption embedded in the Frame stage output (explicit and implicit):
   - Technical assumptions: "The current architecture supports this"
   - Resource assumptions: "We have time/budget for this"
   - User assumptions: "Users want this" or "Users use it this way"
   - Constraint assumptions: "This constraint is real and immovable"
2. Classify each assumption on two axes:
   - **Certainty**: How confident are we that this is true? (High / Medium / Low)
   - **Impact**: If this assumption is wrong, how much do our results change? (High / Medium / Low)
3. Focus on **Low Certainty + High Impact** assumptions — these are the dangerous blind spots
4. For each dangerous assumption, decide: validate now (quick check), flag as risk (note in output), or re-run (brainstorm again without this assumption)

**Example**: Assumption Mapping after brainstorming "what should the next ouroboros module be":

| Assumption | Certainty | Impact | Action |
|------------|-----------|--------|--------|
| Users want more modules (not better existing ones) | Medium | High | Flag — survey users before committing |
| The modular monolith architecture scales to 10+ modules | High | High | Accept — validated by current structure |
| Plugin load time is acceptable with more modules | Low | Medium | Validate — measure current load time |
| Each module is independently useful | Medium | High | Flag — some module ideas only work in combination |
| The evaluate/evolve loop works for any module type | Low | High | **Dangerous** — the loop was designed for document-like components; code-heavy modules may need different quality criteria |

- *Key finding*: The assumption that "evaluate/evolve works for any module type" is low certainty and high impact. If wrong, adding a code-generation module would require redesigning the quality pipeline first. This should be validated before proceeding.

**Pitfalls**:

- Listing only technical assumptions — organizational, user, and process assumptions are equally important
- Treating all assumptions as equally important — focus on the low certainty + high impact quadrant
- Mapping assumptions without acting on findings — each dangerous assumption needs a concrete next step

---

## 3. Reflection Trigger

**Definition**: A structured post-convergence checkpoint that asks three diagnostic questions to catch systematic blind spots in the brainstorming output. Unlike Double Loop Learning (which questions the problem) and Assumption Mapping (which audits assumptions), Reflection Trigger specifically checks for missing perspectives.

**When to use**: As a quick final check before presenting brainstorm results. Reflection Trigger takes 2-3 minutes and catches the most common brainstorming blind spots: missing stakeholders, overlooked constraints, and technique bias.

**Procedure**:

1. Ask the Perspective Question: "What perspective is absent from our top 3?"
   - Check against Stakeholder Mapping results (if used during Frame)
   - If no stakeholder analysis was done, quickly list affected parties and check if any are unrepresented
2. Ask the Constraint Question: "What constraint did we unconsciously accept or ignore?"
   - Review the constraints identified during Frame — were any quietly dropped during divergence?
   - Were any new constraints discovered during the session that were not addressed?
3. Ask the Technique Question: "Did our technique selection bias our results?"
   - Check technique attribution: if 70%+ of top-3 ideas came from one technique, consider whether a different technique would produce a different top 3
   - Check for technique-topic mismatch: did we use SCAMPER on a green-field problem? Analogy on a domain with no good analogues?
4. If any question reveals a significant gap, append a "Blind Spot Warning" to the brainstorm output rather than re-running the entire session

**Example**: Reflection Trigger after brainstorming "how to improve the /generate command":

1. *Perspective*: All top 3 ideas improve generation quality for the command author. But what about the evaluator agent that scores generated components? If generation improves but evaluation criteria do not update, the quality bar may become misaligned. Missing perspective: evaluator/criteria maintainer.
2. *Constraint*: We assumed the generated component must be a single file. But some module types (like SWE) have multi-file components (command + agent + skill). We unconsciously constrained to single-file generation.
3. *Technique*: SCAMPER produced 8 of 12 ideas. All top 3 are SCAMPER-derived (modifications to existing generation flow). A First Principles round might produce a fundamentally different approach to generation.
4. *Blind Spot Warning*: "Results biased toward incremental improvement of single-file generation. Consider re-running with First Principles technique and multi-file generation as an explicit possibility."

**Pitfalls**:

- Treating every gap as a reason to re-run — most gaps can be noted as caveats rather than requiring a full redo
- Skipping the technique question — technique bias is the most common and least noticed brainstorming failure
- Perfectionistic application — Reflection Trigger is a quick check, not an audit; 2-3 minutes maximum
