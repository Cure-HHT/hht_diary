# REQ-d00066: Plugin-Specific Permission Management

**Level**: Dev | **Status**: Draft | **Implements**: o00017

## Rationale

This requirement establishes an automated permission management system for Claude Code plugins. Each plugin declares the commands it needs in a manifest file, and these permissions are automatically configured during installation and cleaned up during uninstallation. This design eliminates repetitive user permission prompts while maintaining security through explicit permission declarations. The system must handle shared permissions correctly when multiple plugins require the same commands, and must track which plugin added which permission to prevent premature removal.

## Assertions

A. The system SHALL support a permissions.json manifest file in each plugin's .claude-plugin directory that declares required commands.

B. The system SHALL provide a manage-permissions.sh utility that supports add, remove, and list operations for plugin permissions.

C. The system SHALL automatically add all permissions declared in permissions.json when a plugin is installed.

D. The system SHALL automatically remove permissions when a plugin is uninstalled.

E. The system SHALL maintain a registry that tracks which plugin added each permission.

F. The system SHALL NOT remove a permission during uninstallation if another installed plugin still requires that permission.

G. Permission management operations SHALL be idempotent such that running the same operation multiple times produces the same result.

H. The plugin install script SHALL invoke the permission addition utility during installation.

I. The plugin uninstall script SHALL invoke the permission removal utility during uninstallation.

J. The plugin-expert plugin permissions manifest SHALL include at minimum: git status, git diff, git show, git rev-parse, git ls-files, and gh commands.

*End* *Plugin-Specific Permission Management* | **Hash**: 03045719
---
