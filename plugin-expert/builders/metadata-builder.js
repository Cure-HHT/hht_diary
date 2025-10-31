/**
 * Metadata Builder for Plugin-Expert
 * Builds plugin.json and marketplace.json metadata
 * Layer 2: Component Builder (depends only on Layer 1 utilities)
 */

const { isValidPluginName, isValidVersion, isValidDescription, isValidEmail } = require('../utilities/validation');
const { toKebabCase, capitalize, truncate } = require('../utilities/string-helpers');
const { deepMerge, removeEmpty, sortObjectKeys } = require('../utilities/json-yaml');

/**
 * Build plugin.json metadata from user specifications
 * @param {object} spec - Plugin specifications
 * @returns {object} Plugin metadata object
 */
function buildPluginMetadata(spec) {
  const metadata = {
    name: '',
    version: '1.0.0',
    description: '',
    author: {},
    ...spec
  };

  // Validate and normalize name
  if (spec.name) {
    const normalizedName = toKebabCase(spec.name);
    if (!isValidPluginName(normalizedName)) {
      throw new Error(`Invalid plugin name: ${normalizedName}. Must be kebab-case with alphanumeric characters and dashes.`);
    }
    metadata.name = normalizedName;
  } else {
    throw new Error('Plugin name is required');
  }

  // Validate version
  if (spec.version) {
    if (!isValidVersion(spec.version)) {
      throw new Error(`Invalid version: ${spec.version}. Must be semantic version (e.g., 1.0.0)`);
    }
    metadata.version = spec.version;
  }

  // Validate and truncate description
  if (spec.description) {
    if (!isValidDescription(spec.description, 500)) {
      throw new Error('Description must be non-empty and under 500 characters');
    }
    metadata.description = truncate(spec.description, 500);
  } else {
    throw new Error('Plugin description is required');
  }

  // Build author metadata
  metadata.author = buildAuthorMetadata(spec.author);

  // Add optional fields
  const optionalFields = ['keywords', 'repository', 'homepage', 'bugs', 'license'];
  for (const field of optionalFields) {
    if (spec[field]) {
      metadata[field] = spec[field];
    }
  }

  // Add Claude Code specific fields
  if (spec.claudeCode) {
    metadata.claudeCode = {
      minVersion: spec.claudeCode.minVersion || '1.0.0',
      maxVersion: spec.claudeCode.maxVersion,
      ...spec.claudeCode
    };
  }

  // Remove empty values and sort keys
  return sortObjectKeys(removeEmpty(metadata));
}

/**
 * Build author metadata
 * @param {object|string} author - Author information
 * @returns {object} Normalized author object
 */
function buildAuthorMetadata(author) {
  if (!author) {
    throw new Error('Author information is required');
  }

  // Handle string format: "Name <email@example.com>"
  if (typeof author === 'string') {
    const match = author.match(/^([^<]+?)(?:\s*<([^>]+)>)?$/);
    if (match) {
      const authorObj = { name: match[1].trim() };
      if (match[2]) {
        authorObj.email = match[2].trim();
      }
      return authorObj;
    }
    return { name: author.trim() };
  }

  // Handle object format
  const authorObj = { ...author };

  if (!authorObj.name || authorObj.name.trim().length === 0) {
    throw new Error('Author name is required');
  }

  authorObj.name = authorObj.name.trim();

  if (authorObj.email) {
    if (!isValidEmail(authorObj.email)) {
      throw new Error(`Invalid author email: ${authorObj.email}`);
    }
  }

  return removeEmpty(authorObj);
}

/**
 * Build marketplace.json metadata
 * @param {object} spec - Marketplace specifications
 * @returns {object} Marketplace metadata object
 */
function buildMarketplaceMetadata(spec) {
  const marketplace = {
    name: spec.name || 'plugin-marketplace',
    description: spec.description || 'A Claude Code plugin marketplace',
    owner: buildAuthorMetadata(spec.owner || spec.author),
    plugins: []
  };

  // Add plugins to marketplace
  if (spec.plugins && Array.isArray(spec.plugins)) {
    for (const plugin of spec.plugins) {
      marketplace.plugins.push(buildMarketplacePlugin(plugin));
    }
  }

  // Add optional fields
  if (spec.repository) {
    marketplace.repository = spec.repository;
  }

  if (spec.homepage) {
    marketplace.homepage = spec.homepage;
  }

  return sortObjectKeys(removeEmpty(marketplace));
}

/**
 * Build marketplace plugin entry
 * @param {object|string} plugin - Plugin configuration
 * @returns {object} Plugin entry for marketplace
 */
function buildMarketplacePlugin(plugin) {
  if (typeof plugin === 'string') {
    // Simple format: just plugin name
    return {
      name: toKebabCase(plugin),
      source: `./${toKebabCase(plugin)}`
    };
  }

  // Object format with more details
  const entry = {
    name: toKebabCase(plugin.name),
    source: plugin.source || `./${toKebabCase(plugin.name)}`
  };

  // Optional fields
  if (plugin.version) {
    entry.version = plugin.version;
  }

  if (plugin.description) {
    entry.description = truncate(plugin.description, 200);
  }

  if (plugin.tags && Array.isArray(plugin.tags)) {
    entry.tags = plugin.tags;
  }

  return removeEmpty(entry);
}

/**
 * Generate default metadata for a new plugin
 * @param {string} name - Plugin name
 * @returns {object} Default metadata
 */
function generateDefaultMetadata(name) {
  const normalizedName = toKebabCase(name);
  const displayName = normalizedName
    .split('-')
    .map(word => capitalize(word))
    .join(' ');

  return {
    name: normalizedName,
    version: '1.0.0',
    description: `${displayName} plugin for Claude Code`,
    author: {
      name: 'Unknown'
    }
  };
}

/**
 * Merge plugin metadata with defaults
 * @param {object} metadata - User provided metadata
 * @param {object} defaults - Default values
 * @returns {object} Merged metadata
 */
function mergeWithDefaults(metadata, defaults = null) {
  if (!defaults) {
    defaults = generateDefaultMetadata(metadata.name || 'unnamed-plugin');
  }

  return deepMerge(defaults, metadata);
}

/**
 * Extract metadata from existing plugin.json content
 * @param {string} content - JSON content
 * @returns {object} Extracted metadata
 */
function extractMetadata(content) {
  try {
    const data = JSON.parse(content);
    return {
      name: data.name,
      version: data.version,
      description: data.description,
      author: data.author,
      keywords: data.keywords,
      repository: data.repository,
      homepage: data.homepage,
      license: data.license
    };
  } catch (error) {
    throw new Error(`Failed to parse plugin metadata: ${error.message}`);
  }
}

/**
 * Update version in metadata (with bump options)
 * @param {object} metadata - Current metadata
 * @param {string} bump - Version bump type: 'major', 'minor', 'patch', or specific version
 * @returns {object} Updated metadata
 */
function updateVersion(metadata, bump = 'patch') {
  if (!metadata.version) {
    metadata.version = '1.0.0';
    return metadata;
  }

  // If specific version provided
  if (isValidVersion(bump)) {
    metadata.version = bump;
    return metadata;
  }

  // Parse current version
  const match = metadata.version.match(/^(\d+)\.(\d+)\.(\d+)/);
  if (!match) {
    throw new Error(`Invalid current version: ${metadata.version}`);
  }

  let [, major, minor, patch] = match.map(Number);

  // Bump version based on type
  switch (bump.toLowerCase()) {
    case 'major':
      major++;
      minor = 0;
      patch = 0;
      break;
    case 'minor':
      minor++;
      patch = 0;
      break;
    case 'patch':
      patch++;
      break;
    default:
      throw new Error(`Invalid version bump type: ${bump}. Use 'major', 'minor', 'patch', or a specific version.`);
  }

  metadata.version = `${major}.${minor}.${patch}`;
  return metadata;
}

module.exports = {
  buildPluginMetadata,
  buildAuthorMetadata,
  buildMarketplaceMetadata,
  buildMarketplacePlugin,
  generateDefaultMetadata,
  mergeWithDefaults,
  extractMetadata,
  updateVersion
};