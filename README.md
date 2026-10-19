# infra-workflow-shared

Runner container and shared modules

## Module Automation

This repository uses `.github/workflows/modules.yaml` plus scripts in `scripts/` to:
- Detect changed modules under `modules/`
- Suggest semantic version bumps
- Accept optional PR comment overrides (`.bumpver` / `.setver`)
- Create module tags when a PR is merged
- Update module metadata in each module `README.md`

Detailed design and troubleshooting are documented in `docs/MODULE_AUTOMATION.md`.

## Creating A New Module

1. Create a module directory under:
   - `modules/terraform/<module_name>/` or
   - `modules/ansible/<module_name>/`
2. Add module implementation files (`.tf`, role files, etc.).
3. Add a `README.md` in the module directory.

Important: `README.md` is required. Module discovery scans `modules/**/README.md`; modules without a `README.md` are not versioned by automation.

### Recommended README Metadata Block

Add this block near the top of the module `README.md`:

```markdown
<!-- MODULE_METADATA
name: <module_name>
type: terraform
description: <short description>
current_version: 0.0.0
-->
```

Notes:
- `current_version` is maintained by workflow automation after release.
- `type` should be `terraform` or `ansible`.

## Maintaining Existing Modules

1. Make changes within a module path under `modules/`.
2. Open a PR.
3. Review the automation comment for suggested version changes.
4. Optionally override version bumps with PR comment commands:
   - `.bumpver <module-name> patch|minor|major`
   - `.setver <module-name> v<major>.<minor>.<patch>`
5. Merge PR to trigger tag creation and metadata updates.

Tag format:
- `<module-name>.v<major>.<minor>.<patch>`

## Terraform Module Docs

Use `terraform-docs` to refresh Terraform module reference docs (for example `module-docs.md`).

Run:

```bash
terraform-docs markdown /path/to/module
```

Install:

```bash
curl -sSLo ./terraform-docs.tar.gz https://terraform-docs.io/dl/v0.19.0/terraform-docs-v0.19.0-$(uname)-amd64.tar.gz
tar -xzf terraform-docs.tar.gz
chmod +x terraform-docs
mv terraform-docs /some-dir-in-your-PATH/terraform-docs
```
