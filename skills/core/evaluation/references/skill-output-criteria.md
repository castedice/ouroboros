# Skill Dynamic Evaluation Criteria (Output)

> Evaluates the quality of results generated while the skill is loaded.
> 5 binary criteria (0 or 1). Sum 0~5 → Level 1~4.

## Test Method

1. Present a relevant question/task while the skill is loaded, collect results
2. (Optional) Perform the same question without the skill → A/B comparison
3. Score collected results using criteria below

User may directly provide the output.

## C1: Knowledge Reflection

Is the skill's core knowledge reflected in the response?

- **1 point**: Key concepts, methodologies, and criteria defined in the skill appear concretely in the response. Uses the skill's specific terminology and frameworks
- **0 points**: Skill's content not reflected in the response at all. Answered with general knowledge only

## C2: Trigger Accuracy

Does auto-triggering work properly in relevant contexts?

- **1 point**: Skill activates on questions matching trigger conditions specified in description. Trigger phrases and actual activation are consistent
- **0 points**: Not activated on relevant questions. Or trigger status cannot be verified

## C3: Methodology Application

Is the skill's taught methodology actually applied?

- **1 point**: Procedures, checklists, and judgment criteria defined in the skill are actually applied in the output. Not just "knows the methodology" but "used the methodology"
- **0 points**: Mentions the skill's methodology but doesn't actually apply it. Or processes with its own approach

## C4: Enhancement Delta

Is there quality improvement compared to responses without the skill?

- **1 point**: In A/B comparison, the skill-loaded response is clearly superior in specificity, structure, and accuracy. Skill's existence value is demonstrated
- **0 points**: Response quality identical regardless of skill presence. Or A/B comparison impossible with no evidence of enhancement

## C5: Non-interference

Does it avoid triggering unnecessarily in unrelated contexts?

- **1 point**: Skill's methodology not inappropriately applied in questions unrelated to the skill. Trigger scope is properly bounded
- **0 points**: Skill intervenes in unrelated contexts adding unnecessary content. Trigger is too broad
