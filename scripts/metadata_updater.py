#!/usr/bin/env python3
"""
Metadata Updater Utility

Updates README.md files with module metadata including version information.
"""

import re
from pathlib import Path
from typing import Dict, Optional
from datetime import datetime
from dataclasses import dataclass


@dataclass
class ModuleMetadata:
  """Represents module metadata."""

  name: str
  type: str
  description: str
  current_version: str
  last_updated: str


class MetadataUpdater:
  """Updates README.md files with module metadata."""

  def __init__(self, repo_root: str = "."):
    self.repo_root = Path(repo_root).resolve()

  def update_readme_metadata(self, readme_path: str, metadata: ModuleMetadata) -> bool:
    """
    Update the metadata block in a README.md file.

    Args:
        readme_path: Path to the README.md file
        metadata: ModuleMetadata object with updated information

    Returns:
        True if successful, False otherwise.
    """
    try:
      readme_file = Path(readme_path)
      if not readme_file.exists():
        print(f"README file not found: {readme_path}")
        return False

      # Read current content
      with open(readme_file, "r", encoding="utf-8") as f:
        content = f.read()

      # Generate new metadata block
      new_metadata_block = self._generate_metadata_block(metadata)

      # Check if metadata block exists
      metadata_pattern = r"<!--\s*MODULE_METADATA\s*\n.*?\n\s*-->"

      if re.search(metadata_pattern, content, re.DOTALL):
        # Replace existing metadata block
        new_content = re.sub(
          metadata_pattern, new_metadata_block, content, flags=re.DOTALL
        )
      else:
        # Add metadata block at the beginning
        new_content = new_metadata_block + "\n\n" + content

      # Write updated content
      with open(readme_file, "w", encoding="utf-8") as f:
        f.write(new_content)

      print(f"Updated metadata in {readme_path}")
      return True

    except Exception as e:
      print(f"Error updating {readme_path}: {e}")
      return False

  def _generate_metadata_block(self, metadata: ModuleMetadata) -> str:
    """
    Generate a metadata block for insertion into README.md.

    Args:
        metadata: ModuleMetadata object

    Returns:
        Formatted metadata block string.
    """
    return f"""<!-- MODULE_METADATA
name: {metadata.name}
type: {metadata.type}
description: {metadata.description}
current_version: {metadata.current_version}
last_updated: {metadata.last_updated}
-->"""

  def parse_existing_metadata(self, readme_path: str) -> Optional[ModuleMetadata]:
    """
    Parse existing metadata from a README.md file.

    Args:
        readme_path: Path to the README.md file

    Returns:
        ModuleMetadata object if found, None otherwise.
    """
    try:
      readme_file = Path(readme_path)
      if not readme_file.exists():
        return None

      with open(readme_file, "r", encoding="utf-8") as f:
        content = f.read()

      # Look for MODULE_METADATA block
      pattern = r"<!--\s*MODULE_METADATA\s*\n(.*?)\n\s*-->"
      match = re.search(pattern, content, re.DOTALL)

      if not match:
        return None

      metadata_content = match.group(1)
      metadata_dict = {}

      # Parse key: value pairs
      for line in metadata_content.split("\n"):
        line = line.strip()
        if ":" in line:
          key, value = line.split(":", 1)
          metadata_dict[key.strip()] = value.strip()

      # Create ModuleMetadata object
      return ModuleMetadata(
        name=metadata_dict.get("name", ""),
        type=metadata_dict.get("type", ""),
        description=metadata_dict.get("description", ""),
        current_version=metadata_dict.get("current_version", "0.0.0"),
        last_updated=metadata_dict.get("last_updated", ""),
      )

    except Exception as e:
      print(f"Error parsing metadata from {readme_path}: {e}")
      return None

  def update_multiple_modules(
    self, module_updates: Dict[str, Dict[str, str]]
  ) -> Dict[str, bool]:
    """
    Update metadata for multiple modules.

    Args:
        module_updates: Dictionary mapping readme_path -> update_data
                      update_data should contain keys like 'current_version', 'description', etc.

    Returns:
        Dictionary mapping readme_path -> success_status
    """
    results = {}

    for readme_path, update_data in module_updates.items():
      try:
        # Parse existing metadata or create new
        existing_metadata = self.parse_existing_metadata(readme_path)

        if existing_metadata:
          # Update existing metadata
          updated_metadata = ModuleMetadata(
            name=update_data.get("name", existing_metadata.name),
            type=update_data.get("type", existing_metadata.type),
            description=update_data.get("description", existing_metadata.description),
            current_version=update_data.get(
              "current_version", existing_metadata.current_version
            ),
            last_updated=update_data.get("last_updated", datetime.now().isoformat()),
          )
        else:
          # Create new metadata
          updated_metadata = ModuleMetadata(
            name=update_data.get("name", ""),
            type=update_data.get("type", ""),
            description=update_data.get("description", ""),
            current_version=update_data.get("current_version", "0.0.0"),
            last_updated=update_data.get("last_updated", datetime.now().isoformat()),
          )

        success = self.update_readme_metadata(readme_path, updated_metadata)
        results[readme_path] = success

      except Exception as e:
        print(f"Error updating {readme_path}: {e}")
        results[readme_path] = False

    return results

  def create_changelog_entry(
    self, module_path: str, version: str, changes: list, timestamp: str = None
  ) -> bool:
    """
    Create or update a CHANGELOG.md file for a module.

    Args:
        module_path: Path to the module directory
        version: Version string for the changelog entry
        changes: List of change descriptions
        timestamp: Optional timestamp (defaults to current time)

    Returns:
        True if successful, False otherwise.
    """
    try:
      if timestamp is None:
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

      module_dir = Path(module_path)
      changelog_file = module_dir / "CHANGELOG.md"

      # Create new changelog entry
      new_entry = f"""## Version {version} ({timestamp})

"""

      if changes:
        for change in changes:
          new_entry += f"- {change}\n"
      else:
        new_entry += "- No specific changes logged\n"

      new_entry += "\n"

      # Read existing changelog or create header
      if changelog_file.exists():
        with open(changelog_file, "r", encoding="utf-8") as f:
          existing_content = f.read()

        # Insert new entry after the header
        lines = existing_content.split("\n")
        if lines and lines[0].startswith("# Changelog"):
          # Find where to insert (after header and any existing content)
          insert_index = 1
          while insert_index < len(lines) and (
            not lines[insert_index].strip() or lines[insert_index].startswith("#")
          ):
            insert_index += 1

          # Insert new entry
          lines.insert(insert_index, new_entry.rstrip())
          new_content = "\n".join(lines)
        else:
          # Prepend to existing content
          new_content = new_entry + existing_content
      else:
        # Create new changelog
        module_name = module_dir.name
        header = f"# Changelog for {module_name}\n\n"
        new_content = header + new_entry

      # Write updated changelog
      with open(changelog_file, "w", encoding="utf-8") as f:
        f.write(new_content)

      print(f"Updated changelog: {changelog_file}")
      return True

    except Exception as e:
      print(f"Error creating changelog entry: {e}")
      return False


def main():
  """CLI entry point for metadata updating."""
  import argparse
  import json

  parser = argparse.ArgumentParser(description="Update module metadata in README files")
  parser.add_argument("--repo-root", default=".", help="Repository root directory")

  subparsers = parser.add_subparsers(dest="command", help="Available commands")

  # Update single module command
  update_parser = subparsers.add_parser(
    "update", help="Update metadata for a single module"
  )
  update_parser.add_argument("readme_path", help="Path to README.md file")
  update_parser.add_argument("--name", help="Module name")
  update_parser.add_argument("--type", help="Module type (terraform/ansible)")
  update_parser.add_argument("--description", help="Module description")
  update_parser.add_argument("--version", help="Current version")

  # Update multiple modules command
  batch_parser = subparsers.add_parser(
    "batch", help="Update metadata for multiple modules"
  )
  batch_parser.add_argument("updates_file", help="JSON file with update data")

  # Parse existing metadata command
  parse_parser = subparsers.add_parser(
    "parse", help="Parse existing metadata from README"
  )
  parse_parser.add_argument("readme_path", help="Path to README.md file")

  # Create changelog command
  changelog_parser = subparsers.add_parser("changelog", help="Create changelog entry")
  changelog_parser.add_argument("module_path", help="Path to module directory")
  changelog_parser.add_argument("version", help="Version for changelog entry")
  changelog_parser.add_argument("--changes", nargs="*", help="List of changes")

  args = parser.parse_args()

  if not args.command:
    parser.print_help()
    return

  updater = MetadataUpdater(args.repo_root)

  if args.command == "update":
    metadata = ModuleMetadata(
      name=args.name or "",
      type=args.type or "",
      description=args.description or "",
      current_version=args.version or "0.0.0",
      last_updated=datetime.now().isoformat(),
    )

    success = updater.update_readme_metadata(args.readme_path, metadata)
    if success:
      print(f"Successfully updated {args.readme_path}")
    else:
      print(f"Failed to update {args.readme_path}")

  elif args.command == "batch":
    try:
      with open(args.updates_file, "r") as f:
        updates = json.load(f)

      results = updater.update_multiple_modules(updates)

      print("Batch update results:")
      for path, success in results.items():
        status = "SUCCESS" if success else "FAILED"
        print(f"  {path}: {status}")

    except FileNotFoundError:
      print(f"Error: Updates file {args.updates_file} not found")
    except json.JSONDecodeError:
      print(f"Error: Invalid JSON in {args.updates_file}")

  elif args.command == "parse":
    metadata = updater.parse_existing_metadata(args.readme_path)
    if metadata:
      print(f"Metadata for {args.readme_path}:")
      print(f"  Name: {metadata.name}")
      print(f"  Type: {metadata.type}")
      print(f"  Description: {metadata.description}")
      print(f"  Version: {metadata.current_version}")
      print(f"  Last Updated: {metadata.last_updated}")
    else:
      print(f"No metadata found in {args.readme_path}")

  elif args.command == "changelog":
    changes = args.changes or []
    success = updater.create_changelog_entry(args.module_path, args.version, changes)
    if success:
      print(
        f"Successfully created changelog entry for {args.module_path} v{args.version}"
      )
    else:
      print(f"Failed to create changelog entry for {args.module_path} v{args.version}")


if __name__ == "__main__":
  main()
