# Test Coverage Gaps and TODOs

This document tracks missing or weakly covered areas in the current test suite, with concrete proposals for new tests. It focuses on integration/unit coverage in `test/tests` and critical release behaviors.

## High-priority (release and correctness)

- Net: HTTP retry/backoff wrapper (`Invoke-RestMethodWithRetry`)
  - Add unit tests to simulate HTTP 429 and 5xx errors.
  - Cases:
    - 429 with numeric Retry-After header (sleep matches header; succeeds on next attempt).
    - 429 with HTTP-date Retry-After header (sleep uses parsed delta; succeeds on next attempt).
    - 500 → exponential backoff (1s → 2s → 4s … capping at 30s); succeeds after N attempts.
    - Non-retriable 4xx (e.g., 404) throws immediately, no retries.
    - Respects existing headers and sets User-Agent when missing.
  - Acceptance: Wrapper returns value for retriable sequences; asserts attempt count and delay strategy via injected clock/sleep shim (or measure elapsed with small bounds); non-retriable throws.

- Release packaging: README/hash fallback content
  - 96 verifies existence but not content quality. Add checks:
    - README.md: Has version header, mandatory/optional sections, counts match files observed, includes server/installer notes when present.
    - hash.txt: Contains SHA256 lines for all jars in mods (including optional subfolder) and server jars at version root; stable formatting.
    - Idempotency: Running CreateRelease twice produces the same hash values and file list (no duplication, no drift).

- Release packaging: Multi-version matrix
  - Add a test that enables 2+ versions in a temporary `release-config.json` and asserts `releases/<ver>/...` created for each; modpack zips exist for each; README/hash present for each.

- Classification: Expected list alignment
  - Add test for `Get-ExpectedReleaseFiles.ps1` to assert:
    - "admin" group is treated as optional.
    - Server-only when client_side=unsupported OR explicit type in (server, launcher, installer).
    - No duplicates between mandatory/optional/server buckets.

- Installer handling
  - Add a focused test that ensures installer artifacts (e.g., Fabric installer) are not placed under `mods/` and land at the version root with server jars, matching `Copy-ModsToRelease` rules.

## Medium-priority (workflows and edge cases)

- Download resilience without API key
  - Add test that runs `-DownloadMods` with `-UseCachedResponses` and no CURSEFORGE_API_KEY; asserts success and no network call attempts beyond cached reads.

- Dependency resolution (Modrinth/CurseForge)
  - Expand tests to cover auto-resolution of required and optional dependencies at download time, including deep chains (A requires B, B requires C).
  - Ensure optional dependencies do not promote to mandatory unless configured.

- Server startup validations
  - Target minimal startup smoke tests per OS matrix using small, known-good mod sets; collect `server.log` and assert basic success markers, with generous timeouts and clean shutdown.

- Path normalization and cross-platform issues
  - Add tests to ensure Windows path separators and case-insensitive FS behaviors don’t break packaging or hashing; verify temp paths are correctly cleaned up.

- Release reproducibility
  - Given a fixed database and cached responses, `CreateRelease` should produce byte-for-byte identical modpack zips and hash.txt across runs. Add a reproducibility test that builds twice, compares hashes/zips.

## Low-priority (quality and tooling)

- CLI UX and parameter validation
  - Extend `11-ParameterValidation.ps1` for conflicting switches, missing required combos, and helpful error messages.

- Test framework utilities
  - Unit tests for utilities in `TestFramework.ps1`: output folders, logging, and summary aggregation with edge cases (no tests run, only failures, only skips).

- Documentation lints
  - Ensure generated README.md adheres to minimal template fields; add lint-like assertions (no placeholder tokens, has title, includes version).

## Candidate file additions

- `test/tests/98-TestHttpRetryWrapper.ps1` (unit tests for Invoke-RestMethodWithRetry)
- `test/tests/99-TestReleaseMultiVersion.ps1` (multi-version packaging)
- `test/tests/100-TestReleaseReproducibility.ps1` (idempotency)
- `test/tests/101-TestExpectedListAndAdminGroup.ps1` (expected files classification)
- `test/tests/102-TestInstallerPlacement.ps1` (installer jar placement)

## Notes

- Keep new tests fast and cache-friendly: prefer `-UseCachedResponses` and synthetic datasets.
- Avoid real network calls in CI; for the HTTP retry wrapper, simulate responses via throw-once script blocks or a minimal mock function.
- Where timing-sensitive, use small delays (InitialDelaySec=1) and upper-bound elapsed time assertions to keep CI under 10 minutes for the full suite.
