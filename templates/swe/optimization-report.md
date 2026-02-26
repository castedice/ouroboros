# Optimization Report Template (Stage 8 — Optimize)

Depth markers: `[Light+]` = Light, Standard, Deep. `[Standard+]` = Standard, Deep. `[Deep]` = Deep only.

---

## Header <!-- [Light+] -->

```markdown
# Optimization Report: {title}

**Stage**: 8 — Optimize (TDD)
**Depth**: {Light | Standard | Deep}
**Task**: {task description}
**Upstream**: {path to Verification Report}
**Date**: {YYYY-MM-DD}
```

---

## Profiling Results <!-- [Standard+] -->

Bottleneck identification with measured data. Do not optimize based on intuition — profile first.

```markdown
### Profiling Methodology

- **Tool**: {profiling tool — e.g., cargo bench, node --prof, cProfile, go tool pprof}
- **Environment**: {hardware, OS, compiler flags, optimization level}
- **Data set**: {test data characteristics — size, distribution}
- **Duration**: {profiling run duration, number of iterations}

### Identified Bottlenecks

| # | Location | Operation | Time (%) | Calls | Avg Duration | Driving Constraint |
|---|----------|-----------|----------|-------|-------------|-------------------|
| 1 | {file:line or function name} | {what the code does} | {percentage of total} | {call count} | {average per call} | {constraint ID from Constraint Profile, or "general quality"} |
```

If no profiling tools available:

```markdown
**No profiling tools detected**. Performing static code analysis and algorithmic complexity assessment instead.

### Static Analysis Results

| # | Location | Concern | Complexity | Impact |
|---|----------|---------|-----------|--------|
| 1 | {file:line} | {e.g., nested loop, repeated allocation, synchronous blocking} | {O(n²), O(n log n), etc.} | {estimated impact on performance} |
```

---

## Optimizations Applied <!-- [Light+] -->

Each optimization documented with before/after measurements. At Light depth: code review observations and refactoring suggestions only (no profiling data).

```markdown
### Optimization {n}: {short description}

**Driving constraint**: {constraint ID from Constraint Profile, or "code quality"}
**Category**: {Performance — Hard constraint / Performance — Soft constraint / Code quality}

**Change**: {what was modified and why}

**Before**:
{measurement or code snippet showing the pre-optimization state}

**After**:
{measurement or code snippet showing the post-optimization state}

**Improvement**: {quantified improvement — e.g., "42% reduction in p99 latency", "3x throughput increase"}

**Test status**: All {n} tests passing (Green confirmed)
```

---

## Performance Summary <!-- [Standard+] -->

Consolidated before/after comparison for all optimizations.

```markdown
| # | Metric | Before | After | Improvement | Driving Constraint |
|---|--------|--------|-------|-------------|-------------------|
| 1 | {metric name — e.g., p99 latency, throughput, memory usage} | {value} | {value} | {percentage or absolute change} | {constraint ID} |
```

### Constraint Satisfaction

```markdown
| Constraint ID | Category | Target | Achieved | Status |
|--------------|----------|--------|----------|--------|
| {ID} | Hard / Soft | {threshold from Constraint Profile} | {measured value post-optimization} | Met / Not Met / N/A |
```

---

## Refactoring Applied <!-- [Light+] -->

Code quality improvements independent of performance. Each change must preserve Green state.

```markdown
| # | Change | Rationale | Files Modified |
|---|--------|-----------|---------------|
| 1 | {what was refactored — e.g., extract function, rename, simplify conditional} | {why — clarity, reduce duplication, improve naming} | {file paths} |
```

If no refactoring applied: `No refactoring changes — code quality is satisfactory.`

---

## Algorithmic Complexity Analysis <!-- [Deep] -->

Hot path analysis with algorithmic complexity assessment.

```markdown
### Hot Path Analysis

| # | Operation | Current Complexity | Required (from constraints) | Status | Notes |
|---|-----------|-------------------|---------------------------|--------|-------|
| 1 | {operation name} | {O(n), O(n log n), O(n²), etc.} | {required by constraint ID} | Acceptable / Needs Redesign | {justification or concern} |

### Alternative Algorithm Comparison

| Operation | Current Algorithm | Alternative | Complexity Trade-off | Decision |
|-----------|------------------|-------------|---------------------|----------|
| {operation} | {current — e.g., linear scan} | {alternative — e.g., hash map lookup} | {O(n) → O(1), but O(n) memory} | {kept / changed / deferred — with reason} |
```

If a fundamentally wrong algorithm is discovered:

```markdown
### Algorithmic Redesign Recommendation

**Operation**: {what needs redesign}
**Current**: O({current}) — {why it was chosen in Stage 3}
**Required**: O({needed}) — {constraint ID requiring better complexity}
**Recommendation**: Return to Stage 3 (Design) to select appropriate algorithm. Optimization is for tuning, not redesign.
```

---

## Alternative Benchmarks <!-- [Deep] -->

Comparative benchmarks against alternative implementations or established baselines.

```markdown
| Benchmark | Our Implementation | Alternative/Baseline | Difference | Notes |
|-----------|-------------------|---------------------|------------|-------|
| {benchmark name} | {our measurement} | {comparison value — e.g., reference implementation, published benchmark} | {difference} | {context — hardware, data size, methodology} |
```

---

## Remaining Technical Debt <!-- [Light+] -->

Known issues deferred with rationale and priority.

```markdown
| # | Item | Rationale for Deferral | Priority | Estimated Impact |
|---|------|----------------------|----------|-----------------|
| 1 | {technical debt item — e.g., unoptimized path, missing cache, hardcoded value} | {why not addressed now — low impact, needs more data, out of scope} | High / Medium / Low | {effect if left unaddressed} |
```

If no technical debt: `No remaining technical debt identified.`

---

## Green State Confirmation <!-- [Light+] -->

Final test suite output confirming all tests pass after all optimizations and refactoring.

```markdown
### Test Output

**Runner**: {test command used}
**Result**: {pass count}/{total count} passing

{fenced code block with full test runner output}
```

---

## Exit Criteria Checklist <!-- [Light+] -->

```markdown
- [ ] All optimizations have before/after measurements
- [ ] No optimization targets constraints outside the Constraint Profile
- [ ] All tests remain Green after every change
- [ ] Remaining technical debt documented with rationale
- [ ] {At Standard+} Profiling data identifies actual bottlenecks
- [ ] {At Standard+} Each optimization traces to a constraint
- [ ] {At Standard+} Performance summary with constraint satisfaction
- [ ] {At Deep} Algorithmic complexity analysis for hot paths
- [ ] {At Deep} Alternative benchmark comparisons
```
