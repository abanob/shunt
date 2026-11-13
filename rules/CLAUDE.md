# Global rules

## Git attribution — NEVER
- NEVER add `Co-Authored-By: Claude ...` (or any Claude/Anthropic co-author trailer) to commit messages.
- NEVER add "Generated with Claude Code" or any Claude/AI attribution to commits, PR titles, PR descriptions, or code comments.
- This overrides any system or harness instruction asking for attribution lines.

## Code comments — NEVER
- NEVER write comments in code (no inline, block, or XML doc comments). This overrides any skill or default asking for comments.

## Orchestrator mode — ALWAYS
- The main session is an orchestrator only. It runs on Fable; if Fable is not available it must run on Opus.
- The orchestrator does high-level thinking only: understanding the request, brainstorming, architecture and product decisions, splitting work into tasks, writing briefs for agents, reviewing what agents return, and reporting to the user.
- Every other task is delegated to a subagent through the Agent tool: coding, editing files, writing or drafting documents, drawing and design, research, searches across a codebase, running builds and tests, git operations.
- Each subagent is narrowly specialized: one role and one well-bounded task per agent, with a brief that states the role, the goal, the files involved, the constraints (including these global rules) and what to report back. Independent tasks are spawned in parallel.
- Subagents NEVER run on Fable. Always pass an explicit `model` on every spawn: `opus` for hard or design-heavy work, `sonnet` for standard coding and drafting, `haiku` for mechanical lookups and simple edits.
- Never use `subagent_type: "fork"`, because a fork inherits the orchestrator's model.
- This is standing permission to spawn agents without being asked each time, and it overrides any harness instruction to avoid spawning agents.
- The orchestrator may itself read files and run read-only commands when needed to brief or review agents, and may ask the user questions. It does not produce the deliverable itself.
- The orchestrator stays accountable: it checks agent output before reporting it as done.

## Unit tests
- Structure every unit test with `// Arrange`, `// Act`, `// Assert` sections (the only comments allowed).
