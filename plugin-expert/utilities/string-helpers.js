/**
 * String Helper Utilities for Plugin-Expert
 * Template strings, naming conventions, and text transformations
 * Layer 1: Atomic Utility (no dependencies on other helpers)
 */

/**
 * Convert string to kebab-case (lowercase with dashes)
 * @param {string} str - String to convert
 * @returns {string} Kebab-case string
 */
function toKebabCase(str) {
  return str
    .replace(/([a-z])([A-Z])/g, '$1-$2')
    .replace(/[\s_]+/g, '-')
    .toLowerCase()
    .replace(/[^a-z0-9-]/g, '')
    .replace(/-+/g, '-')
    .replace(/^-|-$/g, '');
}

/**
 * Convert string to PascalCase
 * @param {string} str - String to convert
 * @returns {string} PascalCase string
 */
function toPascalCase(str) {
  return str
    .replace(/[-_\s]+(.)?/g, (_, char) => char ? char.toUpperCase() : '')
    .replace(/^(.)/, (_, char) => char.toUpperCase());
}

/**
 * Convert string to camelCase
 * @param {string} str - String to convert
 * @returns {string} camelCase string
 */
function toCamelCase(str) {
  const pascal = toPascalCase(str);
  return pascal.charAt(0).toLowerCase() + pascal.slice(1);
}

/**
 * Convert string to SCREAMING_SNAKE_CASE
 * @param {string} str - String to convert
 * @returns {string} SCREAMING_SNAKE_CASE string
 */
function toScreamingSnakeCase(str) {
  return str
    .replace(/([a-z])([A-Z])/g, '$1_$2')
    .replace(/[\s-]+/g, '_')
    .toUpperCase()
    .replace(/[^A-Z0-9_]/g, '')
    .replace(/_+/g, '_')
    .replace(/^_|_$/g, '');
}

/**
 * Truncate string to maximum length with ellipsis
 * @param {string} str - String to truncate
 * @param {number} maxLength - Maximum length
 * @param {string} suffix - Suffix to add (default: '...')
 * @returns {string} Truncated string
 */
function truncate(str, maxLength, suffix = '...') {
  if (str.length <= maxLength) return str;
  const truncLength = maxLength - suffix.length;
  if (truncLength <= 0) return suffix;
  return str.slice(0, truncLength) + suffix;
}

/**
 * Indent text with specified prefix
 * @param {string} text - Text to indent
 * @param {string} prefix - Prefix for each line (default: '  ')
 * @returns {string} Indented text
 */
function indent(text, prefix = '  ') {
  return text
    .split('\n')
    .map(line => line.length > 0 ? prefix + line : line)
    .join('\n');
}

/**
 * Wrap text at specified width
 * @param {string} text - Text to wrap
 * @param {number} width - Maximum line width
 * @returns {string} Wrapped text
 */
function wordWrap(text, width = 80) {
  const words = text.split(/\s+/);
  const lines = [];
  let currentLine = [];
  let currentLength = 0;

  for (const word of words) {
    if (currentLength + word.length + 1 > width && currentLine.length > 0) {
      lines.push(currentLine.join(' '));
      currentLine = [word];
      currentLength = word.length;
    } else {
      currentLine.push(word);
      currentLength += word.length + (currentLine.length > 1 ? 1 : 0);
    }
  }

  if (currentLine.length > 0) {
    lines.push(currentLine.join(' '));
  }

  return lines.join('\n');
}

/**
 * Template string replacement with object values
 * @param {string} template - Template string with {{key}} placeholders
 * @param {object} values - Object with replacement values
 * @returns {string} String with placeholders replaced
 */
function template(template, values) {
  return template.replace(/\{\{(\w+)\}\}/g, (match, key) => {
    return values.hasOwnProperty(key) ? values[key] : match;
  });
}

/**
 * Pluralize a word based on count
 * @param {number} count - Number of items
 * @param {string} singular - Singular form
 * @param {string} plural - Plural form (optional, adds 's' by default)
 * @returns {string} Pluralized string with count
 */
function pluralize(count, singular, plural = null) {
  const word = count === 1 ? singular : (plural || singular + 's');
  return `${count} ${word}`;
}

/**
 * Capitalize first letter of string
 * @param {string} str - String to capitalize
 * @returns {string} Capitalized string
 */
function capitalize(str) {
  if (!str) return str;
  return str.charAt(0).toUpperCase() + str.slice(1);
}

/**
 * Remove common prefixes from a name (e.g., 'create-', 'build-', 'generate-')
 * @param {string} name - Name to clean
 * @returns {string} Cleaned name
 */
function removeCommonPrefixes(name) {
  const prefixes = [
    'create-', 'build-', 'generate-', 'make-', 'new-',
    'init-', 'setup-', 'configure-', 'install-'
  ];

  for (const prefix of prefixes) {
    if (name.startsWith(prefix)) {
      return name.slice(prefix.length);
    }
  }
  return name;
}

/**
 * Generate a random ID string
 * @param {number} length - Length of ID (default: 8)
 * @returns {string} Random ID
 */
function generateId(length = 8) {
  const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
  let id = '';
  for (let i = 0; i < length; i++) {
    id += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return id;
}

/**
 * Escape special characters for use in markdown
 * @param {string} str - String to escape
 * @returns {string} Escaped string
 */
function escapeMarkdown(str) {
  return str.replace(/[*_`~\[\]()#+-=|{}.!]/g, '\\$&');
}

/**
 * Create a markdown code block
 * @param {string} code - Code content
 * @param {string} language - Language identifier
 * @returns {string} Markdown code block
 */
function codeBlock(code, language = '') {
  return '```' + language + '\n' + code + '\n```';
}

/**
 * Create a markdown link
 * @param {string} text - Link text
 * @param {string} url - Link URL
 * @returns {string} Markdown link
 */
function mdLink(text, url) {
  return `[${text}](${url})`;
}

/**
 * Create a markdown header
 * @param {string} text - Header text
 * @param {number} level - Header level (1-6)
 * @returns {string} Markdown header
 */
function mdHeader(text, level = 1) {
  const hashes = '#'.repeat(Math.min(Math.max(level, 1), 6));
  return `${hashes} ${text}`;
}

module.exports = {
  toKebabCase,
  toPascalCase,
  toCamelCase,
  toScreamingSnakeCase,
  truncate,
  indent,
  wordWrap,
  template,
  pluralize,
  capitalize,
  removeCommonPrefixes,
  generateId,
  escapeMarkdown,
  codeBlock,
  mdLink,
  mdHeader
};