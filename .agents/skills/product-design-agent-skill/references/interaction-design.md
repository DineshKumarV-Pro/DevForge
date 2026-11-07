# Interaction Quality

Use this guide to make actions discoverable, outcomes predictable, and mistakes recoverable.

## A practical interaction model

For every important task, inspect five layers:

### 1. Possibility

Can the user tell what actions are available?

### 2. Intention

Can the user connect the available action to their goal?

### 3. Execution

Can they perform the action without unnecessary friction?

### 4. System response

Does the product clearly show what happened?

### 5. Evaluation

Can the user tell whether the result matches what they wanted?

A failure at any layer is an interaction-design problem.

## Visible action cues

Interactive elements should communicate:

- that they are interactive,
- where to act,
- what action is possible,
- when the action is unavailable.

Avoid:

- uncommon icon-only actions without labels,
- hover-only controls for essential functions,
- gestures with no visible clue,
- static and interactive elements that look identical.

## Predictable mapping

Keep controls close to the objects they affect.

Group actions around user activities rather than backend subsystems.

Prefer labels that describe user outcomes instead of internal implementation.

## Put knowledge in the interface

Do not require memory when the product can display context.

Examples:

- keep selected filters visible,
- show the affected object beside a destructive action,
- reveal requirements before submission,
- preserve prior choices when useful,
- show relevant comparison attributes together,
- use examples and defaults where they reduce ambiguity.

## Constrain invalid states

Good constraints prevent errors before they happen.

Examples:

- prevent impossible date ranges,
- restrict invalid file types,
- stop duplicate submissions,
- provide structured choices when the domain is bounded,
- disable impossible actions with an explanation when appropriate,
- hide advanced controls until they are relevant.

Constraints should guide, not trap.

## Feedback

After an action, the product should answer:

- Did you receive my input?
- Is something happening?
- Did it succeed?
- What changed?
- What should I do next?
- If it failed, how do I recover?

Match feedback intensity to the importance of the event.

## Design for mistakes

Assume users will:

- click the wrong thing,
- forget,
- misunderstand,
- repeat an action,
- work while distracted,
- follow an outdated mental model.

Prefer this sequence:

1. Prevent invalid action.
2. Show consequences before high-cost actions.
3. Make actions reversible where feasible.
4. Preserve user work.
5. Provide clear recovery.
6. Use confirmations only when they add real protection.

Undo is often better than repeated confirmation.

## Problem-first design

Do not treat the initial feature request as the problem definition.

Ask:

- What is the user trying to accomplish?
- What evidence shows the problem exists?
- What is the current workaround?
- What is the root cause?
- Could the goal be met without adding another feature?

## Explore before converging

For significant design problems:

1. Explore the problem space broadly.
2. Narrow to the most important problem.
3. Generate multiple solution approaches.
4. Select a promising direction.
5. Prototype.
6. Test.
7. Iterate.

Do not jump directly from request to polished interface.

## Complexity

Complexity can be inherent. Confusion is optional.

A powerful expert product can still:

- organize around real activities,
- reveal advanced capability progressively,
- use stable language,
- preserve orientation,
- provide useful defaults,
- make frequent expert paths efficient.

## Feature-cost rule

Every additional feature increases:

- navigation burden,
- state complexity,
- testing surface,
- documentation needs,
- error opportunities,
- maintenance cost.

Before adding a feature, ask whether it should instead replace, merge with, automate, contextualize, or remove something.
