# Mod patch scripts

This folder contains local post-download patch scripts for known upstream mod issues.

Patch scripts are organised by mod and Minecraft target version:

```text
patches/mods/<mod-id>/<minecraft-version>/<patch-name>.ps1
```

Examples:

```text
patches/mods/furnace-recycle/1.21.11/fix-smelt-chain.ps1
patches/mods/gens-recipes-plus/1.21.11/remove-invalid-resource-paths.ps1
```

## What these patches are

A patch is a local fix-up applied after a mod jar is downloaded and before the server is started or validated.

These scripts do not change the upstream mod, Modrinth, CurseForge, GitHub releases, or the source repository for the mod. They only clean or rewrite the local downloaded copy used by this mod manager.

## Patch script contract

Each patch script should accept these parameters:

```powershell
param(
    [string]$DownloadRoot,
    [string]$TargetGameVersion,
    [string]$ModListPath
)
```

A patch script should:

- Check whether the target file exists.
- Do nothing if the file or bad resource is not present.
- Only modify the specific known-bad file/resource.
- Log exactly what it changed.

## Current patches

| Mod | Minecraft target | Patch | Reason |
| --- | --- | --- | --- |
| Furnace Recycle | 1.21.11 | fix-smelt-chain.ps1 | Rewrites the broken `smelt_chain.json` recipe as a valid chain smelting recipe instead of deleting it. |
| Gen's Recipes Plus | 1.21.11 | remove-invalid-resource-paths.ps1 | Removes JSON resources with invalid paths such as spaces in the resource filename. |
