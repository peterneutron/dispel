# Release Process

This repo uses `master` as the trunk and tagged release branch.

## Branch Model

- land feature and fix commits on `master`
- tag releases from `master`
- avoid reviving a long-lived `dev` branch unless it materially improves day-to-day work

## Patch Release Checklist

1. Finalize the release candidate on `master`.
2. Verify from repo root:

   ```bash
   make verify
   ```

3. Run an unsigned local app build if you want a release sanity check:

   ```bash
   make build
   ```

4. Prepare concise release notes from the merged commits.
5. Tag the release on `master`:

   ```bash
   git tag vX.Y.Z
   ```

6. Push `master` and the new tag.

## Versioning Notes

- use semver tags on `master`
- patch releases may include additive UI and behavior changes
- if permission behavior or supported OS assumptions change, call that out in release notes
- release notes live in tags and hosting-platform releases, not `CHANGELOG.md`

## Tooling Expectations

- keep `README.md`, `docs/release.md`, and the actual branch model aligned
- if CI is added later, have it validate `master` and pull requests targeting `master`
