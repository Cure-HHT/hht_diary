# Linear Requirement Inserter

VS Code extension that integrates Linear project management with your development workflow, allowing you to easily insert requirement references from in-progress tickets directly into your code.

## Features

- 🎯 **Quick Insertion**: Press `Ctrl+Shift+R` (or `Cmd+Shift+R` on Mac) to insert requirements
- ⌨️ **Auto-completion**: Type `//req`, `--req`, or `#req` to trigger requirement suggestions
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
This implements REQ-p00001, REQ-o00042, and REQ-d00019
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
-- REQ-p00001: Multi-Sponsor Data Isolation
-- REQ-o00042: Database Configuration Per Sponsor
-- REQ-d00019: Patient Data Isolation RLS Implementation
```

### Dart File (`lib/main.dart`)
```dart
// REQ-p00006: Offline-First Data Entry
// REQ-d00004: Local-First Data Entry Implementation
```

### Python File (`scripts/migrate.py`)
```python
# REQ-p00004: Immutable Audit Trail via Event Sourcing
# REQ-d00007: Database Schema Implementation
```

## Configuration

| Setting | Description | Default |
|---------|-------------|---------|
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
   - REQ-p00019: Patient Data Isolation
   - REQ-p00020: Investigator Site-Scoped Access
   - REQ-p00021: Investigator Annotation Restrictions
   ```

2. **Move to "In Progress"**: Extension only shows in-progress tickets

3. **Insert in Code**: Use keyboard shortcut or auto-completion

4. **Traceability**: Requirements are now linked to implementation files

## File Type Support

The extension automatically detects file types and uses appropriate comment syntax:

| File Types | Comment Style | Example |
|------------|---------------|---------|
| `.sql` | `--` | `-- REQ-p00001: Title` |
| `.dart`, `.js`, `.ts`, `.java`, `.cpp` | `//` | `// REQ-p00001: Title` |
| `.py`, `.rb`, `.sh` | `#` | `# REQ-p00001: Title` |
| `.html`, `.xml`, `.md` | `<!-- -->` | `<!-- REQ-p00001: Title -->` |

## Troubleshooting

### "No in-progress tickets found"
- Ensure you have tickets in "In Progress" or "In Review" status
- Check that tickets are assigned to you in Linear

### "No requirements found in tickets"
- Add requirement references (REQ-p00001, etc.) to ticket descriptions or comments
- Format must match: `REQ-[pod]\d{5}`

### "Failed to fetch Linear tickets"
- Verify API token is correct
- Check internet connection
- Ensure API token has not expired

### "Loaded 0 requirements"
- Verify `spec/` directory exists in workspace
- Check that `.md` files contain requirement definitions
- Ensure requirements follow format: `### REQ-p00001: Title`

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
