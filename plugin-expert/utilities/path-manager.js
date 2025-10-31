/**
 * Path Manager for Plugin-Expert
 * Centralized path management to prevent path-related errors
 * Layer 1: Atomic Utility (no dependencies on other helpers)
 */

const path = require('path');
const fs = require('fs');

/**
 * PathManager class to maintain consistent paths throughout plugin operations
 */
class PathManager {
  constructor(basePath = null) {
    // Set the base path (defaults to current working directory)
    this.basePath = basePath ? path.resolve(basePath) : process.cwd();

    // Cache for validated paths
    this.pathCache = new Map();

    // Standard plugin directories
    this.standardDirs = {
      plugin: '.claude-plugin',
      commands: 'commands',
      agents: 'agents',
      skills: 'skills',
      hooks: 'hooks',
      tests: 'tests',
      docs: 'docs'
    };
  }

  /**
   * Get the base path
   * @returns {string} Absolute base path
   */
  getBasePath() {
    return this.basePath;
  }

  /**
   * Set a new base path
   * @param {string} newPath - New base path
   * @returns {PathManager} This instance for chaining
   */
  setBasePath(newPath) {
    this.basePath = path.resolve(newPath);
    this.pathCache.clear(); // Clear cache when base changes
    return this;
  }

  /**
   * Resolve a path relative to the base path
   * @param {...string} segments - Path segments to join
   * @returns {string} Absolute path
   */
  resolve(...segments) {
    if (segments.length === 0) {
      return this.basePath;
    }

    // If first segment is absolute, don't use base path
    if (path.isAbsolute(segments[0])) {
      return path.resolve(...segments);
    }

    return path.resolve(this.basePath, ...segments);
  }

  /**
   * Get a path relative to the base path
   * @param {string} targetPath - Path to make relative
   * @returns {string} Relative path
   */
  relative(targetPath) {
    return path.relative(this.basePath, targetPath);
  }

  /**
   * Join path segments (without resolving to absolute)
   * @param {...string} segments - Path segments
   * @returns {string} Joined path
   */
  join(...segments) {
    return path.join(...segments);
  }

  /**
   * Get the directory path for a standard plugin component
   * @param {string} component - Component name (commands, agents, skills, etc.)
   * @returns {string} Absolute path to component directory
   */
  getComponentPath(component) {
    const dir = this.standardDirs[component];
    if (!dir) {
      throw new Error(`Unknown component: ${component}. Valid components: ${Object.keys(this.standardDirs).join(', ')}`);
    }

    return this.resolve(dir);
  }

  /**
   * Get the plugin config directory path
   * @returns {string} Absolute path to .claude-plugin directory
   */
  getConfigPath() {
    return this.resolve(this.standardDirs.plugin);
  }

  /**
   * Get the path to a specific config file
   * @param {string} filename - Config filename
   * @returns {string} Absolute path to config file
   */
  getConfigFilePath(filename = 'plugin.json') {
    return this.resolve(this.standardDirs.plugin, filename);
  }

  /**
   * Ensure a directory exists (create if needed)
   * @param {...string} segments - Path segments
   * @returns {string} Absolute path to directory
   */
  ensureDir(...segments) {
    const dirPath = this.resolve(...segments);

    if (!fs.existsSync(dirPath)) {
      fs.mkdirSync(dirPath, { recursive: true });
    }

    return dirPath;
  }

  /**
   * Check if a path exists
   * @param {...string} segments - Path segments
   * @returns {boolean} True if path exists
   */
  exists(...segments) {
    const targetPath = this.resolve(...segments);
    return fs.existsSync(targetPath);
  }

  /**
   * Check if a path is within the base path (prevent directory traversal)
   * @param {string} targetPath - Path to check
   * @returns {boolean} True if path is safe
   */
  isSafePath(targetPath) {
    const resolved = path.resolve(this.basePath, targetPath);
    const relative = path.relative(this.basePath, resolved);

    // Path is safe if it doesn't start with .. (parent directory)
    return !relative.startsWith('..') && !path.isAbsolute(relative);
  }

  /**
   * Validate and resolve a path (with safety checks)
   * @param {...string} segments - Path segments
   * @returns {object} Validation result
   */
  validatePath(...segments) {
    const targetPath = segments.length === 1 && path.isAbsolute(segments[0])
      ? segments[0]
      : this.resolve(...segments);

    const result = {
      valid: false,
      path: targetPath,
      exists: false,
      isDirectory: false,
      isFile: false,
      isSafe: true,
      error: null
    };

    try {
      // Check if path is safe (within base directory)
      if (!targetPath.startsWith(this.basePath)) {
        result.isSafe = false;
        result.error = 'Path is outside the plugin directory';
        return result;
      }

      result.exists = fs.existsSync(targetPath);

      if (result.exists) {
        const stats = fs.statSync(targetPath);
        result.isDirectory = stats.isDirectory();
        result.isFile = stats.isFile();
      }

      result.valid = true;
    } catch (error) {
      result.error = error.message;
    }

    return result;
  }

  /**
   * Get or create a cached path
   * @param {string} key - Cache key
   * @param {function} pathGenerator - Function to generate path if not cached
   * @returns {string} Cached or generated path
   */
  getCachedPath(key, pathGenerator) {
    if (this.pathCache.has(key)) {
      return this.pathCache.get(key);
    }

    const generatedPath = pathGenerator();
    this.pathCache.set(key, generatedPath);
    return generatedPath;
  }

  /**
   * Create a full plugin directory structure
   * @returns {object} Created directories
   */
  createPluginStructure() {
    const created = {};

    // Create all standard directories
    for (const [key, dir] of Object.entries(this.standardDirs)) {
      created[key] = this.ensureDir(dir);
    }

    return created;
  }

  /**
   * Get file path for a component item (e.g., specific command, agent, skill)
   * @param {string} component - Component type
   * @param {string} name - Item name
   * @param {string} extension - File extension
   * @returns {string} Full file path
   */
  getComponentItemPath(component, name, extension = '.md') {
    const componentPath = this.getComponentPath(component);

    // Special handling for skills (they're directories with SKILL.md)
    if (component === 'skills') {
      return this.resolve(componentPath, name, 'SKILL.md');
    }

    // Add extension if not present
    if (!name.endsWith(extension)) {
      name += extension;
    }

    return this.resolve(componentPath, name);
  }

  /**
   * List all items in a component directory
   * @param {string} component - Component type
   * @returns {array} List of item names
   */
  listComponentItems(component) {
    const componentPath = this.getComponentPath(component);

    if (!fs.existsSync(componentPath)) {
      return [];
    }

    const items = fs.readdirSync(componentPath, { withFileTypes: true });

    if (component === 'skills') {
      // For skills, look for directories containing SKILL.md
      return items
        .filter(item => item.isDirectory())
        .filter(dir => fs.existsSync(this.resolve(componentPath, dir.name, 'SKILL.md')))
        .map(dir => dir.name);
    } else {
      // For other components, look for .md files
      return items
        .filter(item => item.isFile() && item.name.endsWith('.md'))
        .map(file => path.basename(file.name, '.md'));
    }
  }

  /**
   * Get all paths for a plugin
   * @returns {object} Object with all relevant paths
   */
  getAllPaths() {
    return {
      base: this.basePath,
      config: this.getConfigPath(),
      pluginJson: this.getConfigFilePath('plugin.json'),
      marketplaceJson: this.getConfigFilePath('marketplace.json'),
      commands: this.getComponentPath('commands'),
      agents: this.getComponentPath('agents'),
      skills: this.getComponentPath('skills'),
      hooks: this.getComponentPath('hooks'),
      tests: this.getComponentPath('tests'),
      docs: this.getComponentPath('docs')
    };
  }

  /**
   * Change to plugin directory and execute a function
   * @param {function} fn - Function to execute in plugin directory
   * @returns {any} Function result
   */
  inPluginDir(fn) {
    const originalDir = process.cwd();
    try {
      process.chdir(this.basePath);
      return fn();
    } finally {
      process.chdir(originalDir);
    }
  }

  /**
   * Create a new PathManager for a subdirectory
   * @param {...string} segments - Path segments for subdirectory
   * @returns {PathManager} New PathManager instance
   */
  createSubManager(...segments) {
    return new PathManager(this.resolve(...segments));
  }

  /**
   * Get a formatted path for display (relative if within base)
   * @param {string} targetPath - Path to format
   * @returns {string} Formatted path
   */
  displayPath(targetPath) {
    if (targetPath.startsWith(this.basePath)) {
      return './' + this.relative(targetPath);
    }
    return targetPath;
  }
}

/**
 * Create a singleton instance for global use
 */
let globalPathManager = null;

/**
 * Get or create the global PathManager instance
 * @param {string} basePath - Base path (only used on first call)
 * @returns {PathManager} Global PathManager instance
 */
function getGlobalPathManager(basePath = null) {
  if (!globalPathManager) {
    globalPathManager = new PathManager(basePath);
  }
  return globalPathManager;
}

/**
 * Reset the global PathManager
 */
function resetGlobalPathManager() {
  globalPathManager = null;
}

module.exports = {
  PathManager,
  getGlobalPathManager,
  resetGlobalPathManager
};