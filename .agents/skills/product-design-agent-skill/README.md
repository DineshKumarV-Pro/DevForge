# Product Design Agent Skill

A portable Agent Skill for designing and reviewing digital products through usability, interaction quality, accessibility, trust, error recovery, research, and ethical repeat-value design.

This repository is independently written. It does not contain, redistribute, or reproduce any source books, book excerpts, diagrams, exercises, screenshots, cover art, or publisher assets.

## What it does

- Designs product flows from scratch
- Reviews screenshots, prototypes, dashboards, SaaS, websites, and mobile apps
- Improves onboarding, activation, forms, checkout, and settings
- Diagnoses navigation and information architecture
- Designs empty, loading, success, permission, error, and recovery states
- Reviews accessibility and trust issues
- Builds usability-test plans
- Prioritizes UX issues by severity and expected impact
- Improves repeat use without dark patterns
- Translates product requirements into user-centered interaction behavior

## Structure

```
product-design-agent-skill/
├── SKILL.md
├── README.md
├── LICENSE
├── NOTICE.md
├── CONTRIBUTING.md
└── references/
    ├── usability.md
    ├── interaction-design.md
    ├── behavior-design.md
    ├── research-and-testing.md
    ├── audit-checklists.md
    └── provenance.md
```

## Use anywhere

Copy this repository, or just the skill folder contents, into the skills location supported by your AI agent.

Examples:

```bash
~/.agents/skills/product-design-agent-skill/
```

or project-local:

```bash
.agents/skills/product-design-agent-skill/
```

If an agent has no native skill system, instruct it to read `SKILL.md` before product-design work.

The skill has no runtime or vendor-specific dependency.

## Example prompts

- "Audit this dashboard and prioritize the five UX problems most likely to hurt task completion."
- "Design onboarding that gets the user to first value before nonessential setup."
- "Review this checkout for ambiguity, error recovery, accessibility, and trust."
- "Redesign this settings page around user tasks rather than backend structure."
- "Our retention is weak. Determine whether a real recurring user need exists before suggesting engagement mechanics."
- "Create a usability test for this prototype and tell me exactly what to observe."

## Design stance

- Reduce unnecessary cognitive work.
- Make state and consequences visible.
- Keep user memory burden low.
- Design for mistakes and recovery.
- Treat accessibility as product quality.
- Tie engagement to user value rather than attention extraction.
- Validate important choices with observed behavior.

## Intellectual-property posture

This project contains independently written guidance and general product-design methods. It is not affiliated with or endorsed by any author or publisher listed in the bibliography.

See `references/provenance.md` and `NOTICE.md` for the repository's provenance and rights policy.
