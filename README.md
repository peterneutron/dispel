# Dispel

Menubar app for macOS that suppresses accidental tap‑to‑clicks while typing. It helps prevent the “cursor jumps while typing” problem caused by stray trackpad taps.

- macOS 15+ (Sequoia), Apple Silicon (arm64) only
- Accessibility permission required (no root, no daemons)
- Built with AppKit; lives in the menu bar (no Dock icon)

## Features
- Suppression delay slider: 0–1000 ms in 100 ms steps (0 = off)
- Advanced controls:
  - Activation delay (default 20 ms, range 0–100 ms in 10 ms steps)
  - Trigger on Key Down or Key Up (default Key Up)
  - Select which mouse phases to block: Mouse Down (default on), Mouse Up (default off)
- Recovers automatically if the system disables the event tap by timeout
- Low CPU overhead; immediate live changes

## Why this exists
Some users observe “ghost taps” while typing (often a palm grazing the trackpad), which can move the insertion point and cause text to jump. Dispel blocks clicks for a short window after keys are pressed to avoid those stray taps.

## Build & Signing

Prerequisites
- Xcode 16+
- Xcode command line tools (`xcode-select --install`) for the signing helper
- macOS 15+ on Apple Silicon

Workflow options
- Xcode: open `Dispel/Dispel.xcodeproj` and run the `Dispel` scheme.
- Makefile: pick the lane that matches the type of build you need (see below).

Make lanes
- `make build` – unsigned local build (default). Equivalent to running `make` with no target and produces `build/Dispel.app` with code signing disabled.
- `make devsigned` – development-signed build. Uses automatic signing with your Apple Development certificate and places the signed app in `build/Dispel.app`.
- `make archive` – distribution archive for maintainers. Creates `build/Dispel.xcarchive` using manual signing.
- `make export` – exports a notarizable `.app` from the most recent archive using `ExportOptions.plist`.
- `make package` – zips the `.app` into `build/Dispel.zip`.
- `make clean` – removes the entire `build/` directory.

Selecting a signing identity
- Set `SIGNING_IDENTITY="Apple Development: Your Name (TEAMID)"` when invoking `make devsigned` or `make archive` if you already know the identity you want.
- If `SIGNING_IDENTITY` is unset, the Makefile runs `scripts/select_signing_identity.sh`, which lists the valid code signing identities discovered via the `security` tool and prompts you to pick one.
- The helper script requires the Xcode command line tools and at least one Apple Development certificate in your login keychain.

Export options
- `make export` relies on `./ExportOptions.plist`. Adjust it if you need different export styles (e.g., Developer ID vs. App Store).

## Run and grant permission
1) Launch Dispel; an icon appears in the menu bar.
2) Open the menu and click “Grant Accessibility Permission…”.
3) In System Settings → Privacy & Security → Accessibility, enable Dispel. The status in the menu should show “Active” once permission is granted and suppression is on.

## Usage
- Set the suppression delay with the main slider. 200–300 ms is a good starting point; 0 ms disables suppression entirely.
- If Finder rename or other click‑to‑focus flows feel blocked, increase the Activation delay to 20–40 ms (Advanced).
- For maximum protection, set Trigger = Key Down and optionally block Mouse Up (Advanced), noting this can interfere a bit more with click‑to‑focus.

## Defaults
- Trigger: Key Up
- Block phases: Mouse Down (on), Mouse Up (off)
- Activation delay: 20 ms
- Suppression delay: set by your slider (default 200 ms on first run)

## Settings storage
- Uses UserDefaults (per-user). Keys:
  - `delayMs`, `activationDelayMs`, `trigger` ("keyDown"/"keyUp"), `blockMouseDown` (Bool), `blockMouseUp` (Bool)
- On a sandboxed build, values are stored under the app’s container preferences plist.

## Troubleshooting
- No effect on clicks: ensure Accessibility permission is ON; relaunch the app after enabling.
- Finder rename glitches: keep Trigger = Key Up and use Activation delay ~20–40 ms.
- Over‑blocking: reduce suppression delay, uncheck “Mouse Up”, or set Trigger = Key Up.
- Under‑blocking: increase suppression delay; reduce or zero Activation delay; consider Trigger = Key Down and block both phases.
- After sleep the app stops blocking: it should auto‑recover; if not, toggle suppression or relaunch the app.

## Security & Privacy
- Dispel requests Accessibility permission to observe/modify input events locally. It does not log keystrokes or send data anywhere.
- No network access required; no background daemons installed.

## Roadmap
- Start at login (via SMAppService) — optional
- One‑click presets (e.g., “Aggressive mode”)
- Experimental “trackpad‑only” filtering (best effort via IOKit)

## Acknowledgements
- Inspired by [TouchGuard](https://github.com/thesyntaxinator/TouchGuard).
- Google Gemini and OpenAI GPT families of models and all the labs involved making these possible 🙏
