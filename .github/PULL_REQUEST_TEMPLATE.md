## Summary

<!-- One or two sentences describing the change and why. -->

## Checklist

- [ ] `xcodegen generate` was run (`project.yml` is canonical; never edit `.xcodeproj` by hand)
- [ ] `./test/test.sh` is green (unit tests)
- [ ] `CheapSeek.app` line coverage is ≥ 95% (`./test/test.sh --coverage`)
- [ ] Any new user-facing string exists in all 17 `.lproj` files (and is not left in English)
- [ ] No new network calls, entitlements, or runtime dependencies in the app target
- [ ] `README.md` / `TESTING.md` updated when behavior or test coverage changed
