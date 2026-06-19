# Linear Requirement Inserter

VS Code extension that integrates Linear project management with your development workflow, allowing you to easily insert requirement references from in-progress tickets directly into your code.

## Features

- 🎯 **Quick Insertion**: Press `Ctrl+Shift+R` (or `Cmd+Shift+R` on Mac) to insert requirements
- ⌨️ **Auto-completion**: Type `//impl`, `--impl`, or `#impl` to trigger requirement suggestions
- 📝 **Multi-format Support**: Automatically uses correct comment syntax for SQL, Dart, Python, JS/TS, Markdown, and more
- 🔄 **Real-time Sync**: Fetches latest in-progress tickets from Linear
- 📋 **Multi-select**: Select multiple requirements to insert at once
- 🎨 **Smart Formatting**: Inserts requirements with titles in multi-line format

## Requirements

- Linear account with API access
- VS Code 1.85.0 or higher
- Project with `spec/` directory containing requirement definitions

## Installation

### From VSIX (Development)
1. Download the `.vsix` file
2. Open VS Code
3. Run: `Extensions: Install from VSIX...` from Command Palette
4. Select the downloaded file

### From Source
```bash
cd vscode-linear-req-inserter
npm install
npm run compile
# Press F5 to launch Extension Development Host
```

## Setup

### 1. Get Linear API Token
1. Go to [Linear Settings > API](https://linear.app/settings/api)
2. Create a new Personal API Key
3. Copy the token (starts with `lin_api_`)

### 2. Configure Extension
1. Open VS Code Settings (`Ctrl+,` or `Cmd+,`)
2. Search for "Linear Requirement Inserter"
3. Paste your API token into `Linear Req Inserter: Api Token`
4. (Optional) Set `Linear Req Inserter: Spec Path` if not `${workspaceFolder}/spec`

### 3. Add Requirements to Linear Tickets
In your Linear ticket descriptions or comments, reference requirements like:
```markdown
This implements DIARY-PRD-user-account-create, DIARY-OPS-storage-rules, and DIARY-DEV-event-store-rename
```

## Usage

### Method 1: Keyboard Shortcut (Recommended)
1. Move cursor to where you want to insert requirements
2. Press `Ctrl+Shift+R` (or `Cmd+Shift+R` on Mac)
3. Select requirements from the picker (use Tab for multi-select)
4. Press Enter to insert

### Method 2: Right-Click Context Menu
1. Right-click where you want to insert requirements
2. Select **"Insert Requirements from Linear Ticket"**
3. Select requirements from the picker
4. Press Enter to insert

### Method 3: Command Palette
1. Press `Ctrl+Shift+P` (or `Cmd+Shift+P` on Mac)
2. Type "Insert Requirements"
3. Select **"Insert Requirements from Linear Ticket"**
4. Select requirements from the picker
5. Press Enter to insert

## Example Output

### SQL File (`database/schema.sql`)
```sql
-- Implements: DIARY-PRD-data-isolation: Multi-Sponsor Data Isolation
-- Implements: DIARY-OPS-storage-rules: Database Configuration Per Sponsor
-- Implements: DIARY-DEV-participant-isolation-rls: Participant Data Isolation RLS Implementation
```

### Dart File (`lib/main.dart`)
```dart
// Implements: DIARY-PRD-offline-first-entry: Offline-First Data Entry
// Implements: DIARY-DEV-local-first-entry: Local-First Data Entry Implementation
```

### Python File (`scripts/migrate.py`)
```python
# Implements: DIARY-PRD-audit-trail: Immutable Audit Trail via Event Sourcing
# Implements: DIARY-DEV-event-store-schema: Database Schema Implementation
```

## Configuration

| Setting | Description | Default |
| --- | --- | --- |
| `linearReqInserter.apiToken` | Linear API token | (empty) |
| `linearReqInserter.teamId` | Linear team ID (optional) | (empty) |
| `linearReqInserter.specPath` | Path to spec/ directory | `${workspaceFolder}/spec` |
| `linearReqInserter.commentFormat` | Format style (`multiline` or `singleline`) | `multiline` |
| `linearReqInserter.includeTicketLink` | Include Linear ticket URL in comment | `false` |

## Workflow Integration

1. **Create Linear Ticket**: Include requirement IDs in description
   ```markdown
   Implement database access controls

   Requirements:
   - DIARY-PRD-participant-data-isolation: Participant Data Isolation
   - DIARY-PRD-investigator-site-access: Investigator Site-Scoped Access
   - DIARY-PRD-investigator-annotation-restrictions: Investigator Annotation Restrictions
   ```

2. **Move to "In Progress"**: Extension only shows in-progress tickets

3. **Insert in Code**: Use keyboard shortcut or auto-completion

4. **Traceability**: Requirements are now linked to implementation files

## File Type Support

The extension automatically detects file types and uses appropriate comment syntax:

| File Types | Comment Style | Example |
| --- | --- | --- |
| `.sql` | `--` | `-- Implements: DIARY-PRD-user-account-create: Title` |
| `.dart`, `.js`, `.ts`, `.java`, `.cpp` | `//` | `// Implements: DIARY-PRD-user-account-create: Title` |
| `.py`, `.rb`, `.sh` | `#` | `# Implements: DIARY-PRD-user-account-create: Title` |
| `.html`, `.xml`, `.md` | `<!-- -->` | `<!-- Implements: DIARY-PRD-user-account-create: Title -->` |

## Troubleshooting

### "No in-progress tickets found"
- Ensure you have tickets in "In Progress" or "In Review" status
- Check that tickets are assigned to you in Linear

### "No requirements found in tickets"
- Add requirement references (DIARY-PRD-user-account-create, etc.) to ticket descriptions or comments
- Format must match: `DIARY-(PRD|GUI|OPS|DEV)-[a-z0-9-]+`

### "Failed to fetch Linear tickets"
- Verify API token is correct
- Check internet connection
- Ensure API token has not expired

### "Loaded 0 requirements"
- Verify `spec/` directory exists in workspace
- Check that `.md` files contain requirement definitions
- Ensure requirements follow format: `### DIARY-PRD-user-account-create: Title`

## Development

### Building
```bash
npm install
npm run compile
```

### Testing
```bash
npm test
```

### Packaging
```bash
npm install -g vsce
vsce package
```

## Architecture

```
src/
├── extension.ts          # Main entry point
├── linear/              # Linear API integration
│   ├── client.ts        # API client using @linear/sdk
│   ├── queries.ts       # GraphQL queries
│   └── types.ts         # TypeScript interfaces
├── requirements/        # Requirement parsing & loading
│   ├── parser.ts        # Extract REQ-* from text
│   ├── loader.ts        # Load from spec/ files
│   └── cache.ts         # In-memory caching
├── comments/            # Comment formatting & insertion
│   ├── detector.ts      # File type detection
│   ├── templates.ts     # Comment templates
│   └── inserter.ts      # Editor insertion logic
├── ui/                  # User interface
│   ├── quickpick.ts     # Requirement picker
│   └── completion.ts    # Auto-completion provider
└── config.ts            # Configuration management
```

## License

MIT

## Contributing

Contributions welcome! Please open an issue or PR.

## Support

For issues or feature requests, please use the [GitHub Issues](https://github.com/your-org/linear-req-inserter/issues) page.
