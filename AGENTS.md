# AGENTS.md

Instructions and guidelines for AI agents working in this repository.

## Engineering Rules & Discipline

This repository uses Matt Pocock's engineering skills:
- **TDD**: Write tests before implementation at agreed seams. Red -> Green -> Refactor.
- **Deep Modules**: Design shallow interfaces that hide deep complexity.
- **Domain Modeling**: Always refer to terms defined in [`CONTEXT.md`](CONTEXT.md).

## Agent skills

### Issue tracker
Tracked via local files and GitHub Issues. See `docs/agents/issue-tracker.md`.

### Domain docs
Single-context domain model in root `CONTEXT.md`. See `docs/agents/domain.md`.
