# Release Process

This repository has three different release-like paths. Only one of them is the proper public GitHub Release process.

## The proper GitHub Release process

A proper stable GitHub Release is created by pushing a Git tag that matches one of these patterns:

```text
v*
release-*
```

The tag triggers:

```text
.github/workflows/tag-release.yml
```

That workflow builds the enabled Minecraft versions from `release-config.json`, validates server startup, packages the modpack ZIP files, generates checksums and release notes, then publishes a stable GitHub Release.

## Current stable release target

The current public release target is controlled by `release-config.json`.

At the moment:

```text
current = 1.21.11
next    = 26.1.2
latest  = 26.2
```

Only `1.21.11` is enabled for stable release packaging. The 1.21.11 target requires Java 25 because C2ME's native math module requires it.

## Stable release command

Use a clean semantic tag for the public release:

```powershell
git checkout main
git pull

git status

git tag -a v1.21.11 -m "Minecraft 1.21.11 stable modpack release"
git push origin v1.21.11
```

After the tag is pushed, watch the **Tag-Based Release** workflow in GitHub Actions.

The workflow should publish a GitHub Release containing:

```text
modpack-*.zip
release-hashes.txt
README.md
```

## Recommended pre-flight before tagging

Run these locally before creating the tag:

```powershell
git checkout main
git pull

# Do not let a local env var force the wrong Java requirement.
Remove-Item Env:\JAVA_VERSION_MIN -ErrorAction SilentlyContinue

# Clean old test releases from GitHub first, if needed.
.\tools\Remove-TestReleases.ps1
.\tools\Remove-TestReleases.ps1 -Delete

# Refresh/repair metadata.
.\ModManager.ps1 -UpdateMods -Online

# Re-download and apply mod patches.
.\ModManager.ps1 -Download -ForceDownload -TargetVersion "1.21.11"

# Validate server startup.
.\ModManager.ps1 -StartServer -TargetVersion "1.21.11"

# Optional local package smoke test.
.\ModManager.ps1 -CreateRelease -GameVersion "1.21.11"
```

If those pass, tag and push.

## What local `-CreateRelease` does

This command:

```powershell
.\ModManager.ps1 -CreateRelease -GameVersion "1.21.11"
```

creates a local package under:

```text
releases/1.21.11
```

It does **not** publish a GitHub Release by itself. It is used by the GitHub Actions workflows as the build step.

## What the tag release workflow does

The tag workflow:

1. Checks out the tagged commit with submodules.
2. Reads enabled versions from `release-config.json`.
3. Runs `ModManager.ps1 -CreateRelease -GameVersion <version>` for each enabled version.
4. Refuses to publish if the package has zero mod files.
5. Creates `modpack-<version>.zip`.
6. Generates `release-hashes.txt`.
7. Generates release notes.
8. Publishes a stable GitHub Release with `prerelease: false`.

## Automated pre-releases

These are not the proper stable release path:

### Daily Mod Update workflow

```text
.github/workflows/daily-mod-update.yml
```

This runs on schedule or manually. It can publish automated development builds, but they are marked as pre-releases.

It only publishes when:

```text
modlist.csv changed
```

or when the workflow is manually run with:

```text
Force create all versions = true
```

### Test workflow

```text
.github/workflows/test.yml
```

This can create `test-release-*` pre-releases after successful test runs on `main`. These are test artifacts only and can be deleted before publishing a stable release.

Use:

```powershell
.\tools\Remove-TestReleases.ps1
.\tools\Remove-TestReleases.ps1 -Delete
```

## Mod patch policy

Local jar fix-ups live under:

```text
patches/mods/<mod-id>/<minecraft-version>/<patch-name>.ps1
```

For example:

```text
patches/mods/furnace-recycle/1.21.11/fix-smelt-chain.ps1
```

The patch runner applies these after download. This keeps release-specific mod fixes visible and version-scoped.

## Current known release patch

For 1.21.11, Furnace Recycle contains a broken `smelt_chain.json` recipe. The release patch removes only that recipe so the rest of the mod can load.

## Checklist for a proper stable GitHub Release

Before tagging:

- `release-config.json` has exactly the intended stable versions enabled.
- The tag release workflow uses Java 25 for 1.21.11 validation.
- `ModManager.ps1 -StartServer -TargetVersion "1.21.11"` passes locally.
- Test releases have been cleaned from GitHub Releases if required.
- `git status` is clean.

Then create and push the tag:

```powershell
git tag -a v1.21.11 -m "Minecraft 1.21.11 stable modpack release"
git push origin v1.21.11
```

After tagging:

- Watch the **Tag-Based Release** workflow.
- Confirm the GitHub Release is not marked as a pre-release.
- Confirm `modpack-1.21.11.zip`, `release-hashes.txt`, and `README.md` are attached.
- Download the ZIP and sanity-check the contents.
