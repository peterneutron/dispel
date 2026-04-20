# AGENTS: Working Guide for `dispel`

This file is the source of truth for contributors and coding agents working in this repo.

## Scope

- repo: `dispel` only
- goal: ship a reliable local-only click-suppression app for macOS
- priority order:
  1. correct and predictable input behavior
  2. permission clarity and safety
  3. maintainable build and release flow

## Project Layout

- `Dispel/Dispel/`
  - app source and runtime logic
- `Dispel/DispelTests/`
  - unit tests
- `Dispel/DispelUITests/`
  - UI tests
- `Dispel/project.yml`
  - Xcode project source of truth
- `scripts/`
  - signing and project verification helpers

## Non-Negotiable Rules

- do not introduce a daemon or privileged helper without an explicit product decision
- keep input processing local-only
- do not weaken Accessibility permission messaging or failure handling
- prefer regeneration from `Dispel/project.yml` over opportunistic Xcode project edits
- timing and event-tap changes need real interactive testing, not just static review

## Build and Verification

Run from repo root:

- `make xcodegen-check`
- `make lint`
- `make test`
- `make build`
- `make verify`

## Editing Guidance

- event handling changes usually belong in `Dispel/Dispel/EventTapManager.swift`
- menu and status behavior changes usually belong in `Dispel/Dispel/StatusMenuController.swift`
- UI changes usually belong in `Dispel/Dispel/ContentView.swift`
- keep settings and runtime behavior aligned so permission-denied and disabled states stay legible

## Release Model

- trunk branch: `master`
- releases are tagged from `master`
- keep the repo releasable from trunk instead of maintaining a ceremonial long-lived `dev`
