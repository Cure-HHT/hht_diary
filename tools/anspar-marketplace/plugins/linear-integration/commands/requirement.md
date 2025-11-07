# /requirement (alias for /req)

Alias for `/req` command. See `/req` for full documentation.

## Usage

```
/requirement                    # Show help
/requirement REQ-d00027         # Display requirement
/requirement search <term>      # Search requirements
/requirement new                # Create new requirement
/requirement validate           # Validate requirements
```

## Implementation

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/req-command.sh "$@"
```
