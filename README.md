# Dispel

Dispel is a macOS menu bar app that suppresses accidental trackpad clicks while you type.

## Scope

Use Dispel when you need:

- a menu bar app with no daemon and no root requirement
- a short post-keystroke click suppression window
- configurable trigger timing and blocked mouse phases
- a local-only implementation built on macOS Accessibility APIs

## Build

```bash
make build
```

## Verify

```bash
make verify
```

Common local targets:

- `make xcodegen`
- `make xcodegen-check`
- `make lint`
- `make test`
- `make build`

## Docs

Keep the README short. Detailed material lives elsewhere:

- [Contract and Architecture](docs/contracts.md)
- [Release Process](docs/release.md)
- [Agent Instructions](AGENTS.md)

## Runtime Notes

- requires Accessibility permission to intercept and suppress input events
- no network service, daemon, kernel extension, or root privilege is involved
- the primary tuning controls are delay, activation delay, trigger edge, and blocked mouse phases

## Safety

Dispel changes local input behavior. Favor conservative defaults and real interactive testing when changing event tap, timing, or permission flows.
