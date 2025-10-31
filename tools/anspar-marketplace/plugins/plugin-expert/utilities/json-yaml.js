/**
 * JSON/YAML Serialization Utilities for Plugin-Expert
 * Handle configuration file parsing and generation
 * Layer 1: Atomic Utility (no dependencies on other helpers)
 */

const fs = require('fs');

/**
 * Parse JSON with better error reporting
 * @param {string} content - JSON string to parse
 * @param {string} context - Context for error messages
 * @returns {object} Parsed object or error details
 */
function parseJSON(content, context = 'JSON') {
  try {
    return {
      success: true,
      data: JSON.parse(content),
      error: null
    };
  } catch (error) {
    // Extract line/column from error message if available
    const match = error.message.match(/position (\d+)/);
    const position = match ? parseInt(match[1]) : 0;

    // Find line and column from position
    let line = 1;
    let column = 1;
    if (position > 0) {
      const lines = content.substring(0, position).split('\n');
      line = lines.length;
      column = lines[lines.length - 1].length + 1;
    }

    return {
      success: false,
      data: null,
      error: {
        message: error.message,
        line,
        column,
        context
      }
    };
  }
}

/**
 * Stringify JSON with formatting options
 * @param {object} obj - Object to stringify
 * @param {object} options - Formatting options
 * @returns {string} JSON string
 */
function stringifyJSON(obj, options = {}) {
  const {
    indent = 2,
    sortKeys = false,
    compact = false
  } = options;

  // Sort keys if requested
  if (sortKeys) {
    obj = sortObjectKeys(obj);
  }

  // Stringify with options
  if (compact) {
    return JSON.stringify(obj);
  } else {
    return JSON.stringify(obj, null, indent);
  }
}

/**
 * Sort object keys recursively
 * @param {object} obj - Object to sort
 * @returns {object} New object with sorted keys
 */
function sortObjectKeys(obj) {
  if (obj === null || typeof obj !== 'object') {
    return obj;
  }

  if (Array.isArray(obj)) {
    return obj.map(sortObjectKeys);
  }

  const sorted = {};
  const keys = Object.keys(obj).sort();

  for (const key of keys) {
    sorted[key] = sortObjectKeys(obj[key]);
  }

  return sorted;
}

/**
 * Read and parse a JSON file
 * @param {string} filePath - Path to JSON file
 * @returns {object} Parsed data or error
 */
function readJSONFile(filePath) {
  try {
    if (!fs.existsSync(filePath)) {
      return {
        success: false,
        data: null,
        error: `File not found: ${filePath}`
      };
    }

    const content = fs.readFileSync(filePath, 'utf8');
    return parseJSON(content, filePath);
  } catch (error) {
    return {
      success: false,
      data: null,
      error: error.message
    };
  }
}

/**
 * Write object to JSON file
 * @param {string} filePath - Path to JSON file
 * @param {object} data - Data to write
 * @param {object} options - Formatting options
 * @returns {boolean} Success status
 */
function writeJSONFile(filePath, data, options = {}) {
  try {
    const content = stringifyJSON(data, options);
    fs.writeFileSync(filePath, content);
    return true;
  } catch {
    return false;
  }
}

/**
 * Deep merge objects (for configuration merging)
 * @param {object} target - Target object
 * @param {object} source - Source object to merge
 * @returns {object} Merged object
 */
function deepMerge(target, source) {
  const result = { ...target };

  for (const key in source) {
    if (source.hasOwnProperty(key)) {
      if (source[key] && typeof source[key] === 'object' && !Array.isArray(source[key])) {
        if (result[key] && typeof result[key] === 'object' && !Array.isArray(result[key])) {
          result[key] = deepMerge(result[key], source[key]);
        } else {
          result[key] = source[key];
        }
      } else {
        result[key] = source[key];
      }
    }
  }

  return result;
}

/**
 * Deep clone an object
 * @param {object} obj - Object to clone
 * @returns {object} Cloned object
 */
function deepClone(obj) {
  if (obj === null || typeof obj !== 'object') {
    return obj;
  }

  if (obj instanceof Date) {
    return new Date(obj.getTime());
  }

  if (Array.isArray(obj)) {
    return obj.map(item => deepClone(item));
  }

  const cloned = {};
  for (const key in obj) {
    if (obj.hasOwnProperty(key)) {
      cloned[key] = deepClone(obj[key]);
    }
  }

  return cloned;
}

/**
 * Get value from object using dot notation path
 * @param {object} obj - Object to query
 * @param {string} path - Dot notation path (e.g., 'author.name')
 * @param {any} defaultValue - Default value if not found
 * @returns {any} Value at path or default
 */
function getByPath(obj, path, defaultValue = null) {
  const parts = path.split('.');
  let current = obj;

  for (const part of parts) {
    if (current && typeof current === 'object' && part in current) {
      current = current[part];
    } else {
      return defaultValue;
    }
  }

  return current;
}

/**
 * Set value in object using dot notation path
 * @param {object} obj - Object to modify
 * @param {string} path - Dot notation path
 * @param {any} value - Value to set
 * @returns {object} Modified object
 */
function setByPath(obj, path, value) {
  const parts = path.split('.');
  const last = parts.pop();
  let current = obj;

  for (const part of parts) {
    if (!(part in current) || typeof current[part] !== 'object') {
      current[part] = {};
    }
    current = current[part];
  }

  current[last] = value;
  return obj;
}

/**
 * Remove empty values from object recursively
 * @param {object} obj - Object to clean
 * @returns {object} Cleaned object
 */
function removeEmpty(obj) {
  if (obj === null || typeof obj !== 'object') {
    return obj;
  }

  if (Array.isArray(obj)) {
    return obj
      .map(removeEmpty)
      .filter(item => item !== null && item !== undefined && item !== '');
  }

  const cleaned = {};
  for (const key in obj) {
    if (obj.hasOwnProperty(key)) {
      const value = removeEmpty(obj[key]);

      if (value !== null && value !== undefined && value !== '') {
        if (typeof value === 'object' && !Array.isArray(value)) {
          if (Object.keys(value).length > 0) {
            cleaned[key] = value;
          }
        } else if (Array.isArray(value)) {
          if (value.length > 0) {
            cleaned[key] = value;
          }
        } else {
          cleaned[key] = value;
        }
      }
    }
  }

  return cleaned;
}

/**
 * Validate object against a simple schema
 * @param {object} obj - Object to validate
 * @param {object} schema - Schema definition
 * @returns {object} Validation result
 */
function validateSchema(obj, schema) {
  const errors = [];

  function validate(obj, schema, path = '') {
    for (const key in schema) {
      const fullPath = path ? `${path}.${key}` : key;
      const rule = schema[key];
      const value = obj ? obj[key] : undefined;

      if (rule.required && (value === undefined || value === null)) {
        errors.push(`${fullPath} is required`);
        continue;
      }

      if (value !== undefined && value !== null) {
        if (rule.type) {
          const actualType = Array.isArray(value) ? 'array' : typeof value;
          if (actualType !== rule.type) {
            errors.push(`${fullPath} must be of type ${rule.type}, got ${actualType}`);
            continue;
          }
        }

        if (rule.enum && !rule.enum.includes(value)) {
          errors.push(`${fullPath} must be one of: ${rule.enum.join(', ')}`);
        }

        if (rule.minLength && value.length < rule.minLength) {
          errors.push(`${fullPath} must be at least ${rule.minLength} characters`);
        }

        if (rule.maxLength && value.length > rule.maxLength) {
          errors.push(`${fullPath} must be at most ${rule.maxLength} characters`);
        }

        if (rule.pattern && !rule.pattern.test(value)) {
          errors.push(`${fullPath} has invalid format`);
        }

        if (rule.properties && typeof value === 'object') {
          validate(value, rule.properties, fullPath);
        }
      }
    }
  }

  validate(obj, schema);

  return {
    valid: errors.length === 0,
    errors
  };
}

module.exports = {
  parseJSON,
  stringifyJSON,
  sortObjectKeys,
  readJSONFile,
  writeJSONFile,
  deepMerge,
  deepClone,
  getByPath,
  setByPath,
  removeEmpty,
  validateSchema
};