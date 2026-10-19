#!/usr/bin/env python3
"""
Module Detection Utility

Scans the repository for modules by finding README.md files and extracting
module information based on their location and metadata.
"""

import re
from pathlib import Path
from typing import Dict, List, Optional, Tuple
from dataclasses import dataclass


@dataclass
class ModuleInfo:
  """Information about a detected module."""

  name: str
  path: str
  type: str  # 'terraform' or 'ansible'
  description: str
  current_version: str
  readme_path: str


class ModuleDetector:
  """Detects and manages module information in the repository."""

  def __init__(self, repo_root: str = "."):
    self.repo_root = Path(repo_root).resolve()
    self.modules_dir = self.repo_root / "modules"

  def find_all_modules(self) -> List[ModuleInfo]:
    """
    Find all modules by scanning for README.md files under modules/.

    Returns:
        List of ModuleInfo objects for all detected modules.
    """
    modules = []

    if not self.modules_dir.exists():
      return modules

    # Recursively find all README.md files under modules/
    for readme_path in self.modules_dir.rglob("README.md"):
      try:
        module_info = self._extract_module_info(readme_path)
        if module_info:
          modules.append(module_info)
      except Exception as e:
        print(f"Warning: Failed to process {readme_path}: {e}")

    return modules

  def find_changed_modules(self, changed_files: List[str]) -> List[ModuleInfo]:
    """
    Find modules that have changes based on a list of changed file paths.

    Args:
        changed_files: List of file paths that have been changed

    Returns:
        List of ModuleInfo objects for modules with changes.
    """
    all_modules = self.find_all_modules()
    changed_modules = []

    for module in all_modules:
      # Check if any changed file is within this module's directory
      # Module path is relative to modules/ (e.g., "terraform/vm")
      # Changed files include the modules/ prefix (e.g., "modules/terraform/vm/main.tf")
      module_full_path = f"modules/{module.path}"
      
      for changed_file in changed_files:
        # Check if the changed file starts with the module's full path
        if changed_file.startswith(module_full_path + "/") or changed_file == module_full_path:
          changed_modules.append(module)
          break

    return changed_modules

  def _extract_module_info(self, readme_path: Path) -> Optional[ModuleInfo]:
    """
    Extract module information from a README.md file.

    Args:
        readme_path: Path to the README.md file

    Returns:
        ModuleInfo object if valid module, None otherwise.
    """
    try:
      with open(readme_path, "r", encoding="utf-8") as f:
        content = f.read()
    except Exception as e:
      print(f"Error reading {readme_path}: {e}")
      return None

    # Extract metadata from README
    metadata = self._parse_metadata(content)

    # Determine module path relative to modules directory
    module_dir = readme_path.parent
    try:
      relative_path = module_dir.relative_to(self.modules_dir)
    except ValueError:
      print(f"Warning: {readme_path} is not under modules directory")
      return None

    # Generate module name and type from path
    module_name, module_type = self._generate_module_name(relative_path)

    # Use metadata if available, otherwise use defaults
    description = metadata.get("description", f"{module_type.title()} module")
    current_version = metadata.get("current_version", "0.0.0")

    return ModuleInfo(
      name=module_name,
      path=str(relative_path),
      type=module_type,
      description=description,
      current_version=current_version,
      readme_path=str(readme_path.relative_to(self.repo_root)),
    )

  def _parse_metadata(self, content: str) -> Dict[str, str]:
    """
    Parse MODULE_METADATA block from README content.

    Args:
        content: README.md file content

    Returns:
        Dictionary of metadata key-value pairs.
    """
    metadata = {}

    # Look for MODULE_METADATA block
    pattern = r"<!--\s*MODULE_METADATA\s*\n(.*?)\n\s*-->"
    match = re.search(pattern, content, re.DOTALL)

    if match:
      metadata_content = match.group(1)

      # Parse key: value pairs
      for line in metadata_content.split("\n"):
        line = line.strip()
        if ":" in line:
          key, value = line.split(":", 1)
          metadata[key.strip()] = value.strip()

    return metadata

  def _generate_module_name(self, relative_path: Path) -> Tuple[str, str]:
    """
    Generate module name and type from the relative path.

    Args:
        relative_path: Path relative to modules directory

    Returns:
        Tuple of (module_name, module_type)
    """
    parts = relative_path.parts

    if len(parts) == 0:
      raise ValueError("Invalid module path")

    # First part determines type (terraform/ansible)
    if parts[0] == "terraform":
      module_type = "terraform"
      prefix = "t"
    elif parts[0] == "ansible":
      module_type = "ansible"
      prefix = "a"
    else:
      # Default to terraform if unknown
      module_type = "terraform"
      prefix = "t"

    # Remaining parts form the module name
    if len(parts) > 1:
      name_parts = parts[1:]
      module_name = f"{prefix}-{'-'.join(name_parts)}"
    else:
      module_name = f"{prefix}-{parts[0]}"

    return module_name, module_type


def main():
  """CLI entry point for module detection."""
  import argparse
  import json

  parser = argparse.ArgumentParser(description="Detect modules in repository")
  parser.add_argument("--repo-root", default=".", help="Repository root directory")
  parser.add_argument("--changed-files", nargs="*", help="List of changed files")
  parser.add_argument(
    "--format", choices=["json", "text"], default="text", help="Output format"
  )

  args = parser.parse_args()

  detector = ModuleDetector(args.repo_root)

  if args.changed_files:
    modules = detector.find_changed_modules(args.changed_files)
  else:
    modules = detector.find_all_modules()

  if args.format == "json":
    module_data = []
    for module in modules:
      module_data.append(
        {
          "name": module.name,
          "path": module.path,
          "type": module.type,
          "description": module.description,
          "current_version": module.current_version,
          "readme_path": module.readme_path,
        }
      )
    print(json.dumps(module_data, indent=2))
  else:
    print(f"Found {len(modules)} modules:")
    for module in modules:
      print(
        f"  {module.name} ({module.type}) - {module.description} - v{module.current_version}"
      )


if __name__ == "__main__":
  main()
