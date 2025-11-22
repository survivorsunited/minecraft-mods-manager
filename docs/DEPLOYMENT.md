# Server Deployment Guide

## Overview

This guide explains how to create a proper release and deploy the modpack to your Minecraft server.

## Release Process

### Step 1: Create a Tag-Based Release

Tag-based releases are **stable releases** that are ready for production deployment.

#### Prerequisites

1. **Ensure all tests pass**:
   ```bash
   # Check that tests are passing
   git checkout main
   git pull
   ```

2. **Verify release configuration**:
   - Check `release-config.json` has the correct enabled versions
   - Ensure all mods are compatible and tested

3. **Review recent changes**:
   - Check mod compatibility
   - Verify server validation has passed

#### Creating the Release Tag

```bash
# 1. Create an annotated tag with a descriptive message
git tag -a v1.0.0 -m "Stable release v1.0.0 - Ready for production"

# 2. Push the tag to trigger the release workflow
git push origin v1.0.0
```

**Tag Naming Options**:
- **Semantic versioning**: `v1.0.0`, `v1.1.0`, `v2.0.0`
- **Date-based**: `release-2025.11.19`

The tag must start with `v` or `release-` to trigger the workflow.

#### What Happens Next

The `tag-release.yml` workflow will automatically:

1. ✅ Checkout code with submodules
2. ✅ Build modpacks for all enabled versions in `release-config.json`
3. ✅ Download mods and server files
4. ✅ Validate server startup (ensures mods are compatible)
5. ✅ Generate `hash.txt` and `README.md` for each version
6. ✅ Create modpack ZIP files
7. ✅ Generate SHA256 checksums
8. ✅ Create GitHub Release (marked as **stable**, not pre-release)
9. ✅ Upload all artifacts to GitHub Releases

**Monitor the workflow**: Go to GitHub Actions → "Tag-Based Release" → Watch for completion

### Step 2: Download the Release

Once the workflow completes:

1. **Go to GitHub Releases**: https://github.com/YOUR_REPO/releases
2. **Find your release**: Look for the tag you created (e.g., `v1.0.0`)
3. **Download artifacts**:
   - `modpack-{version}.zip` - The complete modpack for each Minecraft version
   - `release-hashes.txt` - SHA256 checksums for verification
   - `README-{version}.md` - Installation and mod list for each version

**Example**:
- `modpack-1.21.8.zip` - Modpack for Minecraft 1.21.8
- `README-1.21.8.md` - Documentation for 1.21.8

### Step 3: Deploy to Server

#### Option A: Manual Deployment

1. **Download the modpack ZIP** for your server's Minecraft version

2. **Verify the download** (optional but recommended):
   ```bash
   # Check SHA256 checksum
   sha256sum modpack-1.21.8.zip
   # Compare with release-hashes.txt from GitHub
   ```

3. **Extract the modpack**:
   ```bash
   unzip modpack-1.21.8.zip -d /path/to/server/
   ```

4. **Copy files to server**:
   ```bash
   # Copy mods
   cp -r mods/* /path/to/server/mods/
   
   # Copy server JARs (if not already present)
   cp minecraft_server*.jar /path/to/server/
   cp fabric-server*.jar /path/to/server/
   
   # Copy Fabric installer (if needed)
   cp install/fabric-installer*.jar /path/to/server/
   
   # Copy config (if using InertiaAntiCheat)
   cp -r config/ /path/to/server/
   ```

5. **Configure InertiaAntiCheat** (if using):
   - Copy `config/InertiaAntiCheat/InertiaAntiCheat.toml` to your server
   - The config is already populated with mod hashes from the release

6. **Start the server**:
   ```bash
   java -Xmx4G -Xms4G -jar fabric-server-*.jar nogui
   ```

#### Option B: Automated Deployment (Recommended for Production)

You can add a deployment step to the workflow. Here's an example:

**Add to `.github/workflows/tag-release.yml`** (after the "Create GitHub Release" step):

```yaml
- name: Deploy to Server
  if: github.ref == 'refs/tags/v*'  # Only deploy stable releases
  shell: pwsh
  env:
    SERVER_HOST: ${{ secrets.SERVER_HOST }}
    SERVER_USER: ${{ secrets.SERVER_USER }}
    SERVER_PATH: ${{ secrets.SERVER_PATH }}
    SERVER_SSH_KEY: ${{ secrets.SERVER_SSH_KEY }}
  run: |
    # Install SSH key
    $sshKeyPath = "$env:RUNNER_TEMP/ssh_key"
    $env:SERVER_SSH_KEY | Out-File -FilePath $sshKeyPath -Encoding ASCII -NoNewline
    icacls $sshKeyPath /inheritance:r /grant "$env:USERNAME:R"
    
    # Deploy modpack
    $modpackFile = Get-ChildItem -Filter "modpack-*.zip" | Select-Object -First 1
    if ($modpackFile) {
      Write-Host "📦 Deploying $($modpackFile.Name) to server..." -ForegroundColor Cyan
      
      # Copy to server
      scp -i $sshKeyPath -o StrictHostKeyChecking=no $modpackFile.FullName ${SERVER_USER}@${SERVER_HOST}:${SERVER_PATH}/
      
      # Extract on server
      ssh -i $sshKeyPath -o StrictHostKeyChecking=no ${SERVER_USER}@${SERVER_HOST} "cd ${SERVER_PATH} && unzip -o $($modpackFile.Name) && rm $($modpackFile.Name)"
      
      Write-Host "✅ Deployment complete" -ForegroundColor Green
    }
```

**Required GitHub Secrets**:
- `SERVER_HOST` - Your server's hostname or IP
- `SERVER_USER` - SSH username
- `SERVER_PATH` - Path on server where modpack should be deployed
- `SERVER_SSH_KEY` - Private SSH key for authentication

## Release Contents

Each modpack ZIP contains:

```
modpack-{version}.zip
├── mods/
│   ├── [mandatory mods].jar
│   ├── optional/
│   │   └── [optional mods].jar
│   └── server/
│       └── [server-only mods].jar
├── config/
│   └── InertiaAntiCheat/
│       └── InertiaAntiCheat.toml  (pre-configured with mod hashes)
├── hash.txt                       (SHA256 hashes for all mods)
├── README.md                      (Complete mod list and instructions)
├── minecraft_server.{version}.jar
├── fabric-server-*.jar
└── install/
    ├── fabric-installer-*.exe
    └── fabric-installer-*.jar
```

## Verification

After deployment, verify:

1. **Server starts successfully**:
   ```bash
   # Check server logs for errors
   tail -f logs/latest.log
   ```

2. **Mods loaded correctly**:
   - Check server console for mod loading messages
   - Verify no compatibility errors

3. **InertiaAntiCheat validation** (if using):
   - Check that client validation is working
   - Verify mod hashes match

## Troubleshooting

### Release Not Created

1. **Check tag format**: Must start with `v` or `release-`
2. **Verify workflow exists**: Ensure `.github/workflows/tag-release.yml` is present
3. **Check permissions**: Workflow needs `contents: write` permission
4. **Review logs**: Check GitHub Actions for errors

### Deployment Fails

1. **Check SSH connectivity**: Test SSH connection manually
2. **Verify paths**: Ensure `SERVER_PATH` exists and is writable
3. **Check disk space**: Ensure server has enough space
4. **Review server logs**: Check for mod compatibility issues

### Mod Compatibility Issues

1. **Check release README**: Lists all included mods
2. **Review server logs**: Look for missing dependencies
3. **Verify mod versions**: Ensure all mods are compatible with Minecraft version
4. **Check InertiaAntiCheat config**: Ensure mod hashes are correct

## Best Practices

1. **Always test releases** before deploying to production
2. **Keep backups** of previous server state
3. **Monitor server logs** after deployment
4. **Use semantic versioning** for release tags
5. **Document changes** in release notes
6. **Verify checksums** before deploying

## Related Documentation

- [Release Process](RELEASE_PROCESS.md) - Detailed release workflow
- [API Reference](API_REFERENCE.md) - ModManager API documentation
- [Modlist CSV Columns](MODLIST_CSV_COLUMNS.md) - Database structure


