# Minecraft 1.21.11 release pipeline

This repo now has a dedicated validated release workflow for Minecraft `1.21.11`:

- Workflow: **Validated Minecraft 1.21.11 Release**
- File: `.github/workflows/release-12111.yml`
- Default target: `1.21.11`
- Java runtime: `25`

## What the workflow checks

The release is blocked unless all of these gates pass:

1. `release-config.json` contains the requested Minecraft version and it is enabled.
2. The configured Java requirement is satisfied by the CI Java runtime.
3. `modlist.csv` passes database linting.
4. GitHub release asset URLs are canonicalised correctly:
   - `ID` must be `owner/repo`.
   - `Url` must be the canonical repository URL.
   - `CurrentVersionUrl` must keep the exact release asset URL.
   - `Host` and `ApiSource` must be `github`.
5. Required server and Fabric launcher rows exist for the target Minecraft version.
6. Required mod rows exist for the target Minecraft version.
7. `ModManager.ps1 -CreateRelease -GameVersion <version>` succeeds.
8. Server startup validation passes.
9. The release folder contains:
   - non-empty `mods/` payload
   - `README.md`
   - `hash.txt`
   - at least one generated ZIP
   - Minecraft server JAR
   - Fabric server launcher JAR

## How to run it manually

Go to **Actions → Validated Minecraft 1.21.11 Release → Run workflow**.

Use:

- `game_version`: `1.21.11`
- `publish_release`: `true` to publish a GitHub Release after validation, or `false` to only build and upload the validated artifact.

## Local sanity commands

Run these before publishing when working locally:

```powershell
.\ModManager.ps1 -TestDatabase
.\ModManager.ps1 -ValidateAllModVersions -UpdateModList
.\ModManager.ps1 -CreateRelease -GameVersion "1.21.11"
```

A release is considered ready only when the database is coherent, required server and launcher rows exist, required mods resolve for the target version, downloads land in the correct folders, server validation passes, the release payload is non-empty, and hashes/readmes are generated.
