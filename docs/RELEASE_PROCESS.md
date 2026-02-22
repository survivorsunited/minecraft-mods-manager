# Release Process Documentation

## Overview

This document describes the release process for the Minecraft Mods Manager modpack. The system uses a **tag-based release strategy** where:

- **Official Releases**: Only created when a Git tag is pushed (marked as stable releases)
- **Pre-Releases**: All automated releases from workflows are marked as pre-release

## Release Types

### 1. Official Releases (Tag-Based)

**Trigger**: When a Git tag matching the pattern `v*` or `release-*` is pushed to the repository.

**Characteristics**:
- Marked as **stable release** (not pre-release)
- Uses the tag name as the release name
- Includes all enabled modpack versions from `release-config.json`
- Full validation and server startup testing
- Published to GitHub Releases

**Workflow**: `.github/workflows/tag-release.yml`

**How to Create**:
```bash
# 1. Ensure all tests pass
git checkout main
git pull

# 2. Create and push a tag
git tag -a v1.0.0 -m "Release version 1.0.0"
git push origin v1.0.0

# The tag-release workflow will automatically:
# - Build all enabled versions
# - Validate server startup
# - Create GitHub Release with tag name
# - Mark as stable (not pre-release)
```

**Tag Naming Convention**:
- Use semantic versioning: `v1.0.0`, `v1.1.0`, `v2.0.0`
- Or date-based: `release-2025.11.18`
- Must start with `v` or `release-`

### 2. Pre-Releases (Automated)

**Triggers**:
1. **Daily Mod Update Pipeline** (`.github/workflows/daily-mod-update.yml`)
   - Runs daily at 2:00 AM UTC
   - Creates pre-release when mod updates are detected
   - Tag format: `release-YYYY.MM.DD-HHMMSS`

2. **Test Pipeline** (`.github/workflows/test.yml`)
   - Runs on push to `main`/`develop` branches
   - Creates test pre-release after successful test suite
   - Tag format: `test-release-{run_number}`

**Characteristics**:
- Marked as **pre-release** (unstable/development)
- Automatically generated
- May contain untested or experimental changes
- Useful for testing and validation

## Workflow Details

### Tag-Based Release Workflow

**File**: `.github/workflows/tag-release.yml`

**Trigger**:
```yaml
on:
  push:
    tags:
      - 'v*'
      - 'release-*'
```

**Process**:
1. Checkout code with submodules
2. Read enabled versions from `release-config.json`
3. For each enabled version:
   - Download mods and server files
   - Validate server startup
   - Generate hash.txt and README.md
   - Create modpack ZIP
4. Package all versions
5. Generate release notes
6. Create GitHub Release:
   - Tag: The pushed tag name
   - Name: Extracted from tag
   - **prerelease: false** (stable release)
   - Files: All modpack ZIPs + checksums

### Daily Mod Update Workflow

**File**: `.github/workflows/daily-mod-update.yml`

**Changes Required**:
- Set `prerelease: true` in the `publish-release` job
- Keep automatic tag generation for tracking
- Add note in release notes that this is a pre-release

**Current Behavior**:
- Creates timestamp-based tags: `release-YYYY.MM.DD-HHMMSS`
- Marks as stable release (needs change to pre-release)

**Updated Behavior**:
- Creates timestamp-based tags: `release-YYYY.MM.DD-HHMMSS`
- Marks as **pre-release** (development/testing)

**Next and Latest version packages**:
- After validating and updating the mod database, the pipeline refreshes **Next** and **Latest** version data only (`-UpdateNextOnly`, `-UpdateLatestOnly`) so Current stays unchanged.
- It then builds release packages for the **Next** and **Latest** game versions (from the database). If server validation passes for those versions, the packages are included in the same GitHub Release as `modpack-next-{version}.zip` and `modpack-latest-{version}.zip`. This lets you test and ship Next/Latest when they are valid without changing the main (Current) release.

**Why the daily run might not create a release**:
1. **No database changes (`has_updates=false`)**  
   The pipeline only runs **Create Release Packages** and **Publish Release** when `modlist.csv` has changed after validation (new mod versions, SyncLatestMinecraftVersion adding rows, etc.). If there are no changes, those jobs are skipped and no GitHub Release is created.  
   - **What to do:** Re-run the workflow from the Actions tab and check **"Force create all versions"** to build and publish anyway.
2. **Server validation failed for all enabled versions**  
   If every matrix version (from `release-config.json`) fails server startup, no artifacts are uploaded and the release may be empty or only include Next/Latest packages.  
   - **What to do:** Check the **Create Release Package for &lt;version&gt;** step logs for the failure (e.g. mod incompatibility, missing JAR).

In the Actions run, the **update-database** job summary now includes a **Release decision** section stating whether Create Release Packages will run and why.

### Test Pipeline Release

**File**: `.github/workflows/test.yml`

**Current Behavior**:
- Already marks releases as `prerelease: true` ✅
- Creates tags: `test-release-{run_number}`
- No changes needed

## Configuration

### Release Configuration File

**File**: `release-config.json`

```json
{
  "versions": [
    {
      "version": "1.21.5",
      "enabled": true
    },
    {
      "version": "1.21.8",
      "enabled": true
    }
  ]
}
```

This file controls which Minecraft versions are included in releases. Versions 1.21.10 and 1.21.11 are included as disabled entries; enable when ready for release.

### Database (modlist.csv) for release versions

For each Minecraft version you enable in `release-config.json`, the pipeline needs **server**, **launcher**, and optionally **installer** rows in `modlist.csv` so that release packages can download the correct server JAR and Fabric launcher (and installer) for that version.

**Current DB coverage (as of last review):**

| Type      | Versions in DB                    | Notes |
|-----------|-----------------------------------|-------|
| **Server**   | 1.21.5, 1.21.6, 1.21.7, 1.21.8, 1.21.9, 1.21.10 | Add **1.21.11** when Mojang publish the server JAR. |
| **Launcher** | 1.21.5, 1.21.6, 1.21.7, 1.21.8, 1.21.9, 1.21.10 | Add **1.21.11** when Fabric meta has loader for 1.21.11 (same pattern: `fabric-server-launcher-1.21.11`, URL from `https://meta.fabricmc.net/v2/versions/loader/1.21.11/...`). |
| **Installer**| 1.21.5, 1.21.6 only               | Fabric often uses one installer EXE for many versions. Add rows for **1.21.9, 1.21.10, 1.21.11** only if you need version-specific installer entries (e.g. for release packaging). |

When adding a new Minecraft version (e.g. 1.21.11): add a **server** row (Minecraft Server JAR from Mojang) and a **launcher** row (Fabric server launcher from Fabric meta). Add **installer** rows only if your workflow requires per-version installer entries.

## Release Artifacts

Each release includes:

1. **Modpack ZIP Files**: `modpack-{version}.zip`
   - Contains all mods (mandatory and optional)
   - Server JARs (Minecraft and Fabric)
   - Fabric installer (EXE and JAR)
   - `hash.txt` for file verification
   - `README.md` with mod list and instructions

2. **Checksums File**: `release-hashes.txt`
   - SHA256 hashes for all modpack ZIPs
   - Used for download verification

## Release Notes

### Tag-Based Releases

Release notes include:
- Release version (from tag)
- Included modpack versions
- Installation instructions
- Checksums for verification
- InertiaAntiCheat integration notes

### Pre-Releases

Pre-release notes include:
- Pre-release indicator
- Source workflow (Daily Update or Test)
- Included versions
- Warning that this is a development build

## Best Practices

### Creating Official Releases

1. **Before Tagging**:
   - Ensure all tests pass
   - Review recent changes
   - Verify mod compatibility
   - Check `release-config.json` has correct enabled versions

2. **Tagging**:
   - Use semantic versioning: `v1.0.0`, `v1.1.0`, `v2.0.0`
   - Include descriptive message: `git tag -a v1.0.0 -m "Initial stable release"`
   - Push tag: `git push origin v1.0.0`

3. **After Tagging**:
   - Monitor workflow execution
   - Verify release artifacts
   - Test downloaded modpacks
   - Announce release if needed

### Pre-Release Management

- Pre-releases are automatically created
- No manual intervention required
- Use for testing and validation
- Can be deleted if not needed (they're marked as pre-release)

## Workflow Comparison

| Feature | Tag Release | Daily Update | Test Release |
|---------|-------------|--------------|--------------|
| **Trigger** | Git tag push | Schedule/Manual | Push to main/develop |
| **Pre-Release** | ❌ No (stable) | ✅ Yes | ✅ Yes |
| **Tag Format** | `v*` or `release-*` | `release-YYYY.MM.DD-HHMMSS` | `test-release-{number}` |
| **Validation** | Full (server startup) | Full (server startup) | Full (test suite) |
| **Frequency** | Manual (on-demand) | Daily (if updates) | On every push |
| **Purpose** | Official stable release | Automated updates | Testing/CI |

## Migration Plan

### Phase 1: Create Tag Release Workflow
- [ ] Create `.github/workflows/tag-release.yml`
- [ ] Test with a test tag
- [ ] Verify stable release creation

### Phase 2: Update Daily Update Workflow
- [ ] Change `prerelease: false` to `prerelease: true`
- [ ] Update release notes to indicate pre-release
- [ ] Test workflow execution

### Phase 3: Documentation
- [ ] Update this document with final details
- [ ] Add release process to main README
- [ ] Create release checklist

### Phase 4: Cleanup
- [ ] Review existing releases
- [ ] Mark old automated releases as pre-release if needed
- [ ] Archive or delete unnecessary pre-releases

## Troubleshooting

### Tag Release Not Triggering

1. **Check tag format**: Must start with `v` or `release-`
2. **Verify workflow file**: Ensure `tag-release.yml` exists
3. **Check permissions**: Workflow needs `contents: write`
4. **Review workflow logs**: Check GitHub Actions for errors

### Pre-Release Still Marked as Stable

1. **Verify workflow file**: Check `prerelease: true` is set
2. **Check workflow version**: Ensure using latest workflow
3. **Review release creation**: Check GitHub Actions logs

### Release Artifacts Missing

1. **Check build logs**: Verify modpack creation succeeded
2. **Verify file paths**: Ensure ZIP files are in correct location
3. **Check file permissions**: Workflow needs write access

## Related Documentation

- [API Reference](API_REFERENCE.md)
- [Modlist CSV Columns](MODLIST_CSV_COLUMNS.md)
- [Latest Mods Testing](USECASE_LATEST_MODS_TESTING.md)

