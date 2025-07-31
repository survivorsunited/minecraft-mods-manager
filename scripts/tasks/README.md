# GitHub Ticket Management Scripts

This directory contains PowerShell scripts for managing GitHub issues with proper backup creation, error handling, and workflow automation. These scripts implement the **MANDATORY** ticket management workflow defined in the project rules.

## Overview

The scripts provide a **safe, documented workflow** for reading and updating GitHub tickets with automatic backup creation and proper error handling. They follow the **CRITICAL RULES** defined in `.cursor/rules/gov-06-issues.mdc`.

### Key Features

- **Automatic Backup Creation**: Every operation creates timestamped backup files
- **Dual Backup System**: Both read and update backups for complete traceability
- **Error Handling**: Graceful error handling with detailed error reporting
- **GitHub CLI Integration**: Uses `gh` CLI for reliable GitHub operations
- **Metadata Preservation**: Maintains operation history and timestamps
- **Workflow Enforcement**: Enforces the mandatory 3-step ticket workflow

## Scripts

### 1. `Create-Ticket.ps1` - Create GitHub Tickets

**Purpose**: Create a new GitHub ticket with proper backup creation and error handling.

**Functionality**:
- Creates new GitHub tickets using GitHub CLI
- Creates **dual backup files** (pre-creation + post-creation)
- Validates GitHub CLI availability
- Returns structured result object with issue number
- Supports both inline body and body from file

**Parameters**:
- `-Title` (Required): GitHub issue title
- `-Body` (Optional): Issue body content
- `-BodyFile` (Optional): File containing issue body content
- `-Labels` (Optional): Comma-separated labels
- `-BackupDir` (Optional): Backup directory (default: `.tasks/`)
- `-OperationDetails` (Required): Description of the creation operation

**Example**:
```powershell
# Create ticket with inline body
.\Create-Ticket.ps1 -Title "Fix logging issues" -Body "Analysis shows multiple issues..." -Labels "bug,high-priority" -OperationDetails "Creating ticket for analysis findings"

# Create ticket from file
.\Create-Ticket.ps1 -Title "Feature request" -BodyFile "feature-description.md" -Labels "enhancement" -OperationDetails "Creating feature request"
```

**Output**:
- Creates `.tasks/issue-create-2024-01-15_143022-pre.md`
- Creates `.tasks/issue-123-2024-01-15_143022-created.md`
- Returns issue number and backup paths

### 2. `Read-Ticket.ps1` - Read GitHub Tickets

**Purpose**: Read a GitHub ticket and create backup files for safe review.

**Functionality**:
- Reads ticket content using GitHub CLI
- Creates **dual backup files** (read + update)
- Validates GitHub CLI availability
- Returns structured result object

**Parameters**:
- `-IssueNumber` (Required): GitHub issue number
- `-BackupDir` (Optional): Backup directory (default: `.tasks/`)

**Example**:
```powershell
# Read ticket #54 and create backups
.\Read-Ticket.ps1 -IssueNumber 54

# Read with custom backup directory
.\Read-Ticket.ps1 -IssueNumber 21 -BackupDir "backups"
```

**Output**:
- Creates `.tasks/issue-54-2024-01-15_143022-read.md`
- Creates `.tasks/issue-54-2024-01-15_143022-update.md`
- Returns ticket content and backup paths

### 3. `Update-Ticket.ps1` - Update GitHub Tickets

**Purpose**: Update GitHub tickets with proper backup creation and content preservation.

**Functionality**:
- Updates ticket title, body, labels, or state
- Creates backup before and after updates
- Preserves existing content when updating
- Strips metadata from backup files
- Validates all operations

**Parameters**:
- `-IssueNumber` (Required): GitHub issue number
- `-Title` (Optional): New title
- `-Body` (Optional): New body content
- `-BodyFile` (Optional): File containing new body content
- `-Labels` (Optional): Comma-separated labels
- `-State` (Optional): "open" or "closed"
- `-BackupDir` (Optional): Backup directory (default: `.tasks/`)
- `-OperationDetails` (Required): Description of the update operation

**Examples**:
```powershell
# Update ticket body
.\Update-Ticket.ps1 -IssueNumber 54 -Body "Updated content" -OperationDetails "Adding new requirements"

# Update from file
.\Update-Ticket.ps1 -IssueNumber 21 -BodyFile "update-content.md" -OperationDetails "Updating from file"

# Close ticket
.\Update-Ticket.ps1 -IssueNumber 33 -State "closed" -OperationDetails "Closing completed issue"

# Add labels
.\Update-Ticket.ps1 -IssueNumber 45 -Labels "bug,high-priority" -OperationDetails "Adding priority labels"
```

### 4. `Modify-Ticket.ps1` - Interactive Ticket Modification

**Purpose**: Modify GitHub tickets through an interactive editor workflow.

**Functionality**:
- Reads current ticket content
- Opens content in specified editor
- Waits for user modifications
- Updates ticket with modified content
- Creates comprehensive backups

**Parameters**:
- `-IssueNumber` (Required): GitHub issue number
- `-Editor` (Optional): Editor to use (default: "notepad")
- `-BackupDir` (Optional): Backup directory (default: `.tasks/`)
- `-OperationDetails` (Required): Description of the modification

**Examples**:
```powershell
# Modify with default editor (notepad)
.\Modify-Ticket.ps1 -IssueNumber 54 -OperationDetails "Adding new acceptance criteria"

# Modify with VS Code
.\Modify-Ticket.ps1 -IssueNumber 21 -Editor "code" -OperationDetails "Updating requirements"

# Modify with custom editor
.\Modify-Ticket.ps1 -IssueNumber 33 -Editor "vim" -OperationDetails "Fixing typos"
```

**Workflow**:
1. Reads current ticket content
2. Creates backup of original content
3. Opens temporary file in specified editor
4. Waits for user to save and close editor
5. Updates ticket with modified content
6. Creates backup of updated content

### 5. `Get-Ticket.ps1` - Unified Ticket Manager

**Purpose**: Wrapper script providing a clean interface for reading and updating tickets.

### 6. `Get-Next-Ticket.ps1` - Next Ticket Finder

**Purpose**: Automatically find the next ticket to work on with intelligent prioritization.

**Functionality**:
- Queries GitHub issues with automatic filtering
- Prioritizes issues by priority labels and creation date
- Filters by development phase and priority
- Optionally reads the next ticket automatically
- Returns structured result objects

**Parameters**:
- `-ReadTicket` (Optional): Automatically read the next ticket after finding it
- `-Priority` (Optional): Filter by priority label (high-priority, medium-priority, low-priority)
- `-Phase` (Optional): Filter by development phase (Phase 1, Phase 2, Phase 3, Phase 4)
- `-Limit` (Optional): Number of tickets to return (default: 1)
- `-BackupDir` (Optional): Backup directory (default: `.tasks/`)

**Examples**:
```powershell
# Get next highest priority ticket
.\Get-Next-Ticket.ps1

# Get and read next ticket
.\Get-Next-Ticket.ps1 -ReadTicket

# Get next high-priority ticket from Phase 2
.\Get-Next-Ticket.ps1 -Priority "high-priority" -Phase "Phase 2"

# Get next 5 tickets to work on
.\Get-Next-Ticket.ps1 -Limit 5

# Get next medium priority tickets
.\Get-Next-Ticket.ps1 -Priority "medium-priority" -Limit 3
```

**Functionality**:
- Single script for both read and update operations
- Validates parameters before execution
- Provides consistent error handling
- Delegates to appropriate underlying scripts

**Parameters**:
- `-IssueNumber` (Required): GitHub issue number
- `-Action` (Optional): "read" or "update" (default: "read")
- `-Title` (Optional): New title (for update)
- `-Body` (Optional): New body content (for update)
- `-BodyFile` (Optional): File containing new body (for update)
- `-Labels` (Optional): Comma-separated labels (for update)
- `-State` (Optional): "open" or "closed" (for update)
- `-BackupDir` (Optional): Backup directory (default: `.tasks/`)
- `-OperationDetails` (Optional): Description of operation (for update)

**Examples**:
```powershell
# Read ticket
.\Get-Ticket.ps1 -IssueNumber 54

# Update ticket body
.\Get-Ticket.ps1 -IssueNumber 54 -Action "update" -Body "Updated content" -OperationDetails "Adding new requirements"

# Close ticket
.\Get-Ticket.ps1 -IssueNumber 21 -Action "update" -State "closed" -OperationDetails "Closing completed issue"
```

## Mandatory Workflow

### 3-Step Process (CRITICAL RULE)

**Step 1: Read and Create Backup Files**
```powershell
$result = .\Read-Ticket.ps1 -IssueNumber X
# Creates: issue-X-timestamp-read.md and issue-X-timestamp-update.md
```

**Step 2: Modify the Update File**
```powershell
# Edit the update file directly
notepad .tasks\issue-X-timestamp-update.md
# Or use VS Code: code .tasks\issue-X-timestamp-update.md
```

**Step 3: Update Ticket Using Modified File**
```powershell
.\Update-Ticket.ps1 -IssueNumber X -BodyFile ".tasks\issue-X-timestamp-update.md" -OperationDetails "Description"
```

### Enforcement Rules

- **Always use Read-Ticket.ps1** before making any changes
- **Never overwrite entire ticket body** without reading it first
- **Preserve all existing content** and add new requirements
- **Use automated scripts** for all ticket operations
- **Always create backups** before any operation

## Backup System

### Backup File Structure

All backup files are created in the `.tasks/` directory (or custom backup directory) with the format:

```
issue-{number}-{timestamp}-{operation}.md
```

Example: `issue-54-2024-01-15_143022-read.md`

### Backup File Content

Each backup file contains:

```markdown
---
operation: read|update
timestamp: 2024-01-15_143022
issue_number: 54
operation_details: "Description of what was done"
---

# Full ticket content here
```

### Dual Backup System

**CRITICAL RULE**: Read-Ticket.ps1 creates **BOTH** read and update backup files immediately:

1. **Read Backup**: `issue-54-2024-01-15_143022-read.md`
   - Contains original ticket content
   - Used for reference and audit trail

2. **Update Backup**: `issue-54-2024-01-15_143022-update.md`
   - Contains same content as read backup
   - **Modified directly** for changes
   - Used by Update-Ticket.ps1

## Error Handling

### Common Errors

1. **GitHub CLI Not Found**
   - Error: "GitHub CLI (gh) not found"
   - Solution: Install GitHub CLI from https://cli.github.com/

2. **Issue Not Found**
   - Error: "Failed to read issue #X"
   - Solution: Verify issue number exists and is accessible

3. **Permission Denied**
   - Error: "Access denied" or "Forbidden"
   - Solution: Check GitHub permissions and authentication

4. **Backup Directory Issues**
   - Error: "Failed to create backup"
   - Solution: Check write permissions for backup directory

### Error Recovery

All scripts return structured result objects:

```powershell
$result = .\Read-Ticket.ps1 -IssueNumber 54
if ($result.Success) {
    Write-Host "Operation successful"
    Write-Host "Backup: $($result.BackupPath)"
} else {
    Write-Host "Error: $($result.Error)"
}
```

## Integration with Project Rules

These scripts implement the **MANDATORY** rules from `.cursor/rules/gov-06-issues.mdc`:

### Streamlined Ticket Workflow
- ✅ Use automated ticket management scripts for ALL operations
- ✅ Create proper backups before any changes
- ✅ Preserve existing content when updating
- ✅ Follow the 3-step process

### Dual Backup System
- ✅ Create both read and update backup files
- ✅ Include metadata and operation details
- ✅ Maintain unique timestamps
- ✅ Preserve full ticket content

### Issue Updates During Development
- ✅ Update acceptance criteria when requirements change
- ✅ Add test requirements for new acceptance criteria
- ✅ Update issue immediately when scope changes
- ✅ Reflect all changes in issue before committing code

## Usage Examples

### Complete Workflow Example

```powershell
# 1. Read ticket and create backups
$result = .\Read-Ticket.ps1 -IssueNumber 54

# 2. Modify the update file
notepad $result.UpdateBackupPath

# 3. Update ticket with modified content
.\Update-Ticket.ps1 -IssueNumber 54 -BodyFile $result.UpdateBackupPath -OperationDetails "Adding new requirements"
```

### Interactive Modification Example

```powershell
# Modify ticket through editor
.\Modify-Ticket.ps1 -IssueNumber 54 -Editor "code" -OperationDetails "Updating acceptance criteria"
```

### Batch Operations Example

```powershell
# Read multiple tickets
foreach ($issue in @(21, 22, 23)) {
    .\Read-Ticket.ps1 -IssueNumber $issue
}
```

## Requirements

- **PowerShell 5.1+** or **PowerShell Core 7.0+**
- **GitHub CLI (gh)** installed and authenticated
- **Write permissions** for backup directory
- **Internet connection** for GitHub API access

## Installation

1. **Install GitHub CLI**:
   ```powershell
   # Windows (using winget)
   winget install GitHub.cli
   
   # Or download from: https://cli.github.com/
   ```

2. **Authenticate GitHub CLI**:
   ```powershell
   gh auth login
   ```

3. **Verify Installation**:
   ```powershell
   gh --version
   ```

## Troubleshooting

### GitHub CLI Issues

```powershell
# Check GitHub CLI installation
gh --version

# Check authentication
gh auth status

# Re-authenticate if needed
gh auth login
```

### Permission Issues

```powershell
# Check backup directory permissions
Test-Path ".tasks"
Get-Acl ".tasks"

# Create backup directory if needed
New-Item -ItemType Directory -Path ".tasks" -Force
```

### Script Execution Issues

```powershell
# Check execution policy
Get-ExecutionPolicy

# Set execution policy if needed
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

## Best Practices

1. **Always use the 3-step workflow** for ticket modifications
2. **Create backups before any changes** to preserve history
3. **Use descriptive operation details** for audit trail
4. **Verify GitHub CLI authentication** before operations
5. **Check backup files** after operations for verification
6. **Use appropriate editors** for your workflow (VS Code, notepad, etc.)
7. **Keep backup directory organized** and regularly clean old backups

## File Structure

```
scripts/tasks/
├── README.md              # This documentation
├── Create-Ticket.ps1      # Create new tickets with backup creation
├── Read-Ticket.ps1        # Read tickets and create backups
├── Update-Ticket.ps1      # Update tickets with backup creation
├── Modify-Ticket.ps1      # Interactive ticket modification
├── Get-Ticket.ps1         # Unified ticket manager
└── Get-Next-Ticket.ps1    # Next ticket finder

.tasks/                    # Backup directory (created automatically)
├── issue-54-2024-01-15_143022-read.md
├── issue-54-2024-01-15_143022-update.md
└── ...
```

## Contributing

When modifying these scripts:

1. **Follow the existing patterns** and error handling
2. **Maintain backward compatibility** with existing workflows
3. **Update this documentation** for any new features
4. **Test thoroughly** with various GitHub scenarios
5. **Preserve the backup system** and metadata structure

## Support

For issues with these scripts:

1. Check the **Error Handling** section above
2. Verify **GitHub CLI** installation and authentication
3. Check **backup directory** permissions
4. Review **PowerShell execution policy**
5. Consult the **Project Rules** in `.cursor/rules/gov-06-issues.mdc` 