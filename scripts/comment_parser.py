#!/usr/bin/env python3
"""
Comment Parser Utility

Parses GitHub PR comments for version management commands.
"""

import re
from typing import Dict, List, Tuple
from dataclasses import dataclass


@dataclass
class VersionCommand:
  """Represents a version management command from a comment."""

  module_name: str
  command_type: str  # 'bump' or 'set'
  value: str  # bump_type for 'bump', version string for 'set'
  raw_command: str


class CommentParser:
  """Parses GitHub comments for version management commands."""

  GENERATED_ANALYSIS_MARKERS = (
    "## 📦 Module Versioning Analysis",
    "### Bump Version Commands",
    "### Set Specific Version Commands",
  )

  def __init__(self):
    # Regex patterns for different command formats
    self.bump_pattern = re.compile(
      r"\.bumpver\s+([a-zA-Z0-9\-_]+)\s+(major|minor|patch)", re.IGNORECASE
    )
    self.set_pattern = re.compile(
      r"\.setver\s+([a-zA-Z0-9\-_]+)\s+v?(\d+\.\d+\.\d+)", re.IGNORECASE
    )

  def parse_comment(self, comment_body: str) -> List[VersionCommand]:
    """
    Parse a comment body for version management commands.

    Args:
        comment_body: The text content of the comment

    Returns:
        List of VersionCommand objects found in the comment.
    """
    commands = []

    # Find all bump commands
    for match in self.bump_pattern.finditer(comment_body):
      module_name = match.group(1)
      bump_type = match.group(2).lower()
      raw_command = match.group(0)

      commands.append(
        VersionCommand(
          module_name=module_name,
          command_type="bump",
          value=bump_type,
          raw_command=raw_command,
        )
      )

    # Find all set commands
    for match in self.set_pattern.finditer(comment_body):
      module_name = match.group(1)
      version = match.group(2)
      raw_command = match.group(0)

      commands.append(
        VersionCommand(
          module_name=module_name,
          command_type="set",
          value=version,
          raw_command=raw_command,
        )
      )

    return commands

  def parse_multiple_comments(self, comments: List[str]) -> List[VersionCommand]:
    """
    Parse multiple comment bodies for version management commands.

    Args:
        comments: List of comment body strings

    Returns:
        List of all VersionCommand objects found across all comments.
    """
    all_commands = []

    for comment in comments:
      if self.is_generated_analysis_comment(comment):
        continue

      commands = self.parse_comment(comment)
      all_commands.extend(commands)

    return all_commands

  def is_generated_analysis_comment(self, comment_body: str) -> bool:
    """Return True when a comment matches the workflow-generated analysis template."""
    return all(marker in comment_body for marker in self.GENERATED_ANALYSIS_MARKERS)

  def validate_commands(
    self, commands: List[VersionCommand], valid_modules: List[str]
  ) -> Tuple[List[VersionCommand], List[str]]:
    """
    Validate commands against a list of valid module names.

    Args:
        commands: List of VersionCommand objects to validate
        valid_modules: List of valid module names

    Returns:
        Tuple of (valid_commands, error_messages)
    """
    valid_commands = []
    errors = []

    for cmd in commands:
      if cmd.module_name not in valid_modules:
        errors.append(f"Unknown module '{cmd.module_name}' in command: {cmd.raw_command}")
        continue

      if cmd.command_type == "bump":
        if cmd.value not in ["major", "minor", "patch"]:
          errors.append(f"Invalid bump type '{cmd.value}' in command: {cmd.raw_command}")
          continue

      elif cmd.command_type == "set":
        # Basic version format validation
        if not re.match(r"^\d+\.\d+\.\d+$", cmd.value):
          errors.append(
            f"Invalid version format '{cmd.value}' in command: {cmd.raw_command}"
          )
          continue

      valid_commands.append(cmd)

    return valid_commands, errors

  def commands_to_dict(
    self, commands: List[VersionCommand]
  ) -> Dict[str, Tuple[str, str]]:
    """
    Convert list of commands to dictionary format for version manager.

    Args:
        commands: List of VersionCommand objects

    Returns:
        Dictionary mapping module_name -> (command_type, value)
    """
    command_dict = {}

    for cmd in commands:
      # If multiple commands for same module, last one wins
      command_dict[cmd.module_name] = (cmd.command_type, cmd.value)

    return command_dict

  def generate_help_text(self) -> str:
    """
    Generate help text explaining the command syntax.

    Returns:
        Help text string.
    """
    return """
## Version Management Commands

You can control module versioning using the following commands in PR comments:

### Bump Version Commands
- `.bumpver <module-name> patch` - Increment patch version (e.g., 1.0.0 → 1.0.1)
- `.bumpver <module-name> minor` - Increment minor version (e.g., 1.0.0 → 1.1.0)
- `.bumpver <module-name> major` - Increment major version (e.g., 1.0.0 → 2.0.0)

### Set Version Commands
- `.setver <module-name> v1.2.3` - Set specific version
- `.setver <module-name> 1.2.3` - Set specific version (v prefix optional)

### Examples
```
.bumpver t-vm patch
.bumpver a-infoblox minor
.setver t-vm v2.0.0
.setver a-windows-postdeploy 1.5.2
```

### Notes
- Commands are case-insensitive
- Multiple commands can be used in a single comment
- If multiple commands target the same module, the last one takes precedence
- If no commands are provided, all changed modules will receive a patch version bump by default
"""

  def format_command_summary(self, commands: List[VersionCommand]) -> str:
    """
    Format a summary of parsed commands for display.

    Args:
        commands: List of VersionCommand objects

    Returns:
        Formatted summary string.
    """
    if not commands:
      return "No version commands found in comments."

    summary = "## Parsed Version Commands\n\n"

    for cmd in commands:
      if cmd.command_type == "bump":
        summary += f"- **{cmd.module_name}**: Bump {cmd.value} version\n"
      elif cmd.command_type == "set":
        summary += f"- **{cmd.module_name}**: Set version to {cmd.value}\n"

    return summary


def main():
  """CLI entry point for comment parsing."""
  import argparse
  import json
  import sys

  parser = argparse.ArgumentParser(
    description="Parse GitHub comments for version commands"
  )
  parser.add_argument("--comment", help="Single comment to parse")
  parser.add_argument("--comments-file", help="File containing comments (one per line)")
  parser.add_argument(
    "--valid-modules", nargs="*", help="List of valid module names for validation"
  )
  parser.add_argument(
    "--format",
    choices=["json", "text", "summary"],
    default="text",
    help="Output format",
  )
  parser.add_argument(
    "--help-text", action="store_true", help="Show help text for commands"
  )

  args = parser.parse_args()

  parser_obj = CommentParser()

  if args.help_text:
    print(parser_obj.generate_help_text())
    return

  # Get comments to parse
  comments = []
  if args.comment:
    comments.append(args.comment)
  elif args.comments_file:
    try:
      with open(args.comments_file, "r") as f:
        comments = [line.strip() for line in f if line.strip()]
    except FileNotFoundError:
      print(f"Error: File {args.comments_file} not found")
      sys.exit(1)
  else:
    # Read from stdin
    comments = [line.strip() for line in sys.stdin if line.strip()]

  if not comments:
    print("No comments provided")
    return

  # Parse commands
  commands = parser_obj.parse_multiple_comments(comments)

  # Validate if valid modules provided
  if args.valid_modules:
    commands, errors = parser_obj.validate_commands(commands, args.valid_modules)
    if errors:
      print("Validation errors:")
      for error in errors:
        print(f"  - {error}")
      print()

  # Output results
  if args.format == "json":
    command_dict = parser_obj.commands_to_dict(commands)
    print(json.dumps(command_dict, indent=2))
  elif args.format == "summary":
    print(parser_obj.format_command_summary(commands))
  else:
    if commands:
      print(f"Found {len(commands)} version commands:")
      for cmd in commands:
        print(f"  {cmd.module_name}: {cmd.command_type} {cmd.value}")
    else:
      print("No version commands found")


if __name__ == "__main__":
  main()
