#!/usr/bin/env python3
"""
Version Management Utility

Handles semantic versioning operations and git tag management for modules.
"""

import re
from pathlib import Path
from typing import Dict, List, Tuple
from dataclasses import dataclass
import semver
import git
from git import Repo


@dataclass
class VersionInfo:
  """Information about a module version."""

  module_name: str
  current_version: str
  suggested_version: str
  source: str  # 'git_tag', 'metadata', 'default'


class VersionManager:
  """Manages semantic versioning and git operations for modules."""

  def __init__(self, repo_root: str = "."):
    self.repo_root = Path(repo_root).resolve()
    try:
      self.repo = Repo(self.repo_root)
    except git.InvalidGitRepositoryError as err:
      raise ValueError(f"Not a git repository: {repo_root}") from err

  def get_current_version(self, module_name: str) -> str:
    """
    Get the current version for a module from git tags.

    Args:
        module_name: Name of the module (e.g., 't-vm', 'a-infoblox')

    Returns:
        Current version string, or '0.0.0' if no tags found.
    """
    try:
      # Get all tags for this module
      tags = [
        tag.name for tag in self.repo.tags if tag.name.startswith(f"{module_name}.v")
      ]

      if not tags:
        return "0.0.0"

      # Extract version numbers and sort
      versions = []
      for tag in tags:
        version_match = re.match(rf"{re.escape(module_name)}\.v(.+)", tag)
        if version_match:
          version_str = version_match.group(1)
          try:
            # Validate and normalize version
            version = semver.VersionInfo.parse(version_str)
            versions.append(version)
          except ValueError:
            print(f"Warning: Invalid version tag {tag}")
            continue

      if not versions:
        return "0.0.0"

      # Return the latest version
      latest_version = max(versions)
      return str(latest_version)

    except Exception as e:
      print(f"Error getting version for {module_name}: {e}")
      return "0.0.0"

  def get_all_module_versions(self, module_names: List[str]) -> Dict[str, VersionInfo]:
    """
    Get current versions for multiple modules.

    Args:
        module_names: List of module names

    Returns:
        Dictionary mapping module names to VersionInfo objects.
    """
    versions = {}

    for module_name in module_names:
      current_version = self.get_current_version(module_name)
      suggested_version = self.bump_version(current_version, "patch")

      versions[module_name] = VersionInfo(
        module_name=module_name,
        current_version=current_version,
        suggested_version=suggested_version,
        source="git_tag",
      )

    return versions

  def bump_version(self, version: str, bump_type: str) -> str:
    """
    Bump a version according to semantic versioning rules.

    Args:
        version: Current version string
        bump_type: Type of bump ('major', 'minor', 'patch')

    Returns:
        New version string.
    """
    try:
      ver = semver.VersionInfo.parse(version)

      if bump_type == "major":
        new_ver = ver.bump_major()
      elif bump_type == "minor":
        new_ver = ver.bump_minor()
      elif bump_type == "patch":
        new_ver = ver.bump_patch()
      else:
        raise ValueError(f"Invalid bump type: {bump_type}")

      return str(new_ver)

    except ValueError as e:
      print(f"Error bumping version {version}: {e}")
      # Fallback to simple increment
      if bump_type == "patch":
        return "0.0.1"
      elif bump_type == "minor":
        return "0.1.0"
      else:
        return "1.0.0"

  def validate_version(self, version: str) -> bool:
    """
    Validate that a version string is valid semantic version.

    Args:
        version: Version string to validate

    Returns:
        True if valid, False otherwise.
    """
    try:
      semver.VersionInfo.parse(version)
      return True
    except ValueError:
      return False

  def create_tag(self, module_name: str, version: str, message: str | None = None) -> bool:
    """
    Create a git tag for a module version.

    Args:
        module_name: Name of the module
        version: Version string
        message: Optional tag message

    Returns:
        True if successful, False otherwise.
    """
    tag_name = ""
    try:
      # Ensure version is valid
      if not self.validate_version(version):
        print(f"Invalid version: {version}")
        return False

      tag_name = f"{module_name}.v{version}"

      # Check if tag already exists
      if tag_name in [tag.name for tag in self.repo.tags]:
        print(f"Tag {tag_name} already exists")
        return False

      # Create tag
      if message is None:
        message = f"Release {module_name} version {version}"

      self.repo.create_tag(tag_name, message=message)
      print(f"Created tag: {tag_name}")
      return True

    except Exception as e:
      print(f"Error creating tag {tag_name}: {e}")
      return False

  def push_tags(self, remote_name: str = "origin") -> bool:
    """
    Push all tags to remote repository.

    Args:
        remote_name: Name of the remote to push to

    Returns:
        True if successful, False otherwise.
    """
    try:
      remote = self.repo.remote(remote_name)
      remote.push(tags=True)
      print(f"Pushed tags to {remote_name}")
      return True
    except Exception as e:
      print(f"Error pushing tags: {e}")
      return False

  def get_changelog_since_tag(
    self, module_name: str, module_path: str, since_tag: str | None = None
  ) -> List[str]:
    """
    Get commit messages for a module since a specific tag.

    Args:
        module_name: Name of the module
        module_path: Path to the module directory
        since_tag: Tag to compare from (if None, uses latest tag)

    Returns:
        List of commit messages.
    """
    try:
      if since_tag is None:
        # Find the latest tag for this module
        current_version = self.get_current_version(module_name)
        if current_version == "0.0.0":
          since_tag = None
        else:
          since_tag = f"{module_name}.v{current_version}"

      # Get commits affecting the module path
      if since_tag:
        commit_range = f"{since_tag}..HEAD"
      else:
        commit_range = "HEAD"

      commits = list(
        self.repo.iter_commits(rev=commit_range, paths=f"modules/{module_path}")
      )

      # Extract commit messages
      messages = []
      for commit in commits:
        # Skip merge commits
        if len(commit.parents) > 1:
          continue

        message = str(commit.message).strip().split("\n")[0]
        if message and message not in messages:
          messages.append(message)

      return messages

    except Exception as e:
      print(f"Error getting changelog for {module_name}: {e}")
      return []

  def apply_version_commands(
    self, module_versions: Dict[str, VersionInfo], commands: Dict[str, Tuple[str, str]]
  ) -> Dict[str, VersionInfo]:
    """
    Apply version commands to module versions.

    Args:
        module_versions: Current module versions
        commands: Dictionary of module_name -> (command_type, value)
                 command_type can be 'bump' or 'set'
                 value is bump_type for 'bump' or version string for 'set'

    Returns:
        Updated module versions dictionary.
    """
    updated_versions = module_versions.copy()

    for module_name, (command_type, value) in commands.items():
      if module_name not in updated_versions:
        print(f"Warning: Module {module_name} not found in current versions")
        continue

      current_info = updated_versions[module_name]

      try:
        if command_type == "bump":
          new_version = self.bump_version(current_info.current_version, value)
          source = f"bump_{value}"
        elif command_type == "set":
          if not self.validate_version(value):
            print(f"Error: Invalid version {value} for {module_name}")
            continue
          new_version = value
          source = "manual_set"
        else:
          print(f"Error: Unknown command type {command_type}")
          continue

        updated_versions[module_name] = VersionInfo(
          module_name=module_name,
          current_version=current_info.current_version,
          suggested_version=new_version,
          source=source,
        )

      except Exception as e:
        print(f"Error applying command to {module_name}: {e}")

    return updated_versions


def main():
  """CLI entry point for version management."""
  import argparse

  parser = argparse.ArgumentParser(description="Manage module versions")
  parser.add_argument("--repo-root", default=".", help="Repository root directory")

  subparsers = parser.add_subparsers(dest="command", help="Available commands")

  # Get version command
  get_parser = subparsers.add_parser("get", help="Get current version for module")
  get_parser.add_argument("module_name", help="Module name")

  # Bump version command
  bump_parser = subparsers.add_parser("bump", help="Bump version for module")
  bump_parser.add_argument("module_name", help="Module name")
  bump_parser.add_argument(
    "bump_type", choices=["major", "minor", "patch"], help="Bump type"
  )

  # Create tag command
  tag_parser = subparsers.add_parser("tag", help="Create tag for module")
  tag_parser.add_argument("module_name", help="Module name")
  tag_parser.add_argument("version", help="Version to tag")
  tag_parser.add_argument("--message", help="Tag message")

  # List all versions command
  list_parser = subparsers.add_parser("list", help="List all module versions")
  list_parser.add_argument(
    "modules", nargs="*", help="Module names (if empty, lists all)"
  )

  args = parser.parse_args()

  if not args.command:
    parser.print_help()
    return

  manager = VersionManager(args.repo_root)

  if args.command == "get":
    version = manager.get_current_version(args.module_name)
    print(f"{args.module_name}: {version}")

  elif args.command == "bump":
    current = manager.get_current_version(args.module_name)
    new_version = manager.bump_version(current, args.bump_type)
    print(f"{args.module_name}: {current} -> {new_version}")

  elif args.command == "tag":
    success = manager.create_tag(args.module_name, args.version, args.message)
    if success:
      print(f"Successfully created tag for {args.module_name} v{args.version}")
    else:
      print(f"Failed to create tag for {args.module_name} v{args.version}")

  elif args.command == "list":
    if args.modules:
      versions = manager.get_all_module_versions(args.modules)
    else:
      # This would need module detection to get all modules
      print("Error: Please specify module names or use module detector first")
      return

    for module_name, version_info in versions.items():
      print(
        f"{module_name}: {version_info.current_version} -> {version_info.suggested_version}"
      )


if __name__ == "__main__":
  main()
