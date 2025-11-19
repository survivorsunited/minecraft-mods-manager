# Release Process Update - Summary

## What Was Done

### 1. Created Tag-Based Release Workflow

**File**: `.github/workflows/tag-release.yml`

**Purpose**: Creates official stable releases when a Git tag is pushed.

**Features**:
- Triggers on tags matching `v*` or `release-*`
- Builds all enabled versions from `release-config.json`
- Validates server startup for each version
- Creates GitHub Release with `prerelease: false` (stable)
- Includes all modpack ZIPs and checksums

**How to Use**:
```bash
# Create and push a tag
git tag -a v1.0.0 -m "Release version 1.0.0"
git push origin v1.0.0

# The workflow will automatically:
# - Build all enabled modpack versions
# - Validate server startup
# - Create a stable GitHub Release
```

### 2. Updated Daily Mod Update Workflow

**File**: `.github/workflows/daily-mod-update.yml`

**Changes**:
- **Line 482**: Changed `prerelease: false` → `prerelease: true`
- **Release Notes**: Added pre-release indicator at the top

**Result**:
- Daily automated releases are now marked as pre-release
- Release notes clearly indicate this is a development build
- Users are directed to tagged releases for stable versions

### 3. Test Workflow (No Changes)

**File**: `.github/workflows/test.yml`

**Status**: Already correct
- Already marks releases as `prerelease: true` ✅
- No changes needed

### 4. Documentation Created

**Files**:
- `docs/RELEASE_PROCESS.md` - Complete release process documentation
- `docs/RELEASE_PROCESS_IMPLEMENTATION_PLAN.md` - Detailed implementation plan
- `docs/RELEASE_PROCESS_SUMMARY.md` - This summary

## Release Types Comparison

| Feature | Tag Release | Daily Update | Test Release |
|---------|-------------|--------------|--------------|
| **Trigger** | Git tag push | Schedule/Manual | Push to main/develop |
| **Pre-Release** | ❌ No (stable) | ✅ Yes | ✅ Yes |
| **Tag Format** | `v*` or `release-*` | `release-YYYY.MM.DD-HHMMSS` | `test-release-{number}` |
| **Validation** | Full (server startup) | Full (server startup) | Full (test suite) |
| **Frequency** | Manual (on-demand) | Daily (if updates) | On every push |
| **Purpose** | Official stable release | Automated updates | Testing/CI |

## Next Steps

### For Users

1. **Creating Official Releases**:
   - Create a Git tag: `git tag -a v1.0.0 -m "Release version 1.0.0"`
   - Push the tag: `git push origin v1.0.0`
   - Monitor the workflow execution
   - Verify the release is created as stable (not pre-release)

2. **Understanding Pre-Releases**:
   - Daily updates create pre-releases automatically
   - Test releases are pre-releases
   - Pre-releases are for testing/development
   - Use tagged releases for production

### For Developers

1. **Testing**:
   - Test tag release workflow with a test tag
   - Verify daily update creates pre-release
   - Check release artifacts are correct

2. **Monitoring**:
   - Monitor first few tag releases
   - Verify pre-release status on daily updates
   - Check release notes are clear

## Files Modified

### Created
- `.github/workflows/tag-release.yml` - New tag-based release workflow
- `docs/RELEASE_PROCESS.md` - Release process documentation
- `docs/RELEASE_PROCESS_IMPLEMENTATION_PLAN.md` - Implementation plan
- `docs/RELEASE_PROCESS_SUMMARY.md` - This summary

### Updated
- `.github/workflows/daily-mod-update.yml` - Changed to pre-release

### Unchanged
- `.github/workflows/test.yml` - Already correct

## Validation

✅ All workflows pass linting
✅ Tag release workflow created
✅ Daily update workflow updated
✅ Documentation complete

## Testing Checklist

Before using in production:

- [ ] Test tag release workflow with test tag
- [ ] Verify stable release creation
- [ ] Test daily update workflow (manual trigger)
- [ ] Verify pre-release creation
- [ ] Check release artifacts
- [ ] Verify release notes
- [ ] Test with real tag (e.g., `v1.0.0`)

## Questions?

See `docs/RELEASE_PROCESS.md` for complete documentation.

