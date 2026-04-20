# Contract and Architecture

This document holds the durable architecture and runtime constraints for `dispel`.

## Architecture

Dispel is a single macOS menu bar app. It relies on an Accessibility-backed event tap to suppress accidental mouse click events after keyboard activity.

High-value code areas:

- `Dispel/Dispel/DispelApp.swift`
  - app entry and lifecycle
- `Dispel/Dispel/StatusMenuController.swift`
  - menu bar status item and menu interactions
- `Dispel/Dispel/EventTapManager.swift`
  - keyboard and mouse event interception logic
- `Dispel/Dispel/ContentView.swift`
  - settings UI
- `Dispel/Dispel/AppDelegate.swift`
  - app wiring outside the SwiftUI surface

## Product Model

Durable user-facing capabilities:

- enable and disable suppression from the menu bar
- adjustable suppression delay
- configurable activation delay
- configurable trigger edge: key down or key up
- configurable blocked phases: mouse down and mouse up
- Run at Login integration

## Non-Negotiable Runtime Rules

- Accessibility permission is required for the core product path
- input handling remains local-only
- no daemon, kernel extension, or root-only helper should be introduced casually
- timing changes should preserve common click-to-focus and rename flows as much as possible

## Build and Tooling

Prerequisites:

- macOS
- Xcode
- Xcode command line tools
- XcodeGen
- SwiftLint for lint and verify paths

Primary commands:

- `make build`
- `make test`
- `make lint`
- `make verify`
- `make xcodegen-check`

## Generated File Policy

Treat the Xcode project as generated from `Dispel/project.yml`.

Sources of truth:

- `Dispel/project.yml`
- `scripts/xcodegen-check.sh`

Expected generated artifact:

- `Dispel/Dispel.xcodeproj`

If project structure changes, regenerate instead of editing the project file by hand unless there is a specific reason not to.

## Release Shape

- semver tags are cut from `master`
- release notes belong in git hosting releases and tags, not an in-repo changelog
