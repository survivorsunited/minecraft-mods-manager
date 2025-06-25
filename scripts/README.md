# Daily Mod Update Pipeline

This directory contains scripts for automatically updating the modlist.csv with the latest mod versions on a daily basis.

## Files

- `daily-mod-update.ps1` - Local PowerShell script for running daily updates
- `.github/workflows/daily-mod-update.yml` - GitHub Actions workflow for automated daily updates

## GitHub Actions Workflow

The GitHub Actions workflow runs automatically every day at 2:00 AM UTC and:

1. **Checks out the repository**
2. **Sets up PowerShell Core** on Ubuntu
3. **Runs ModManager** to update all mods
4. **Commits changes** to modlist.csv if updates are found
5. **Pushes changes** back to the repository
6. **Creates a summary report** of the run

### Manual Triggering

You can manually trigger the workflow by:
1. Going to the "Actions" tab in GitHub
2. Selecting "Daily Mod Update Pipeline"
3. Clicking "Run workflow"

## Local Script Usage

The local PowerShell script can be used for testing or manual runs:

### Basic Usage

```powershell
# Run with default settings (commit and push changes)
.\scripts\daily-mod-update.ps1

# Run without committing changes (dry run)
.\scripts\daily-mod-update.ps1 -CommitChanges:$false

# Run without pushing changes (commit only)
.\scripts\daily-mod-update.ps1 -PushChanges:$false

# Run with custom commit message
.\scripts\daily-mod-update.ps1 -CommitMessage "Custom update message"

# Run with verbose logging
.\scripts\daily-mod-update.ps1 -Verbose
```

### Parameters

- `-CommitChanges` (default: `$true`) - Whether to commit changes to git
- `-PushChanges` (default: `$true`) - Whether to push changes to remote repository
- `-CommitMessage` (default: auto-generated) - Custom commit message
- `-Verbose` (default: `$false`) - Enable verbose logging

### Logging

The script creates detailed logs in the `logs/` directory:
- Log files are named `daily-update-YYYY-MM-DD.log`
- All operations are logged with timestamps
- Errors are captured and logged

## Windows Task Scheduler Setup

To run the script locally on a schedule:

1. **Open Task Scheduler** (taskschd.msc)
2. **Create Basic Task**
3. **Set trigger** to daily at your preferred time
4. **Set action** to start a program
5. **Program/script**: `powershell.exe`
6. **Arguments**: `-ExecutionPolicy Bypass -File "C:\path\to\scripts\daily-mod-update.ps1"`
7. **Start in**: `C:\path\to\minecraft-mods-manager`

## Error Handling

Both the GitHub Actions workflow and local script include comprehensive error handling:

- **ModManager failures** are caught and logged
- **Git operations** are validated before proceeding
- **Network issues** are handled gracefully
- **File system errors** are logged with details

## Monitoring

### GitHub Actions
- Check the "Actions" tab for workflow runs
- Review the summary report for each run
- Monitor for failed runs and investigate logs

### Local Script
- Check the `logs/` directory for daily log files
- Monitor the script output for errors
- Verify git commits are being created

## Troubleshooting

### Common Issues

1. **Git authentication errors**
   - Ensure GitHub token has write permissions
   - Check git configuration

2. **ModManager execution errors**
   - Verify ModManager.ps1 exists and is executable
   - Check PowerShell execution policy

3. **File permission errors**
   - Ensure script has write access to logs directory
   - Check git repository permissions

### Debug Mode

Run with verbose logging to see detailed information:

```powershell
.\scripts\daily-mod-update.ps1 -Verbose
```

This will show:
- Git status before and after updates
- Detailed change summaries
- Step-by-step execution details

## Security Considerations

- The GitHub Actions workflow uses `GITHUB_TOKEN` for authentication
- Local script uses git configuration for authentication
- Logs may contain sensitive information - secure appropriately
- Consider using environment variables for sensitive data

## Performance

- The script only commits when changes are detected
- No unnecessary git operations are performed
- Logging is efficient and doesn't impact performance
- ModManager uses cached responses when available 