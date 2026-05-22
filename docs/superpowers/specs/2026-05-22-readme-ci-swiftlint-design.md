# Design — README enrichi + CI + SwiftLint

**Date:** 2026-05-22  
**Status:** Implemented

## Context

NotchBar is a Swift 6 / SPM-only macOS app with a clean codebase but no CI pipeline and a README that doesn't explain the architecture or contribution workflow. The goal is to make the project immediately understandable to a new developer and to enforce code quality automatically on every PR.

## Scope

| Deliverable | Purpose |
|---|---|
| `README.md` — Architecture, Getting Started, Contributing | New-dev onboarding and architectural context |
| `.github/workflows/ci.yml` | Automated lint → build → test on every PR and push to `main` |
| `.swiftlint.yml` | Code style enforcement calibrated for Swift 6 |

## Decisions

### CI pipeline structure

Three chained jobs (lint → build → test) on `macos-15`:

- **lint** runs first because it's fastest and catches issues before a full compile.
- **build** uses `swift build -c release` to validate the production build path.
- **test** depends on build passing; uses `DEVELOPER_DIR` pointing at Xcode.app to resolve XCTest.

Jobs do not share artifacts — each starts from a fresh checkout. Acceptable for a small project; caching can be added later if build times grow.

### SwiftLint configuration

Conservative opt-in rules (`force_unwrapping`, `sorted_imports`, `empty_count`, `prefer_self_type_over_type_of_self`) were selected to enforce meaningful patterns without generating noise on the existing codebase. The `todo` rule is disabled because TODOs are tracked in PRs and commits, not the linter. Warning thresholds (120 chars / line, 300 lines / file, 50 lines / function) are generous enough for current code and flag genuine outliers.

### README reorganisation

The existing "Building", "Running tests", and "Permissions" sections were merged into a unified "Getting Started" + "Development" pair. A new "Architecture" section documents the five-state snapshot model, the NSPanel choice, and the SPM-only stance — the decisions most likely to confuse a new contributor. A "Contributing" section formalises branch naming and commit conventions that were already implicitly followed.
