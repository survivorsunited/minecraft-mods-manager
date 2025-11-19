# Release Process Implementation Plan

## Objective

Update the release process to use a tag-based strategy where:
- **Official releases** are only created when a Git tag is pushed (marked as stable)
- **All other releases** are marked as pre-release (automated workflows)

## Current State Analysis

### Existing Workflows

1. **`.github/workflows/daily-mod-update.yml`**
   - **Trigger**: Schedule (daily 2 AM UTC) + manual dispatch
   - **Current Behavior**: Creates releases with `prerelease: false` (stable)
   - **Tag Format**: `release-YYYY.MM.DD-HHMMSS`
   - **Issue**: Should be pre-release, not stable

2. **`.github/workflows/test.yml`**
   - **Trigger**: Push to main/develop + PRs
   - **Current Behavior**: Creates releases with `prerelease: true` ✅
   - **Tag Format**: `test-release-{run_number}`
   - **Status**: Already correct, no changes needed

### Missing Workflow

- **Tag-based release workflow**: Does not exist
- **Required**: New workflow to handle Git tag pushes

## Implementation Steps

### Step 1: Create Tag Release Workflow

**File**: `.github/workflows/tag-release.yml`

**Requirements**:
- Trigger on tag push matching `v*` or `release-*`
- Build all enabled versions from `release-config.json`
- Validate server startup for each version
- Generate modpack ZIPs with hash.txt and README.md
- Create GitHub Release with:
  - Tag name from pushed tag
  - `prerelease: false` (stable release)
  - All modpack ZIPs + checksums

**Key Features**:
- Extract version from tag (e.g., `v1.0.0` → `1.0.0`)
- Use tag name as release name
- Include comprehensive release notes
- Full validation before release

### Step 2: Update Daily Mod Update Workflow

**File**: `.github/workflows/daily-mod-update.yml`

**Changes Required**:
1. **Line 482**: Change `prerelease: false` → `prerelease: true`
2. **Release Notes**: Add pre-release indicator
3. **Documentation**: Update comments to indicate pre-release status

**Rationale**:
- Automated daily updates are development/testing
- Only tag-based releases should be marked as stable
- Pre-releases allow testing before official release

### Step 3: Verify Test Workflow

**File**: `.github/workflows/test.yml`

**Status**: Already correct
- Line 387: `prerelease: true` ✅
- No changes needed

### Step 4: Update Documentation

**Files**:
- `docs/RELEASE_PROCESS.md` (created)
- `README.md` (add release process section)

**Content**:
- Tag-based release process
- How to create official releases
- Pre-release explanation
- Workflow comparison table

## Detailed Implementation

### Tag Release Workflow Structure

```yaml
name: Tag-Based Release

on:
  push:
    tags:
      - 'v*'        # Semantic versioning: v1.0.0, v1.1.0
      - 'release-*' # Date-based: release-2025.11.18

jobs:
  create-release:
    runs-on: windows-latest
    steps:
      - Checkout with submodules
      - Read enabled versions from release-config.json
      - For each version:
        - Create release package
        - Validate server startup
      - Package all modpacks
      - Generate checksums
      - Create GitHub Release (prerelease: false)
```

### Daily Update Workflow Changes

**Before** (Line 482):
```yaml
prerelease: false
```

**After**:
```yaml
prerelease: true
```

**Release Notes Addition**:
Add at the top of release notes:
```markdown
> ⚠️ **PRE-RELEASE**: This is an automated development build.
> For stable releases, see tagged releases.
```

### Tag Naming Convention

**Semantic Versioning** (Recommended):
- `v1.0.0` - Major release
- `v1.1.0` - Minor release
- `v1.0.1` - Patch release

**Date-Based** (Alternative):
- `release-2025.11.18` - Date-based release

**Extraction Logic**:
- Remove `v` prefix if present
- Use tag name as-is for `release-*` tags
- Display in release name

## Testing Plan

### Test 1: Tag Release Workflow

1. **Create test tag**:
   ```bash
   git tag -a v0.1.0-test -m "Test tag release"
   git push origin v0.1.0-test
   ```

2. **Verify**:
   - Workflow triggers
   - All enabled versions built
   - Server validation passes
   - Release created with `prerelease: false`
   - Artifacts attached correctly

3. **Cleanup**:
   - Delete test tag: `git push origin --delete v0.1.0-test`
   - Delete test release on GitHub

### Test 2: Daily Update Pre-Release

1. **Trigger daily update workflow** (manual dispatch)
2. **Verify**:
   - Release created with `prerelease: true`
   - Release notes indicate pre-release
   - Tag format: `release-YYYY.MM.DD-HHMMSS`

### Test 3: Test Workflow (No Changes)

1. **Push to main branch**
2. **Verify**:
   - Test release still marked as `prerelease: true`
   - No regressions

## Rollout Strategy

### Phase 1: Preparation (Day 1)
- [x] Create documentation (`RELEASE_PROCESS.md`)
- [x] Create implementation plan (this document)
- [ ] Review with team/stakeholders

### Phase 2: Implementation (Day 2)
- [ ] Create `.github/workflows/tag-release.yml`
- [ ] Update `.github/workflows/daily-mod-update.yml`
- [ ] Test tag release workflow with test tag
- [ ] Test daily update workflow (manual trigger)

### Phase 3: Validation (Day 3)
- [ ] Verify tag release creates stable release
- [ ] Verify daily update creates pre-release
- [ ] Test with real tag (e.g., `v1.0.0`)
- [ ] Review release artifacts

### Phase 4: Documentation (Day 4)
- [ ] Update `README.md` with release process
- [ ] Add release checklist
- [ ] Document tag naming conventions
- [ ] Create troubleshooting guide

### Phase 5: Cleanup (Day 5)
- [ ] Review existing releases
- [ ] Mark old automated releases as pre-release (if needed)
- [ ] Archive unnecessary pre-releases
- [ ] Final validation

## Risk Mitigation

### Risk 1: Tag Release Workflow Fails

**Mitigation**:
- Test with non-production tag first
- Monitor workflow execution
- Have rollback plan (delete tag/release)

### Risk 2: Daily Update Still Creates Stable Releases

**Mitigation**:
- Verify `prerelease: true` in workflow file
- Test workflow before merging
- Check GitHub Actions logs

### Risk 3: Confusion About Release Types

**Mitigation**:
- Clear documentation
- Release notes indicate type
- Pre-release badge visible on GitHub

## Success Criteria

### Tag Release Workflow
- ✅ Triggers on tag push
- ✅ Creates stable release (`prerelease: false`)
- ✅ Includes all enabled versions
- ✅ Validates server startup
- ✅ Generates all artifacts

### Daily Update Workflow
- ✅ Creates pre-release (`prerelease: true`)
- ✅ Includes pre-release indicator in notes
- ✅ Maintains existing functionality

### Documentation
- ✅ Complete release process documented
- ✅ Tag naming conventions clear
- ✅ Troubleshooting guide available

## Post-Implementation

### Monitoring
- Monitor first few tag releases
- Verify pre-release status on daily updates
- Check release artifacts are correct

### Feedback
- Collect feedback from users
- Adjust process if needed
- Update documentation based on experience

### Maintenance
- Keep workflows up to date
- Review release process quarterly
- Update documentation as needed

## Related Files

- `.github/workflows/tag-release.yml` (to be created)
- `.github/workflows/daily-mod-update.yml` (to be updated)
- `.github/workflows/test.yml` (no changes)
- `docs/RELEASE_PROCESS.md` (created)
- `release-config.json` (reference)
- `README.md` (to be updated)

## Questions & Answers

**Q: What if I want to create a stable release from daily update?**
A: Create a Git tag from the commit that triggered the daily update, then push the tag to trigger the tag release workflow.

**Q: Can I delete pre-releases?**
A: Yes, pre-releases can be deleted from GitHub Releases if not needed.

**Q: What happens if tag release workflow fails?**
A: The release won't be created. Fix the issue and push the tag again, or delete the tag and create a new one.

**Q: How do I know which releases are stable?**
A: Stable releases are marked with `prerelease: false` and are created from Git tags. Pre-releases are marked with `prerelease: true` and are from automated workflows.

