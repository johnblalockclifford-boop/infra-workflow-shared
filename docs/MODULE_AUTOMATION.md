# Module Automation System

This repository uses an automated system for managing module versions and releases. The system automatically detects changes to modules, manages semantic versioning, and creates git tags for each module release.

## Overview

The automation consists of:
- **Python scripts** in the `scripts/` directory that handle all the logic
- **GitHub Actions workflow** that orchestrates the automation
- **Integration tests** to ensure reliability

## How It Works

### 1. Module Detection

The system automatically detects modules by scanning for `README.md` files under the `modules/` directory. Each directory containing a `README.md` is considered a module.

**Module Naming Convention:**
- Terraform modules: `t-<module-name>` (e.g., `t-vm`)
- Ansible modules: `a-<module-name>` (e.g., `a-infoblox`, `a-windows-postdeploy`)

**Current Modules:**
- `t-vm` - Azure VM creation module (Terraform)
- `a-infoblox` - Infoblox DNS management module (Ansible)
- `a-windows-postdeploy` - Windows post-deployment module (Ansible)

### 2. Workflow Process

#### When you create a PR:

1. **Automatic Analysis**: The system detects which modules have changes
2. **Version Calculation**: Suggests new versions (default: patch bump)
3. **PR Comment**: Posts a comment with current versions and suggested new versions
4. **Command Instructions**: Shows how to customize version bumps

#### When you want to customize versions:

Use these commands in PR comments:

```
.bumpver <module-name> <major|minor|patch>
.setver <module-name> v<major>.<minor>.<patch>
```

**Examples:**
```
.bumpver t-vm minor
.setver a-infoblox v2.0.0
.bumpver a-windows-postdeploy major
```

#### When the PR is merged:

1. **Tag Creation**: Creates git tags for each module with version changes
2. **Metadata Update**: Updates README.md files with new version information
3. **Changelog Generation**: Creates/updates CHANGELOG.md files for each module

### 3. Version Tags

Tags follow the format: `<module-name>.v<major>.<minor>.<patch>`

Examples:
- `t-vm.v1.2.3`
- `a-infoblox.v0.5.0`
- `a-windows-postdeploy.v2.1.0`

### 4. Module Metadata

Each module's README.md can contain metadata:

```markdown
<!-- MODULE_METADATA
name: vm
type: terraform
description: Azure VM creation module
current_version: 1.2.3
last_updated: 2025-01-15T10:30:00Z
-->

# VM Module
...
```

**Note**: The `current_version` is automatically updated by the system. Manual changes will be overwritten.

## Usage Examples

### Basic Workflow

1. **Create a branch** and make changes to one or more modules
2. **Create a PR** - the system will analyze changes and post a comment
3. **Optionally customize versions** using comment commands
4. **Merge the PR** - tags and metadata are automatically updated

### Version Command Examples

**Patch bump (default):**
```
# No command needed - patch bump is automatic
```

**Minor version bump:**
```
.bumpver t-vm minor
```

**Major version bump:**
```
.bumpver a-infoblox major
```

**Set specific version:**
```
.setver t-vm v2.0.0
```

**Multiple commands:**
```
.bumpver t-vm minor
.setver a-infoblox v1.5.0
.bumpver a-windows-postdeploy patch
```

### Sparse Checkout for Consumers

Other repositories can checkout individual modules using git sparse-checkout:

```bash
# Clone the repository
git clone https://github.com/Faith-Technologies/infra-workflow-shared.git
cd infra-workflow-shared

# Enable sparse checkout
git config core.sparseCheckout true

# Checkout specific module
echo "modules/terraform/vm/*" > .git/info/sparse-checkout
git read-tree -m -u HEAD

# Checkout specific version
git checkout t-vm.v1.2.3
```

## System Components

### Python Scripts

Located in `scripts/`:

- **`module_detector.py`** - Finds and analyzes modules
- **`version_manager.py`** - Handles semantic versioning and git tags
- **`comment_parser.py`** - Parses version commands from PR comments
- **`metadata_updater.py`** - Updates README.md metadata and changelogs
- **`workflow_orchestrator.py`** - Coordinates all automation tasks
- **`test_integration.py`** - Integration tests for all functionality

### GitHub Actions Workflow

Located in `.github/workflows/modules.yaml`:

- **`analyze-pr`** - Analyzes PR changes and posts comments
- **`process-comments`** - Processes version commands from comments
- **`create-tags`** - Creates tags and updates metadata when PR is merged

## Testing

Run the integration tests:

```bash
cd scripts
uv run pytest test_integration.py -v
```

## Troubleshooting

### Common Issues

**Module not detected:**
- Ensure the module directory contains a `README.md` file
- Check that the directory is under `modules/terraform/` or `modules/ansible/`

**Version commands not working:**
- Ensure commands start with `.bumpver` or `.setver`
- Check module names match exactly (case-sensitive)
- Verify the comment is on a pull request

**Tags not created:**
- Check that the PR was actually merged
- Verify there were changes in module directories
- Look at the GitHub Actions logs for errors

## Development

### Adding New Modules

1. Create a directory under `modules/terraform/` or `modules/ansible/`
2. Add a `README.md` file to the directory
3. Optionally add metadata block to the README
4. The system will automatically detect the new module

### Modifying the System

1. Make changes to Python scripts in `scripts/`
2. Run integration tests: `cd scripts && uv run pytest test_integration.py -v`
3. Test the workflow on a feature branch
4. Update documentation as needed

### Script Development

```bash
# Set up development environment
cd scripts
uv sync

# Run individual scripts
uv run python module_detector.py --help
uv run python version_manager.py --help
uv run python comment_parser.py --help

# Run tests
uv run pytest test_integration.py -v
```