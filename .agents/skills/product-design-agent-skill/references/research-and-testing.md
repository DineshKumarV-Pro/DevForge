# Research and Usability Testing

## Principle

Observed behavior is usually more useful for interaction design than predictions about what people say they would do.

Use interviews and concept research to understand needs, language, expectations, and attitudes. Use usability testing to see whether a design actually works.

## Lightweight usability test

Test early, including with rough prototypes.

### Prepare

Define:

- target task,
- starting context,
- success condition,
- risky assumptions,
- critical steps.

Representative users are preferable, but do not postpone all learning because ideal participants are unavailable.

### Run

Ask the participant to think aloud.

Do not:

- teach the interface,
- defend it,
- lead the participant,
- explain labels before they try them.

Observe:

- first action,
- hesitation,
- backtracking,
- misinterpretation,
- ignored content,
- accidental action,
- recovery,
- completion.

### Debrief

Ask:

- What did you expect?
- What surprised you?
- What did you think that label meant?
- What would you do next?
- What felt risky or unclear?

## Severity

### P0
Cannot complete the task, data loss, severe accessibility failure, security/privacy issue, or other critical harm.

### P1
Serious friction in the primary journey, repeated confusion, or major trust problem.

### P2
Recoverable friction or secondary-flow issue.

### P3
Polish, consistency, or optimization.

Fix the most severe repeated problems first.

## Behavioral analytics

Use analytics to find where to investigate, not to explain user intent on their own.

Useful measures include:

- task completion,
- time to value,
- drop-off by step,
- error rate,
- retry rate,
- search and refinement behavior,
- feature adoption,
- retention tied to value events,
- cancellation,
- undo,
- recovery.

Combine quantitative evidence with observed behavior.

## Experiment discipline

A useful test states:

- problem,
- hypothesis,
- change,
- primary metric,
- guardrail metrics,
- target segment,
- duration or sample requirement when known,
- decision rule.

Avoid optimizing a local metric that harms trust, accessibility, task completion, or long-term user value.

## Product critique protocol

1. Attempt the primary task without explanation.
2. Run a five-second comprehension check.
3. Check hierarchy and scanning.
4. Trace action to system response.
5. Force common error states.
6. Test narrow mobile width.
7. Test keyboard navigation when relevant.
8. Review permissions and destructive actions.
9. Review empty, loading, success, and failure states.
10. Attach a validation method to every major recommendation.
