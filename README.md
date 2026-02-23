# Dispel

Dispel is a macOS menu bar app that reduces accidental trackpad clicks while typing.

It works by briefly suppressing mouse click events after keyboard activity, which helps prevent cursor jumps caused by stray taps or palm contact.

## Highlights

- Menu bar app (no Dock icon)
- Adjustable suppression delay (`0-1000 ms`)
- Inline `Enable` toggle for quick on/off control
- Advanced options:
  - Activation delay
  - Trigger on key down / key up
  - Block mouse down and/or mouse up
  - Run at Login
- No daemon, no kernel extension, no root privileges
- Local-only processing (uses macOS Accessibility APIs)

## Requirements

- macOS 15+ (Sequoia)
- Apple Silicon (arm64)
- Accessibility permission (required to intercept input events)

## Install / Run

### Option 1: Xcode (recommended for development)

1. Open `Dispel/Dispel.xcodeproj`
2. Run the `Dispel` scheme
3. Grant Accessibility permission when prompted

### Option 2: Makefile

Prerequisites:
- Xcode 16+
- Xcode command line tools (`xcode-select --install`)
- `xcodegen` (for regenerating/verifying the project)

Common targets:
- `make build` (or just `make`) - unsigned local build at `build/Dispel.app`
- `make devsigned` - development-signed build
- `make test` - unit tests (`DispelTests`)
- `make lint` - SwiftLint checks
- `make verify` - xcodegen check + lint + build + tests
- `make xcodegen` - regenerate `Dispel.xcodeproj` from `Dispel/project.yml`
- `make xcodegen-check` - verify the checked-in project is in sync

Packaging / release targets:
- `make archive`
- `make export`
- `make package`

## First Launch

1. Launch Dispel
2. Click the menu bar icon
3. Click `Grant Accessibility Permission…`
4. Enable Dispel in:
   `System Settings -> Privacy & Security -> Accessibility`

The menu status should switch to `Active` when permission is granted and suppression is enabled.

## Usage

### Basic control

- Use the `Delay` slider to set the suppression window
- Use the `Enable` checkbox (right side of the Delay row) to turn suppression on/off without changing your saved delay

### Advanced options

- `Activation delay`: wait before suppression begins (helps click-to-focus flows)
- `Trigger`: choose `On Key Down` or `On Key Up`
- `Block Phases`: choose whether to block mouse down and/or mouse up
- `Run at Login`: starts Dispel automatically when you log in

## Tuning Tips

- Good starting point: `200-300 ms`
- If Finder rename or click-to-focus feels blocked:
  - Keep trigger on `Key Up`
  - Increase activation delay to `20-40 ms`
- If under-blocking persists:
  - Increase delay
  - Reduce activation delay
  - Try trigger on `Key Down`
  - Optionally block both mouse phases

## Privacy & Security

- Dispel uses Accessibility permission to observe and filter input events locally
- It does not send input data anywhere
- No network service or background daemon is required

## Project Layout

- `Dispel/` - app source + Xcode project + `project.yml`
- `scripts/` - signing and xcodegen helper scripts
- `Makefile` - local build/test/release workflows

## Contributing

If you modify project structure or build settings, regenerate the Xcode project and commit the result:

```bash
make xcodegen
make xcodegen-check
```

## Acknowledgements

- Inspired by [TouchGuard](https://github.com/thesyntaxinator/TouchGuard)
