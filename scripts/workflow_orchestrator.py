#!/usr/bin/env python3
"""
Workflow Orchestrator

Main entry point for GitHub Actions workflow that coordinates all module automation tasks.
"""

import json
import argparse
from pathlib import Path
from typing import Any, Dict, List
from datetime import datetime

# Import our utility modules
from module_detector import ModuleDetector, ModuleInfo
from version_manager import VersionInfo, VersionManager
from comment_parser import CommentParser
from metadata_updater import MetadataUpdater, ModuleMetadata


class WorkflowOrchestrator:
  """Orchestrates the complete module automation workflow."""

  def __init__(self, repo_root: str = "."):
    self.repo_root = Path(repo_root).resolve()
    self.detector = ModuleDetector(repo_root)
    self.version_manager = VersionManager(repo_root)
    self.comment_parser = CommentParser()
    self.metadata_updater = MetadataUpdater(repo_root)

  def detect_changed_modules(self, changed_files: List[str]) -> List[ModuleInfo]:
    """
    Detect modules that have changes based on changed files.

    Args:
        changed_files: List of file paths that have been changed

    Returns:
        List of ModuleInfo objects for changed modules.
    """
    return self.detector.find_changed_modules(changed_files)

  def _normalize_modules_data(self, modules_data: Any) -> List[Dict[str, Any]]:
    """
    Normalize modules file content into a list of module dictionaries.

    Supports the following formats:
    - List of module dictionaries
    - Analysis object with `changed_modules`
    - Object map of module_name -> module dictionary
    """
    if isinstance(modules_data, list):
      return modules_data

    if isinstance(modules_data, dict):
      changed_modules = modules_data.get("changed_modules")
      if isinstance(changed_modules, list):
        return changed_modules

      modules_list = modules_data.get("modules")
      if isinstance(modules_list, list):
        return modules_list

      normalized_modules = []
      for module_name, module_data in modules_data.items():
        if isinstance(module_data, dict):
          module_entry = dict(module_data)
          module_entry.setdefault("name", module_name)
          normalized_modules.append(module_entry)

      if normalized_modules:
        return normalized_modules

    raise ValueError(
      "Unsupported modules file format. Expected a list of modules or an object "
      "containing 'changed_modules'."
    )

  @staticmethod
  def _derive_module_path(module_data: Dict[str, Any]) -> str:
    """Derive module path if omitted by using readme_path metadata."""
    module_path = module_data.get("path", "")
    if module_path:
      return module_path

    readme_path = module_data.get("readme_path", "")
    readme_parts = Path(readme_path).parts
    if len(readme_parts) >= 3 and readme_parts[0] == "modules":
      return "/".join(readme_parts[1:-1])

    return ""

  def build_module_info_map(self, modules_data: Any) -> Dict[str, ModuleInfo]:
    """Build a module name -> ModuleInfo mapping from workflow JSON payloads."""
    module_info = {}

    for module_data in self._normalize_modules_data(modules_data):
      if not isinstance(module_data, dict):
        raise ValueError("Each module entry must be a JSON object")

      module_name = module_data.get("name")
      if not module_name:
        raise ValueError("Each module entry must include a non-empty 'name' field")

      module_path = self._derive_module_path(module_data)
      module_type = module_data.get("type")
      if not module_type:
        module_root = module_path.split("/", 1)[0] if module_path else ""
        module_type = "ansible" if module_root == "ansible" else "terraform"

      readme_path = module_data.get("readme_path")
      if not readme_path and module_path:
        readme_path = f"modules/{module_path}/README.md"

      module_info[module_name] = ModuleInfo(
        name=module_name,
        path=module_path,
        type=module_type,
        description=module_data.get("description", f"{module_type.title()} module"),
        current_version=module_data.get("current_version", "0.0.0"),
        readme_path=readme_path or "",
      )

    return module_info

  def analyze_pr_changes(self, base_sha: str, head_sha: str) -> Dict:
    """
    Analyze PR changes and generate version information.

    Args:
        base_sha: Base commit SHA
        head_sha: Head commit SHA

    Returns:
        Dictionary with analysis results.
    """
    try:
      # Get changed files using git
      import subprocess

      result = subprocess.run(
        ["git", "diff", "--name-only", base_sha, head_sha],
        capture_output=True,
        text=True,
        cwd=self.repo_root,
      )

      if result.returncode != 0:
        raise Exception(f"Git diff failed: {result.stderr}")

      changed_files = [f.strip() for f in result.stdout.split("\n") if f.strip()]

      # Detect changed modules
      changed_modules = self.detect_changed_modules(changed_files)

      if not changed_modules:
        return {
          "changed_modules": [],
          "module_versions": {},
          "suggested_versions": {},
          "analysis_summary": "No modules detected with changes.",
        }

      # Get current versions for changed modules
      module_names = [module.name for module in changed_modules]
      current_versions = self.version_manager.get_all_module_versions(module_names)

      # Generate analysis summary
      analysis = {
        "changed_modules": [
          {
            "name": module.name,
            "path": module.path,
            "type": module.type,
            "description": module.description,
            "readme_path": module.readme_path,
          }
          for module in changed_modules
        ],
        "module_versions": {
          name: {
            "current_version": info.current_version,
            "suggested_version": info.suggested_version,
            "source": info.source,
          }
          for name, info in current_versions.items()
        },
        "analysis_summary": f"Found {len(changed_modules)} modules with changes.",
      }

      return analysis

    except Exception as e:
      return {
        "error": f"Failed to analyze PR changes: {str(e)}",
        "changed_modules": [],
        "module_versions": {},
        "analysis_summary": "Analysis failed.",
      }

  def generate_pr_comment(self, analysis: Dict) -> str:
    """
    Generate a PR comment with version information and instructions.

    Args:
        analysis: Analysis results from analyze_pr_changes

    Returns:
        Formatted comment string.
    """
    if "error" in analysis:
      return f"## ❌ Module Analysis Error\n\n{analysis['error']}"

    if not analysis["changed_modules"]:
      return "## 📦 Module Analysis\n\nNo modules detected with changes in this PR."

    comment = "## 📦 Module Versioning Analysis\n\n"
    comment += f"{analysis['analysis_summary']}\n\n"

    # Add module information
    for module in analysis["changed_modules"]:
      module_name = module["name"]
      version_info = analysis["module_versions"].get(module_name, {})

      comment += f"### 🔧 Module: `{module_name}`\n"
      comment += f"- **Type**: {module['type'].title()}\n"
      comment += f"- **Path**: `{module['path']}`\n"
      comment += f"- **Description**: {module['description']}\n"
      comment += (
        f"- **Current Version**: `{version_info.get('current_version', '0.0.0')}`\n"
      )
      comment += f"- **Suggested Version**: `{version_info.get('suggested_version', '0.0.1')}` (patch bump)\n\n"  # noqa: E501

    # Add command instructions
    comment += "## 🎛️ Version Control Commands\n\n"
    comment += (
      "You can customize the version bumps using these commands in a comment:\n\n"
    )

    comment += "### Bump Version Commands\n"
    for module in analysis["changed_modules"]:
      module_name = module["name"]
      comment += f"- `.bumpver {module_name} patch` (default)\n"
      comment += f"- `.bumpver {module_name} minor`\n"
      comment += f"- `.bumpver {module_name} major`\n"

    comment += "\n### Set Specific Version Commands\n"
    for module in analysis["changed_modules"]:
      module_name = module["name"]
      comment += f"- `.setver {module_name} v<major>.<minor>.<patch>`\n"

    comment += "\n### Notes\n"
    comment += "- Commands are case-insensitive\n"
    comment += "- Multiple commands can be used in a single comment\n"
    comment += (
      "- If no commands are provided, all modules will receive a patch version bump\n"
    )
    comment += "- Tags will be created when this PR is merged\n"

    return comment

  def process_pr_comments(self, comments: List[str], valid_modules: List[str]) -> Dict:
    """
    Process PR comments for version commands.

    Args:
        comments: List of comment body strings
        valid_modules: List of valid module names

    Returns:
        Dictionary with processed commands and any errors.
    """
    try:
      # Parse all comments
      commands = self.comment_parser.parse_multiple_comments(comments)

      # Validate commands
      valid_commands, errors = self.comment_parser.validate_commands(
        commands, valid_modules
      )

      # Convert to dictionary format
      command_dict = self.comment_parser.commands_to_dict(valid_commands)

      return {
        "commands": command_dict,
        "valid_commands": len(valid_commands),
        "total_commands": len(commands),
        "errors": errors,
        "summary": self.comment_parser.format_command_summary(valid_commands),
      }

    except Exception as e:
      return {
        "error": f"Failed to process comments: {str(e)}",
        "commands": {},
        "valid_commands": 0,
        "total_commands": 0,
        "errors": [],
        "summary": "Comment processing failed.",
      }

  def calculate_final_versions(self, analysis: Dict, commands: Dict) -> Dict[str, str]:
    """
    Combine PR analysis and version commands into the versions to release.

    Args:
        analysis: Analysis results from analyze_pr_changes
        commands: Processed commands from process_pr_comments

    Returns:
        Dictionary mapping module_name -> version.
    """
    module_versions = {
      name: VersionInfo(
        module_name=name,
        current_version=info.get("current_version", "0.0.0"),
        suggested_version=info.get("suggested_version", "0.0.1"),
        source=info.get("source", "git_tag"),
      )
      for name, info in analysis.get("module_versions", {}).items()
    }

    # JSON round-trips the (command_type, value) tuples as lists
    command_dict = {
      name: tuple(command) for name, command in commands.get("commands", {}).items()
    }
    module_versions = self.version_manager.apply_version_commands(
      module_versions, command_dict
    )

    final_versions = {}
    for module_data in analysis.get("changed_modules", []):
      module_name = module_data["name"]
      version_info = module_versions.get(module_name)
      final_versions[module_name] = (
        version_info.suggested_version if version_info else "0.0.1"
      )

    return final_versions

  def create_module_tags(
    self, final_versions: Dict[str, str], module_info: Dict[str, ModuleInfo]
  ) -> Dict[str, bool]:
    """
    Create git tags for module versions.

    Args:
        final_versions: Dictionary mapping module_name -> version
        module_info: Dictionary mapping module_name -> ModuleInfo

    Returns:
        Dictionary mapping module_name -> success_status
    """
    results = {}

    for module_name, version in final_versions.items():
      try:
        # Generate changelog
        module = module_info.get(module_name)
        if module:
          changelog = self.version_manager.get_changelog_since_tag(
            module_name, module.path
          )
          changelog_text = (
            "\n".join(f"- {msg}" for msg in changelog)
            if changelog
            else "- No specific changes logged"
          )  # noqa: E501
        else:
          changelog_text = "- No specific changes logged"

        # Create tag with changelog as message
        tag_message = (
          f"Release {module_name} version {version}\n\nChangelog:\n{changelog_text}"  # noqa: E501
        )

        success = self.version_manager.create_tag(module_name, version, tag_message)
        results[module_name] = success

      except Exception as e:
        print(f"Error creating tag for {module_name}: {e}")
        results[module_name] = False

    return results

  def update_module_metadata(
    self, final_versions: Dict[str, str], module_info: Dict[str, ModuleInfo]
  ) -> Dict[str, bool]:
    """
    Update README.md metadata for modules.

    Args:
        final_versions: Dictionary mapping module_name -> version
        module_info: Dictionary mapping module_name -> ModuleInfo

    Returns:
        Dictionary mapping module_name -> success_status
    """
    results = {}
    timestamp = datetime.now().isoformat()

    for module_name, version in final_versions.items():
      try:
        module = module_info.get(module_name)
        if not module:
          results[module_name] = False
          continue

        # Create metadata object
        metadata = ModuleMetadata(
          name=module_name,
          type=module.type,
          description=module.description,
          current_version=version,
          last_updated=timestamp,
        )

        # Update README.md
        readme_path = str(self.repo_root / module.readme_path)
        success = self.metadata_updater.update_readme_metadata(readme_path, metadata)
        results[module_name] = success

        # Create changelog entry
        if success:
          changelog = self.version_manager.get_changelog_since_tag(
            module_name, module.path
          )
          module_path = str(self.repo_root / "modules" / module.path)
          self.metadata_updater.create_changelog_entry(
            module_path, version, changelog, timestamp
          )

      except Exception as e:
        print(f"Error updating metadata for {module_name}: {e}")
        results[module_name] = False

    return results


def main():
  """CLI entry point for workflow orchestration."""
  parser = argparse.ArgumentParser(description="Orchestrate module automation workflow")
  parser.add_argument("--repo-root", default=".", help="Repository root directory")

  subparsers = parser.add_subparsers(dest="command", help="Available commands")

  # Analyze PR command
  analyze_parser = subparsers.add_parser("analyze-pr", help="Analyze PR changes")
  analyze_parser.add_argument("base_sha", help="Base commit SHA")
  analyze_parser.add_argument("head_sha", help="Head commit SHA")
  analyze_parser.add_argument("--output", help="Output file for analysis results")

  # Generate comment command
  comment_parser = subparsers.add_parser("generate-comment", help="Generate PR comment")
  comment_parser.add_argument("analysis_file", help="Analysis results file")
  comment_parser.add_argument("--output", help="Output file for comment text")

  # Process comments command
  process_parser = subparsers.add_parser("process-comments", help="Process PR comments")
  process_parser.add_argument("comments_file", help="File containing comment bodies")
  process_parser.add_argument("modules_file", help="File containing valid module names")
  process_parser.add_argument("--output", help="Output file for processed commands")

  # Calculate versions command
  versions_parser = subparsers.add_parser(
    "calculate-versions",
    help="Calculate final versions from analysis and commands",
  )
  versions_parser.add_argument("analysis_file", help="Analysis results file")
  versions_parser.add_argument("commands_file", help="Processed commands file")
  versions_parser.add_argument("--output", help="Output file for final versions")

  # Create tags command
  tags_parser = subparsers.add_parser("create-tags", help="Create module tags")
  tags_parser.add_argument("versions_file", help="File containing final versions")
  tags_parser.add_argument("modules_file", help="File containing module info")
  tags_parser.add_argument("--push", action="store_true", help="Push tags to remote")

  # Update metadata command
  metadata_parser = subparsers.add_parser(
    "update-metadata",
    help="Update module metadata",
  )
  metadata_parser.add_argument("versions_file", help="File containing final versions")
  metadata_parser.add_argument("modules_file", help="File containing module info")

  args = parser.parse_args()

  if not args.command:
    parser.print_help()
    return

  orchestrator = WorkflowOrchestrator(args.repo_root)

  if args.command == "analyze-pr":
    analysis = orchestrator.analyze_pr_changes(args.base_sha, args.head_sha)

    if args.output:
      with open(args.output, "w") as f:
        json.dump(analysis, f, indent=2)
    else:
      print(json.dumps(analysis, indent=2))

  elif args.command == "generate-comment":
    with open(args.analysis_file, "r") as f:
      analysis = json.load(f)

    comment = orchestrator.generate_pr_comment(analysis)

    if args.output:
      with open(args.output, "w") as f:
        f.write(comment)
    else:
      print(comment)

  elif args.command == "process-comments":
    with open(args.comments_file, "r") as f:
      comments = [line.strip() for line in f if line.strip()]

    with open(args.modules_file, "r") as f:
      modules = [line.strip() for line in f if line.strip()]

    result = orchestrator.process_pr_comments(comments, modules)

    if args.output:
      with open(args.output, "w") as f:
        json.dump(result, f, indent=2)
    else:
      print(json.dumps(result, indent=2))

  elif args.command == "calculate-versions":
    with open(args.analysis_file, "r") as f:
      analysis = json.load(f)

    with open(args.commands_file, "r") as f:
      commands = json.load(f)

    final_versions = orchestrator.calculate_final_versions(analysis, commands)

    if args.output:
      with open(args.output, "w") as f:
        json.dump(final_versions, f, indent=2)

    print("Final versions calculated:", final_versions)

  elif args.command == "create-tags":
    with open(args.versions_file, "r") as f:
      versions = json.load(f)

    with open(args.modules_file, "r") as f:
      modules_data = json.load(f)

    module_info = orchestrator.build_module_info_map(modules_data)

    results = orchestrator.create_module_tags(versions, module_info)

    if args.push:
      orchestrator.version_manager.push_tags()

    print("Tag creation results:")
    for module, success in results.items():
      status = "SUCCESS" if success else "FAILED"
      print(f"  {module}: {status}")

  elif args.command == "update-metadata":
    with open(args.versions_file, "r") as f:
      versions = json.load(f)

    with open(args.modules_file, "r") as f:
      modules_data = json.load(f)

    module_info = orchestrator.build_module_info_map(modules_data)

    results = orchestrator.update_module_metadata(versions, module_info)

    print("Metadata update results:")
    for module, success in results.items():
      status = "SUCCESS" if success else "FAILED"
      print(f"  {module}: {status}")


if __name__ == "__main__":
  main()
