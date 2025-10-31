/**
 * File Operations Utilities for Plugin-Expert
 * Safe file operations with backup capabilities
 * Layer 1: Atomic Utility (no dependencies on other helpers)
 */

const fs = require('fs');
const path = require('path');

/**
 * Create a backup of a file
 * @param {string} filePath - Path to file to backup
 * @returns {string} Path to backup file
 */
function createBackup(filePath) {
  if (!fs.existsSync(filePath)) {
    return null;
  }

  const dir = path.dirname(filePath);
  const ext = path.extname(filePath);
  const base = path.basename(filePath, ext);

  let backupPath;
  let counter = 0;

  // Find an available backup filename
  do {
    const suffix = counter === 0 ? '.bak' : `.bak${counter}`;
    backupPath = path.join(dir, base + suffix + ext);
    counter++;
  } while (fs.existsSync(backupPath) && counter < 100);

  fs.copyFileSync(filePath, backupPath);
  return backupPath;
}

/**
 * Safely write a file (with optional backup)
 * @param {string} filePath - Path to file
 * @param {string} content - Content to write
 * @param {boolean} backup - Create backup if file exists
 * @returns {object} Result with status and backup path if created
 */
function safeWrite(filePath, content, backup = true) {
  const result = {
    success: false,
    backupPath: null,
    error: null
  };

  try {
    // Create directory if needed
    const dir = path.dirname(filePath);
    if (!fs.existsSync(dir)) {
      fs.mkdirSync(dir, { recursive: true });
    }

    // Create backup if requested and file exists
    if (backup && fs.existsSync(filePath)) {
      result.backupPath = createBackup(filePath);
    }

    // Write the file
    fs.writeFileSync(filePath, content);
    result.success = true;
  } catch (error) {
    result.error = error.message;
  }

  return result;
}

/**
 * Read a file safely
 * @param {string} filePath - Path to file
 * @returns {object} Result with content or error
 */
function safeRead(filePath) {
  const result = {
    success: false,
    content: null,
    error: null
  };

  try {
    if (!fs.existsSync(filePath)) {
      result.error = `File not found: ${filePath}`;
      return result;
    }

    result.content = fs.readFileSync(filePath, 'utf8');
    result.success = true;
  } catch (error) {
    result.error = error.message;
  }

  return result;
}

/**
 * Ensure a directory exists (create if needed)
 * @param {string} dirPath - Path to directory
 * @returns {boolean} True if directory exists or was created
 */
function ensureDir(dirPath) {
  try {
    if (!fs.existsSync(dirPath)) {
      fs.mkdirSync(dirPath, { recursive: true });
    }
    return true;
  } catch {
    return false;
  }
}

/**
 * Copy a file or directory recursively
 * @param {string} src - Source path
 * @param {string} dest - Destination path
 * @returns {boolean} True if successful
 */
function copyRecursive(src, dest) {
  try {
    const stat = fs.statSync(src);

    if (stat.isDirectory()) {
      // Create destination directory
      if (!fs.existsSync(dest)) {
        fs.mkdirSync(dest, { recursive: true });
      }

      // Copy all contents
      const files = fs.readdirSync(src);
      for (const file of files) {
        const srcPath = path.join(src, file);
        const destPath = path.join(dest, file);
        copyRecursive(srcPath, destPath);
      }
    } else {
      // Copy file
      fs.copyFileSync(src, dest);
    }

    return true;
  } catch {
    return false;
  }
}

/**
 * Delete a file or directory recursively
 * @param {string} targetPath - Path to delete
 * @returns {boolean} True if successful
 */
function deleteRecursive(targetPath) {
  try {
    if (!fs.existsSync(targetPath)) {
      return true;
    }

    const stat = fs.statSync(targetPath);

    if (stat.isDirectory()) {
      fs.rmSync(targetPath, { recursive: true, force: true });
    } else {
      fs.unlinkSync(targetPath);
    }

    return true;
  } catch {
    return false;
  }
}

/**
 * List all files in a directory matching a pattern
 * @param {string} dirPath - Directory to search
 * @param {RegExp|string} pattern - Pattern to match (string becomes glob-like)
 * @param {boolean} recursive - Search subdirectories
 * @returns {array} Array of matching file paths
 */
function listFiles(dirPath, pattern = null, recursive = false) {
  const files = [];

  if (!fs.existsSync(dirPath)) {
    return files;
  }

  // Convert string pattern to regex (simple glob support)
  let regex = null;
  if (pattern) {
    if (typeof pattern === 'string') {
      const escaped = pattern
        .replace(/[.+^${}()|[\]\\]/g, '\\$&')
        .replace(/\*/g, '.*')
        .replace(/\?/g, '.');
      regex = new RegExp('^' + escaped + '$');
    } else {
      regex = pattern;
    }
  }

  function walk(dir) {
    const entries = fs.readdirSync(dir, { withFileTypes: true });

    for (const entry of entries) {
      const fullPath = path.join(dir, entry.name);

      if (entry.isDirectory() && recursive) {
        walk(fullPath);
      } else if (entry.isFile()) {
        if (!regex || regex.test(entry.name)) {
          files.push(fullPath);
        }
      }
    }
  }

  walk(dirPath);
  return files;
}

/**
 * Get file statistics
 * @param {string} filePath - Path to file
 * @returns {object} File stats or null if not found
 */
function getFileStats(filePath) {
  try {
    const stats = fs.statSync(filePath);
    return {
      size: stats.size,
      created: stats.birthtime,
      modified: stats.mtime,
      isDirectory: stats.isDirectory(),
      isFile: stats.isFile()
    };
  } catch {
    return null;
  }
}

/**
 * Check if path exists
 * @param {string} targetPath - Path to check
 * @returns {boolean} True if exists
 */
function exists(targetPath) {
  return fs.existsSync(targetPath);
}

/**
 * Check if path is a directory
 * @param {string} targetPath - Path to check
 * @returns {boolean} True if directory
 */
function isDirectory(targetPath) {
  try {
    return fs.statSync(targetPath).isDirectory();
  } catch {
    return false;
  }
}

/**
 * Check if path is a file
 * @param {string} targetPath - Path to check
 * @returns {boolean} True if file
 */
function isFile(targetPath) {
  try {
    return fs.statSync(targetPath).isFile();
  } catch {
    return false;
  }
}

/**
 * Move/rename a file or directory
 * @param {string} src - Source path
 * @param {string} dest - Destination path
 * @returns {boolean} True if successful
 */
function move(src, dest) {
  try {
    fs.renameSync(src, dest);
    return true;
  } catch {
    // If rename fails (cross-device), try copy and delete
    if (copyRecursive(src, dest)) {
      return deleteRecursive(src);
    }
    return false;
  }
}

module.exports = {
  createBackup,
  safeWrite,
  safeRead,
  ensureDir,
  copyRecursive,
  deleteRecursive,
  listFiles,
  getFileStats,
  exists,
  isDirectory,
  isFile,
  move
};