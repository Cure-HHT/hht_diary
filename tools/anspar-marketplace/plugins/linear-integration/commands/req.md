# /req (alias: /requirement)

Manage and query formal requirements

## Usage

```
/req                    # Show help and recent requirements
/req REQ-d00027         # Display requirement details
/req search <term>      # Search for requirements by keyword
/req new                # Guide for creating new requirement
/req validate           # Validate all requirements
```

## Examples

```
/req                    # Shows usage and last 5 requirements
/req REQ-d00067         # Shows details of REQ-d00067
/req search "ticket"    # Finds all requirements mentioning "ticket"
/req new                # Shows process for creating requirements
/req validate           # Runs requirement validation
```

## Implementation

This command integrates with:
- **Requirement validation tools**: For validation and parsing
- **Spec directory**: For requirement content
- **INDEX.md**: For requirement listing

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/req-command.sh "$@"
```
