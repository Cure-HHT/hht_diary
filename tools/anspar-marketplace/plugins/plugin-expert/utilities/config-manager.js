/**
 * Configuration Manager for Plugin-Expert
 * Handles reading/writing plugin configuration values
 * Layer 1: Atomic Utility (no dependencies on other helpers)
 */

const fs = require('fs');
const path = require('path');

class ConfigManager {
  constructor(pluginPath) {
    this.pluginPath = pluginPath;
    this.configPath = path.join(pluginPath, '.claude-plugin', 'plugin.json');
    this.marketplacePath = path.join(pluginPath, '.claude-plugin', 'marketplace.json');
  }

  /**
   * Ensures the .claude-plugin directory exists
   */
  ensureConfigDir() {
    const dir = path.join(this.pluginPath, '.claude-plugin');
    if (!fs.existsSync(dir)) {
      fs.mkdirSync(dir, { recursive: true });
    }
    return dir;
  }

  /**
   * Read plugin.json configuration
   */
  readPluginConfig() {
    if (!fs.existsSync(this.configPath)) {
      return null;
    }
    const content = fs.readFileSync(this.configPath, 'utf8');
    return JSON.parse(content);
  }

  /**
   * Write plugin.json configuration
   */
  writePluginConfig(config) {
    this.ensureConfigDir();
    const content = JSON.stringify(config, null, 2);
    fs.writeFileSync(this.configPath, content);
    return config;
  }

  /**
   * Update specific fields in plugin.json
   */
  updatePluginConfig(updates) {
    const current = this.readPluginConfig() || {};
    const updated = { ...current, ...updates };
    return this.writePluginConfig(updated);
  }

  /**
   * Read marketplace.json configuration
   */
  readMarketplaceConfig() {
    if (!fs.existsSync(this.marketplacePath)) {
      return null;
    }
    const content = fs.readFileSync(this.marketplacePath, 'utf8');
    return JSON.parse(content);
  }

  /**
   * Write marketplace.json configuration
   */
  writeMarketplaceConfig(config) {
    this.ensureConfigDir();
    const content = JSON.stringify(config, null, 2);
    fs.writeFileSync(this.marketplacePath, content);
    return config;
  }

  /**
   * Get a specific config value with dot notation
   * Example: getValue('author.name')
   */
  getValue(path) {
    const config = this.readPluginConfig();
    if (!config) return null;

    const parts = path.split('.');
    let value = config;
    for (const part of parts) {
      if (value && typeof value === 'object') {
        value = value[part];
      } else {
        return null;
      }
    }
    return value;
  }

  /**
   * Set a specific config value with dot notation
   * Example: setValue('author.name', 'John Doe')
   */
  setValue(path, value) {
    const config = this.readPluginConfig() || {};
    const parts = path.split('.');
    const lastPart = parts.pop();

    let current = config;
    for (const part of parts) {
      if (!current[part] || typeof current[part] !== 'object') {
        current[part] = {};
      }
      current = current[part];
    }
    current[lastPart] = value;

    return this.writePluginConfig(config);
  }

  /**
   * Check if plugin configuration exists
   */
  exists() {
    return fs.existsSync(this.configPath);
  }

  /**
   * Initialize a new plugin configuration with defaults
   */
  initialize(defaults = {}) {
    const baseConfig = {
      name: 'unnamed-plugin',
      version: '1.0.0',
      description: 'A Claude Code plugin',
      author: { name: 'Unknown' },
      ...defaults
    };
    return this.writePluginConfig(baseConfig);
  }
}

module.exports = ConfigManager;