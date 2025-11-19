Param(
  [Parameter(Mandatory=$true)]
  [string]$Version
)

# Ensure we're on main branch
git checkout main
git pull

# Create and push tag (this will trigger tag-release.yml workflow)
Write-Host "Creating release tag: v$Version" -ForegroundColor Cyan
git tag -a "v$Version" -m "Release v$Version"
git push origin "v$Version"

Write-Host "✅ Tag v$Version pushed successfully" -ForegroundColor Green
Write-Host "The tag-release workflow will automatically create the GitHub Release" -ForegroundColor Yellow
