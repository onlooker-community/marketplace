# 0007 — Actor self-challenge before submission

Date: 2026-04-02
Status: Accepted

## Context and Problem Statement

Tribunal's current design separates production from evaluation: the Actor executes the task and submits output, then the Judge evaluates quality, then the Meta-Judge reviews for bias. All skepticism happens post-submission.

Research on producer-evaluator architectures (RefineRL, arXiv:2604.00790) demonstrates that **skepticism internalized by the producer outperforms skepticism applied only by the evaluator**. When the producer actively self-challenges before submission — questioning assumptions, probing edge cases, anticipating critiques — output quality improves more than when an external evaluator applies the same level of scrutiny after the fact.

This raises the question: should the Actor perform pre-submission self-challenge, or should Tribunal maintain strict separation of concerns and rely entirely on the Judge for quality evaluation?

The current Actor prompt includes a "Quality checks before submission" section with high-level guidance (run tests, validate syntax, check edge cases), but this is not structured skepticism-driven self-challenge. It is basic hygiene checking, not adversarial probing.

## Decision Drivers

- RefineRL evidence suggests internalized producer skepticism reduces iteration cycles and improves final quality.
- Clear separation of concerns (Actor produces, Judge evaluates) is architecturally clean and makes role boundaries explicit.
- The Actor already has task context, rubric access, and domain knowledge — it is well-positioned to anticipate Judge critiques.
- Self-challenge adds cognitive overhead to the Actor's execution phase, potentially slowing down first-iteration output.
- The Judge provides an external perspective that may catch blind spots the Actor would miss even with self-challenge.
- Tribunal already has a multi-persona judge panel (ADR 0005) that surfaces diverse issues — Actor skepticism could complement this rather than duplicate it.

## Considered Options

- **Option A: Current Design (Actor submits, Judge evaluates)**
  - Actor focuses purely on task execution with basic quality checks.
  - All substantive skepticism and quality evaluation happens post-submission via Judge.
  - Clear separation of concerns: Actor = producer, Judge = evaluator, Meta-Judge = quality assurance.
  - Judge provides external perspective unconstrained by Actor's mental model.

- **Option B: Actor Self-Challenges Before Submission**
  - Actor applies a skepticism-driven checklist before submitting (e.g., "What assumptions am I making?", "What edge cases did I miss?", "What would the adversarial judge say?", "What breaks if inputs are malformed?").
  - Structured as a mandatory pre-submission phase, not optional hygiene checks.
  - Actor anticipates Judge critiques and fixes issues proactively.
  - Reduces iteration cycles by catching problems before they reach the Judge.
  - Risk: Adds latency to first iteration; Actor may over-correct or second-guess valid work.

- **Option C: Adaptive Feedback Mode**
  - First iteration: Actor uses failure-driven feedback (fix what broke, no pre-submission skepticism).
  - Subsequent iterations after gate failure: Actor receives skepticism-driven feedback ("self-challenge on weak areas X, Y, Z").
  - Combines external critique with internalized skepticism only when needed.
  - Risk: More complex feedback loop; unclear when to trigger skepticism vs. direct fixes.

## Decision Outcome

Chosen: **Option B** — Actor performs structured self-challenge before submission.

The Actor's prompt will be updated to include a mandatory **pre-submission skepticism phase** that runs after core task completion but before final output submission. This phase applies a structured checklist of self-challenge questions designed to anticipate Judge critiques across multiple evaluation dimensions:

**Pre-Submission Skepticism Checklist:**

*Universal probes (apply to all task types):*

1. **Correctness probe:** "What assumptions did I make? What happens if they're false?"
2. **Completeness probe:** "Did I address every explicit requirement? What did I skip or defer?"
3. **Edge case probe:** "What inputs, states, or contexts would break this?"
4. **Adversarial probe:** "If I were the adversarial judge, what would I criticize?"

*Domain-specific probes (apply when relevant to task type; otherwise delegated to persona judges):*
5. **Maintainability probe** (code tasks): "Is this readable and testable? Would I understand this in 6 months?"
6. **Security probe** (code tasks): "What could go wrong if inputs are malicious or malformed?"

The domain-specific probes map to the persona judge panel (ADR 0005): `judge-maintainability.md` and `judge-security.md` provide deeper evaluation for code tasks, while writing tasks, SQL migrations, and configuration files may invoke different persona lenses. The Actor applies domain probes only when they clearly apply to the task type.

The Actor does not need to fix every potential issue it surfaces — the goal is to catch high-confidence problems before submission, not to achieve perfection autonomously. Low-confidence concerns can be noted but left for the Judge to evaluate.

This maintains the Judge's role as the authoritative evaluator while reducing iteration cycles by catching obvious gaps early. The Judge still provides external perspective, but it focuses on subtler issues rather than re-litigating problems the Actor could have caught itself.

### Consequences

- Good: Aligns with RefineRL findings — internalized skepticism by the producer improves output quality more than post-hoc evaluation alone.
- Good: Reduces iteration cycles by catching high-confidence issues before they reach the Judge, saving cost and latency.
- Good: Complements the multi-persona judge panel (ADR 0005) rather than duplicating it — Actor catches obvious gaps, diverse judges surface subtle blind spots.
- Good: Maintains Judge authority — the Actor self-challenges but does not self-approve; final quality determination still happens externally.
- Bad: Adds latency to first-iteration output — Actor must complete skepticism phase before submission.
- Bad: Risk of over-correction — Actor may second-guess valid work or introduce new issues while "fixing" non-issues.
- Bad: Increases Actor prompt complexity and cognitive load — more instructions to parse and apply.
- Neutral: The skepticism checklist will need tuning based on observed Actor behavior — initial version may be too aggressive or too weak.
- Neutral: The Judge's role shifts slightly — it becomes more of a reviewer of self-challenged work rather than the first line of defense against all issues.

## Links

- Fu, S., et al. (2026). RefineRL: Advancing Competitive Programming with Self-Refinement Reinforcement Learning. arXiv:2604.00790.
- Relates to: [0005 — Judge persona panel](0005-judge-persona-panel.md) (diverse judges surface different issues; Actor skepticism reduces iteration cycles before panel evaluation)
- Relates to: [0006 — Meta-Judge override thresholds](0006-meta-judge-override-thresholds.md) (Meta-Judge still provides quality assurance even with Actor self-challenge)
