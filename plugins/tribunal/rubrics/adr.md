# ADR Rubric

Evaluate the submitted Architectural Decision Record on the following criteria.

## Criteria

**1. Citation Accuracy (25%)**

All citations must be factually correct and verifiable. This criterion is critical for maintaining research integrity.

Evaluate:
- **Author names**: Match the actual paper authors (attributions are correct)
- **Publication year**: Accurate to the paper's publication date
- **Paper titles**: Exact or accurate paraphrasing
- **Identifiers**: arXiv IDs, DOIs, URLs resolve to the cited work
- **No fabrication**: All cited works must be real and verifiable

Red flags:
- Author names that don't match the actual paper (e.g., citing "Uesato et al." for a paper by "Fu et al.")
- arXiv IDs that return 404 or point to different papers
- DOIs that don't resolve
- Paper titles that don't match the actual publication
- Citations without sufficient detail to verify (missing year, venue, or identifier)

**2. Internal Link Validity (15%)**

All cross-references to other ADRs must resolve to existing files.

Evaluate:
- Links to other ADRs (e.g., `[ADR-0005](0005-judge-persona-panel.md)`) point to files that exist in the repository
- Relative paths are correct from the ADR's location
- No broken cross-references
- If an ADR claims to supersede another, that ADR exists and is referenced correctly

Verification method: Check that each linked file path exists in the expected location.

**3. Status Field Validity (10%)**

The Status field must conform to standard ADR status values.

Valid statuses:
- **Proposed**: Decision is under consideration
- **Accepted**: Decision has been approved and is active
- **Deprecated**: Decision is no longer recommended but not formally replaced
- **Superseded**: Decision has been replaced (must include link to superseding ADR)
- **Rejected**: Decision was considered but not adopted

Requirements:
- Status must be exactly one of the above values (case-sensitive)
- If status is "Superseded", the ADR must link to the superseding ADR
- Status should align with the document's content and context

**4. Option Analysis Completeness (20%)**

For each option considered but NOT chosen, the ADR must explain why it was rejected.

Evaluate:
- **Presence of alternatives**: At least 2-3 options should be considered
- **Rejection rationale**: Each non-chosen option has clear reasons for rejection
- **Substantive reasoning**: Rationale goes beyond "not chosen" or "less preferred"
- **Trade-off clarity**: Comparison makes trade-offs between options explicit
- **Fairness**: Rejected options are presented fairly, not strawmanned

Poor examples:
- "Option B: Considered but rejected"
- "Not as good as Option A"

Strong examples:
- "Option B: Rejected because it requires 3x more memory and our deployment environment has 8GB RAM limits"
- "Option C: Adds unnecessary complexity for our current scale (10K requests/day); would be viable at 1M+ requests/day"

**5. Consequences Balance (15%)**

The Consequences section must acknowledge both benefits and costs of the decision.

Requirements:
- **At least one Good consequence**: Positive outcomes or benefits
- **At least one Bad consequence**: Costs, risks, or limitations
- **Honest assessment**: No decision is perfect; trade-offs must be acknowledged
- **Neutral consequences**: Acceptable for uncertain or mixed outcomes

Red flags:
- Only "Good" consequences listed (unrealistic)
- Bad consequences that are trivial or dismissive
- Missing acknowledgment of technical debt, complexity, or maintenance burden
- Consequences that don't relate to the decision made

**6. Decision Traceability (15%)**

The chosen option must logically connect to the stated problem and decision drivers.

Evaluate:
- **Problem alignment**: The decision addresses the problem stated in Context
- **Driver coverage**: The decision responds to the Decision Drivers listed
- **No scope creep**: The decision doesn't introduce unstated requirements
- **Justification clarity**: It's clear WHY this option was chosen over alternatives
- **Consistency**: The decision doesn't contradict stated constraints or principles

Questions to answer:
- Does the decision solve the problem described in the Context section?
- Do the Decision Drivers explain why this option was chosen?
- Are there unstated assumptions that should have been in the Drivers?

## Scoring

**Scoring scale: 0.0 to 1.0**

Each criterion receives a score from 0.0 (completely fails) to 1.0 (exemplary), then weighted by the percentages above.

### Criterion Scoring Guidelines

**Per-criterion thresholds:**

- **1.0 (Exemplary)**: Fully satisfies all requirements with no issues
- **0.8-0.9 (Strong)**: Minor issues that don't undermine the criterion
- **0.6-0.7 (Acceptable)**: Some gaps or weaknesses but core requirements met
- **0.4-0.5 (Weak)**: Significant issues; criterion partially satisfied
- **0.0-0.3 (Failing)**: Critical failures; criterion not satisfied

**Weighted scoring example:**

If Citation Accuracy scores 0.6, Internal Links score 1.0, Status scores 1.0, Options score 0.8, Consequences score 0.7, and Traceability scores 0.9:

```
Final = (0.6 × 0.25) + (1.0 × 0.15) + (1.0 × 0.10) + (0.8 × 0.20) + (0.7 × 0.15) + (0.9 × 0.15)
      = 0.15 + 0.15 + 0.10 + 0.16 + 0.105 + 0.135
      = 0.80
```

### Pass/Fail Thresholds

- **0.80+**: Pass (high quality)
- **0.70-0.79**: Pass with reservations (needs minor improvements)
- **0.60-0.69**: Fail (needs revision)
- **Below 0.60**: Fail (needs substantial revision)

### Critical Failures

The following issues trigger automatic failure regardless of overall score:

- **Hallucinated citations**: Any fabricated author, paper, or identifier
- **Broken internal links**: Links to non-existent ADRs (for Superseded status)
- **Invalid status**: Status field contains a non-standard value
- **No consequences listed**: Missing both Good and Bad consequences
- **No option analysis**: Only one option presented with no alternatives considered

## Feedback Guidance

Provide actionable, specific feedback for each failed or weak criterion.

### Citation Accuracy Feedback

**For hallucinated or incorrect citations:**
- Identify the specific citation with the error
- State what is incorrect (author, year, title, identifier)
- If possible, provide the correct citation or note that the work cannot be verified
- Suggest verification steps (e.g., "Search arXiv for the provided ID")

Example:
```
Citation Accuracy: FAIL (0.2/1.0)
- The citation "Uesato et al. (2022)" in the Context section does not match the
  actual paper authors. The arXiv ID provided (arXiv:2212.09251) corresponds to
  a paper by Fu et al., not Uesato et al.
- Correct the author attribution to "Fu et al." or verify the correct arXiv ID
  for the intended Uesato paper.
```

### Internal Link Validity Feedback

**For broken links:**
- List each broken link with its target path
- Note whether the file doesn't exist or the path is incorrect
- If the ADR exists under a different name/path, suggest the correction

Example:
```
Internal Link Validity: FAIL (0.0/1.0)
- Link to [ADR-0003](0003-old-name.md) is broken. File does not exist in /docs/adr/
- If this ADR has been renamed, update the link to the current filename.
```

### Status Field Validity Feedback

**For invalid status:**
- State the current status value
- List the valid status options
- If the status is "Superseded", verify the link to the superseding ADR

Example:
```
Status Field Validity: FAIL (0.0/1.0)
- Status "In Progress" is not a valid ADR status.
- Use one of: Proposed, Accepted, Deprecated, Superseded, Rejected
- For work-in-progress ADRs, use "Proposed"
```

### Option Analysis Completeness Feedback

**For weak or missing analysis:**
- Identify options that lack rejection rationale
- Point out dismissive or vague reasoning
- Request specific technical, cost, or constraint-based justification

Example:
```
Option Analysis Completeness: WEAK (0.5/1.0)
- Option 2 states "Not selected" without explaining why
- Option 3's rejection rationale is vague: "Adds complexity"
- Clarify: What specific complexity? How does it compare to Option 1's complexity?
- Provide measurable or technical reasons (e.g., lines of code, dependencies, performance impact)
```

### Consequences Balance Feedback

**For unbalanced consequences:**
- Note if only Good or only Bad consequences are listed
- Request acknowledgment of trade-offs or costs
- Highlight if consequences seem unrealistic or incomplete

Example:
```
Consequences Balance: WEAK (0.4/1.0)
- Only "Good" consequences listed (improved performance, easier testing)
- Every decision has trade-offs. Consider:
  - Does this add complexity to deployment?
  - Does it increase dependencies or maintenance burden?
  - Are there learning curve costs for the team?
- Add at least one "Bad" consequence to acknowledge the decision's costs.
```

### Decision Traceability Feedback

**For weak traceability:**
- Point out disconnects between decision and problem/drivers
- Note if the decision introduces scope beyond stated requirements
- Request clarification on how the decision addresses the drivers

Example:
```
Decision Traceability: WEAK (0.5/1.0)
- Decision Driver #2 states "Must support 1000 concurrent users" but the chosen
  option's justification doesn't address scalability
- The decision introduces a "real-time sync feature" not mentioned in the Context
  or Drivers. Is this requirement missing from the Drivers section?
- Clarify how the chosen architecture meets the concurrency requirement.
```

## Meta-Guidance

**For Judges using this rubric:**

1. **Citation verification is mandatory**: Do not skip checking citations. Use the provided identifiers (arXiv, DOI) to verify works exist and authors are correct.

2. **Be strict on hallucinations**: A single fabricated citation should result in a score below 0.60 (failure). Research integrity is non-negotiable.

3. **Internal links**: Check the repository structure to verify linked ADRs exist. This is a factual check, not subjective.

4. **Require substantive analysis**: "Option B: Not chosen" is insufficient. Push for technical reasoning, not hand-waving.

5. **Demand honesty about trade-offs**: No decision is perfect. If the ADR claims zero downsides, it's incomplete.

6. **Consistency check**: Read the entire ADR to ensure the decision, drivers, and consequences form a coherent narrative.

**Common pitfalls to avoid:**

- Accepting citations without verification (this caused the ADR-0007 issue)
- Giving full credit for "Consequences" when only positive outcomes are listed
- Accepting vague option analysis like "less suitable" or "not optimal"
- Not checking whether linked ADRs actually exist in the repository
- Confusing "Neutral" consequences with "no consequences"

**Time-saving tips:**

- Verify citations first (highest weight, objective check)
- Use repository file search to batch-check internal links
- Skim for presence of Good/Bad consequences before detailed reading
- Check Status field immediately (quick objective check)
