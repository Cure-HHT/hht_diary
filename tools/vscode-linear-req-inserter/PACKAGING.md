# Packaging the Extension for Installation

This guide explains how to package the Linear Requirement Inserter extension as a `.vsix` file for installation in VS Code.

## Prerequisites

Install `vsce` (Visual Studio Code Extension manager):

```bash
npm install -g @vscode/vsce
```

## Build and Package

1. **Ensure dependencies are installed:**
   ```bash
   npm install
   ```

2. **Compile TypeScript:**
   ```bash
   npm run compile
   ```

3. **Package the extension:**
   ```bash
   vsce package
   ```

   This creates a `.vsix` file in the current directory, named something like:
   ```
   linear-req-inserter-0.1.0.vsix
   ```

   **Note:** The extension uses esbuild bundling for optimal packaging:
   - All code bundled into single `dist/extension.js` file (~1.3MB)
   - Includes @linear/sdk and all dependencies
   - Package reduced from 500+ files to ~10 files
   - No node_modules folder needed (everything bundled)
   - Production builds are minified for smaller size
   - The 1.3MB size is normal for bundled extensions with API SDKs

## Install the Extension

### Option 1: Via VS Code UI

1. Open VS Code
2. Go to Extensions view (`Ctrl+Shift+X`)
3. Click the `...` menu (top-right of Extensions panel)
4. Select **"Install from VSIX..."**
5. Browse to and select the `.vsix` file
6. Reload VS Code when prompted

### Option 2: Via Command Line

```bash
code --install-extension linear-req-inserter-0.1.0.vsix
```

## Configure After Installation

Once installed in your main VS Code instance:

1. Open your workspace (e.g., `/home/mclew/dev24/diary`)
2. Open Settings (`Ctrl+,`)
3. Search for "Linear Requirement Inserter"
4. Configure:
   - **API Token**: Your Linear API token
   - **Spec Path**: Path to your spec directory (e.g., `${workspaceFolder}/spec`)

## Usage

After installation, you can use the extension in three ways:

1. **Keyboard Shortcut**: Press `Ctrl+Shift+R` (or `Cmd+Shift+R` on Mac)
2. **Right-Click Menu**: Right-click in any file → "Insert Requirements from Linear Ticket"
3. **Command Palette**: `Ctrl+Shift+P` → "Insert Requirements from Linear Ticket"

## Updating the Extension

To update after making changes:

1. Make your code changes
2. Update version in `package.json` (e.g., `0.1.0` → `0.1.1`)
3. Recompile: `npm run compile`
4. Repackage: `vsce package`
5. Reinstall the new `.vsix` file

## Troubleshooting

**Issue: "Cannot find module" errors**
- Solution: Run `npm install` to ensure all dependencies are installed

**Issue: Extension not activating**
- Check Output panel (`View` → `Output`) and select "Extension Host"
- Look for error messages from the extension

**Issue: Commands not appearing**
- Reload VS Code: `Ctrl+Shift+P` → "Reload Window"
- Check that extension is enabled in Extensions view

**Issue: Linear API not authenticated**
- Verify your API token in Settings
- Get a new token from https://linear.app/settings/api if needed
