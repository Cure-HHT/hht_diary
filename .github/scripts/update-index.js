#!/usr/bin/env node

/**
 * IMPLEMENTS REQUIREMENTS:
 *   REQ-o00013: Requirements Format Validation
 *   REQ-p00020: System Validation and Traceability
 *
 * Updates spec/INDEX.md by claiming the next available REQ# for a given prefix.
 *
 * Inputs (via environment variables):
 *   REQ_PREFIX: p, o, or d
 *   REQ_FILE: filename containing the requirement (e.g., prd-security.md)
 *   REQ_TITLE: requirement title/description
 *
 * Outputs:
 *   Sets GitHub Actions output: new_req_id
 */

const fs = require('fs');
const path = require('path');

const INDEX_PATH = path.join(__dirname, '..', '..', 'spec', 'INDEX.md');

// Read inputs from environment
const prefix = process.env.REQ_PREFIX;
const file = process.env.REQ_FILE;
const title = process.env.REQ_TITLE;

if (!prefix || !file || !title) {
  console.error('Error: Missing required environment variables');
  console.error('Required: REQ_PREFIX, REQ_FILE, REQ_TITLE');
  process.exit(1);
}

if (!['p', 'o', 'd'].includes(prefix)) {
  console.error(`Error: Invalid prefix "${prefix}". Must be p, o, or d`);
  process.exit(1);
}

// Read INDEX.md
if (!fs.existsSync(INDEX_PATH)) {
  console.error(`Error: ${INDEX_PATH} does not exist`);
  process.exit(1);
}

const indexContent = fs.readFileSync(INDEX_PATH, 'utf8');
const lines = indexContent.split('\n');

// Find the highest REQ# for the given prefix
const reqPattern = new RegExp(`^\\| REQ-${prefix}(\\d{5})`, 'i');
let maxNum = 0;

for (const line of lines) {
  const match = line.match(reqPattern);
  if (match) {
    const num = parseInt(match[1], 10);
    if (num > maxNum) {
      maxNum = num;
    }
  }
}

// Generate next REQ#
const nextNum = maxNum + 1;
const newReqId = `REQ-${prefix}${String(nextNum).padStart(5, '0')}`;

// Find the insertion point (maintain sorted order)
// We need to insert after the last REQ with the same prefix
let insertIndex = -1;
for (let i = lines.length - 1; i >= 0; i--) {
  if (lines[i].match(reqPattern)) {
    insertIndex = i + 1;
    break;
  }
}

// If no existing REQ with this prefix, find where it should go based on prefix order (p, o, d)
if (insertIndex === -1) {
  const prefixOrder = ['p', 'o', 'd'];
  const currentPrefixIndex = prefixOrder.indexOf(prefix);

  // Find the last line of the previous prefix
  for (let prefixIdx = currentPrefixIndex - 1; prefixIdx >= 0; prefixIdx--) {
    const prevPrefix = prefixOrder[prefixIdx];
    const prevPattern = new RegExp(`^\\| REQ-${prevPrefix}\\d{5}`, 'i');

    for (let i = lines.length - 1; i >= 0; i--) {
      if (lines[i].match(prevPattern)) {
        insertIndex = i + 1;
        break;
      }
    }

    if (insertIndex !== -1) break;
  }

  // If still not found, insert after the table header separator
  if (insertIndex === -1) {
    for (let i = 0; i < lines.length; i++) {
      if (lines[i].match(/^\|[-:\s|]+\|$/)) {
        insertIndex = i + 1;
        break;
      }
    }
  }
}

if (insertIndex === -1) {
  console.error('Error: Could not find insertion point in INDEX.md');
  process.exit(1);
}

// Create the new row
const newRow = `| ${newReqId} | ${file} | ${title} |`;

// Insert the new row
lines.splice(insertIndex, 0, newRow);

// Update the total count in the footer
const updatedContent = lines.join('\n');
const totalMatch = updatedContent.match(/\*\*Total Requirements:\*\* (\d+) \((\d+) PRD, (\d+) Ops, (\d+) Dev\)/);

if (totalMatch) {
  const [fullMatch, total, prdCount, opsCount, devCount] = totalMatch;
  const counts = {
    p: parseInt(prdCount, 10),
    o: parseInt(opsCount, 10),
    d: parseInt(devCount, 10)
  };

  counts[prefix]++;
  const newTotal = counts.p + counts.o + counts.d;

  const newFooter = `**Total Requirements:** ${newTotal} (${counts.p} PRD, ${counts.o} Ops, ${counts.d} Dev)`;
  const finalContent = updatedContent.replace(fullMatch, newFooter);

  fs.writeFileSync(INDEX_PATH, finalContent);
} else {
  // Fallback: just write without updating count
  fs.writeFileSync(INDEX_PATH, updatedContent);
  console.warn('Warning: Could not find/update total requirements count');
}

// Set GitHub Actions output
console.log(`::set-output name=new_req_id::${newReqId}`);
console.log(`✅ Successfully claimed ${newReqId}`);
console.log(`   File: ${file}`);
console.log(`   Title: ${title}`);
