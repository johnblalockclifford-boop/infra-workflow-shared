#!/usr/bin/env python3
"""
Integration tests for module automation scripts.

These tests run against the actual repository to validate end-to-end functionality.
"""

import pytest
import tempfile
import shutil
from pathlib import Path

from module_detector import ModuleDetector
from version_manager import VersionManager
from comment_parser import CommentParser
from workflow_orchestrator import WorkflowOrchestrator


class TestModuleAutomation:
  """Integration tests for module automation functionality."""

  @pytest.fixture
  def repo_root(self):
    """Get the repository root directory."""
    return Path(__file__).parent.parent

  @pytest.fixture
  def detector(self, repo_root):
    """Create a ModuleDetector instance."""
    return ModuleDetector(str(repo_root))

  @pytest.fixture
  def version_manager(self, repo_root):
    """Create a VersionManager instance."""
    return VersionManager(str(repo_root))

  @pytest.fixture
  def comment_parser(self):
    """Create a CommentParser instance."""
    return CommentParser()

  @pytest.fixture
  def orchestrator(self, repo_root):
    """Create a WorkflowOrchestrator instance."""
    return WorkflowOrchestrator(str(repo_root))

  def test_module_detection(self, detector):
    """Test that module detection finds expected modules in the repository."""
    modules = detector.find_all_modules()

    # Should find at least the known modules
    module_names = [module.name for module in modules]

    # Check for expected modules based on repository structure
    assert len(modules) >= 2, f"Expected at least 2 modules, found {len(modules)}"

    # Verify module naming convention
    for module in modules:
      assert module.name.startswith(("t-", "a-")), (
        f"Module {module.name} doesn't follow naming convention"
      )
      assert module.type in ["terraform", "ansible"], f"Invalid module type: {module.type}"
      assert module.path, f"Module {module.name} has empty path"
      assert module.readme_path, f"Module {module.name} has empty readme_path"

    print(f"✓ Found {len(modules)} modules: {module_names}")

  def test_version_management(self, version_manager):
    """Test version management functionality."""
    # Test version validation
    assert version_manager.validate_version("1.0.0")
    assert not version_manager.validate_version("invalid")

    # Test version bumping
    assert version_manager.bump_version("1.0.0", "patch") == "1.0.1"
    assert version_manager.bump_version("1.0.0", "minor") == "1.1.0"
    assert version_manager.bump_version("1.0.0", "major") == "2.0.0"

    # Test getting current version (should return 0.0.0 for non-existent modules)
    version = version_manager.get_current_version("test-module")
    assert version == "0.0.0"

    print("✓ Version management functions work correctly")

  def test_comment_parsing(self, comment_parser):
    """Test comment parsing functionality."""
    # Test bump commands
    comment1 = ".bumpver t-vm patch\n.bumpver a-infoblox minor"
    commands1 = comment_parser.parse_comment(comment1)

    assert len(commands1) == 2
    assert commands1[0].module_name == "t-vm"
    assert commands1[0].command_type == "bump"
    assert commands1[0].value == "patch"

    # Test set commands
    comment2 = ".setver t-vm v1.2.3\n.setver a-windows 2.0.0"
    commands2 = comment_parser.parse_comment(comment2)

    assert len(commands2) == 2
    assert commands2[0].module_name == "t-vm"
    assert commands2[0].command_type == "set"
    assert commands2[0].value == "1.2.3"

    # Test command validation
    valid_modules = ["t-vm", "a-infoblox"]
    valid_commands, errors = comment_parser.validate_commands(commands1, valid_modules)

    assert len(valid_commands) == 2
    assert len(errors) == 0

    generated_comment = """## 📦 Module Versioning Analysis

  ### Bump Version Commands
  - `.bumpver t-vm patch`

  ### Set Specific Version Commands
  - `.setver t-vm v1.2.3`
  """
    assert comment_parser.parse_multiple_comments([generated_comment]) == []

    print("✓ Comment parsing works correctly")

  def test_changed_module_detection(self, detector):
    """Test detection of changed modules based on file paths."""
    # Simulate changed files
    changed_files = [
      "modules/terraform/vm/main.tf",
      "modules/ansible/infoblox/tasks/main.yaml",
      "README.md",  # This shouldn't match any module
    ]

    changed_modules = detector.find_changed_modules(changed_files)

    # Should find modules that contain the changed files
    assert len(changed_modules) >= 1, "Should detect at least one changed module"

    module_names = [module.name for module in changed_modules]
    print(f"✓ Detected changed modules: {module_names}")

  def test_workflow_orchestrator_comment_processing(self, orchestrator):
    """Test the workflow orchestrator's comment processing."""
    comments = [".bumpver t-vm minor", ".setver a-infoblox v1.5.0"]

    valid_modules = ["t-vm", "a-infoblox", "a-windows"]

    result = orchestrator.process_pr_comments(comments, valid_modules)

    assert "commands" in result
    assert "errors" in result
    assert len(result["commands"]) == 2
    assert result["commands"]["t-vm"] == ("bump", "minor")
    assert result["commands"]["a-infoblox"] == ("set", "1.5.0")

    print("✓ Workflow orchestrator processes comments correctly")

  def test_pr_comment_generation(self, orchestrator):
    """Test PR comment generation."""
    # Mock analysis data
    analysis = {
      "changed_modules": [
        {
          "name": "t-vm",
          "path": "terraform/vm",
          "type": "terraform",
          "description": "Azure VM creation module",
          "readme_path": "modules/terraform/vm/README.md",
        }
      ],
      "module_versions": {
        "t-vm": {"current_version": "1.0.0", "suggested_version": "1.0.1", "source": "git_tag"}
      },
      "analysis_summary": "Found 1 module with changes.",
    }

    comment = orchestrator.generate_pr_comment(analysis)

    assert "Module Versioning Analysis" in comment
    assert "t-vm" in comment
    assert "1.0.0" in comment
    assert "1.0.1" in comment
    assert ".bumpver" in comment
    assert ".setver" in comment
    assert "v1.2.3" not in comment
    assert "v<major>.<minor>.<patch>" in comment

    print("✓ PR comment generation works correctly")

  def test_generated_analysis_comment_is_ignored(self, orchestrator):
    """Test that workflow-generated analysis comments do not override versions."""
    comments = [
      """## 📦 Module Versioning Analysis

### Bump Version Commands
- `.bumpver t-vm patch`

### Set Specific Version Commands
- `.setver t-vm v1.2.3`
"""
    ]

    result = orchestrator.process_pr_comments(comments, ["t-vm"])

    assert result["commands"] == {}
    assert result["valid_commands"] == 0

  def test_final_versions_apply_bump_type(self, orchestrator):
    """Test that .bumpver minor/major and .setver override the default patch bump."""
    analysis = {
      "changed_modules": [
        {"name": "t-major"},
        {"name": "t-minor"},
        {"name": "t-patch"},
        {"name": "t-set"},
        {"name": "t-default"},
      ],
      "module_versions": {
        name: {"current_version": "1.2.3", "suggested_version": "1.2.4"}
        for name in ["t-major", "t-minor", "t-patch", "t-set", "t-default"]
      },
    }
    # Shape as read back from commands.json: JSON turns the tuples into lists
    commands = {
      "commands": {
        "t-major": ["bump", "major"],
        "t-minor": ["bump", "minor"],
        "t-patch": ["bump", "patch"],
        "t-set": ["set", "4.5.6"],
      }
    }

    final_versions = orchestrator.calculate_final_versions(analysis, commands)

    assert final_versions == {
      "t-major": "2.0.0",
      "t-minor": "1.3.0",
      "t-patch": "1.2.4",
      "t-set": "4.5.6",
      "t-default": "1.2.4",
    }

  def test_final_versions_first_release(self, orchestrator):
    """Test bumps from a module with no tags yet (0.0.0)."""
    analysis = {
      "changed_modules": [{"name": "t-new"}],
      "module_versions": {
        "t-new": {"current_version": "0.0.0", "suggested_version": "0.0.1"}
      },
    }

    final_versions = orchestrator.calculate_final_versions(
      analysis, {"commands": {"t-new": ["bump", "minor"]}}
    )

    assert final_versions == {"t-new": "0.1.0"}

  def test_module_info_map_from_analysis_payload(self, orchestrator):
    """Test module info parsing when modules file is analysis.json."""
    modules_payload = {
      "changed_modules": [
        {
          "name": "t-example",
          "path": "terraform/example",
          "type": "terraform",
          "description": "Example module",
          "readme_path": "modules/terraform/example/README.md",
        }
      ]
    }

    module_info = orchestrator.build_module_info_map(modules_payload)

    assert "t-example" in module_info
    assert module_info["t-example"].path == "terraform/example"
    assert module_info["t-example"].current_version == "0.0.0"
    assert module_info["t-example"].type == "terraform"

  def test_module_info_map_derives_fields_from_module_map(self, orchestrator):
    """Test module info parsing for module_name -> module metadata payloads."""
    modules_payload = {
      "a-sample": {
        "description": "Ansible sample module",
        "readme_path": "modules/ansible/sample/README.md",
      }
    }

    module_info = orchestrator.build_module_info_map(modules_payload)

    assert "a-sample" in module_info
    assert module_info["a-sample"].path == "ansible/sample"
    assert module_info["a-sample"].type == "ansible"
    assert module_info["a-sample"].readme_path == "modules/ansible/sample/README.md"

  def test_end_to_end_workflow(self, orchestrator, detector):
    """Test a simplified end-to-end workflow."""
    # 1. Detect all modules
    modules = detector.find_all_modules()
    assert len(modules) > 0, "No modules found in repository"

    # 2. Simulate changed files for first module
    first_module = modules[0]
    changed_files = [f"modules/{first_module.path}/README.md"]

    # 3. Detect changed modules
    changed_modules = detector.find_changed_modules(changed_files)
    assert len(changed_modules) >= 1, "Should detect at least one changed module"

    # 4. Process version commands
    comments = [f".bumpver {first_module.name} patch"]
    module_names = [module.name for module in modules]

    result = orchestrator.process_pr_comments(comments, module_names)
    assert len(result["commands"]) == 1
    assert result["commands"][first_module.name] == ("bump", "patch")

    print(f"✓ End-to-end workflow completed successfully for module: {first_module.name}")


def test_repository_structure():
  """Test that the repository has the expected structure."""
  repo_root = Path(__file__).parent.parent
  modules_dir = repo_root / "modules"

  assert modules_dir.exists(), "modules directory should exist"

  # Check for expected subdirectories
  terraform_dir = modules_dir / "terraform"
  ansible_dir = modules_dir / "ansible"

  # At least one should exist
  assert terraform_dir.exists() or ansible_dir.exists(), "Should have terraform or ansible modules"

  print("✓ Repository structure is valid")


if __name__ == "__main__":
  # Run tests directly
  pytest.main([__file__, "-v"])
