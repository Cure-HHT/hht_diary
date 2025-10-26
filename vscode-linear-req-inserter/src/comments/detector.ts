/**
 * File type detection for comment style selection
 */

import * as path from 'path';

export enum CommentStyle {
    DoubleSlash = '//',    // JavaScript, TypeScript, Dart, C++, etc.
    Hash = '#',            // Python, Ruby, Shell, etc.
    DoubleDash = '--',     // SQL, Lua, Haskell
    Html = '<!--',         // HTML, Markdown, XML
    Semicolon = ';',       // Lisp, Scheme, Assembly
}

/**
 * Detect comment style based on file extension
 */
export function detectCommentStyle(fileName: string): CommentStyle {
    const ext = path.extname(fileName).toLowerCase();

    const styleMap: Record<string, CommentStyle> = {
        // JavaScript/TypeScript family
        '.js': CommentStyle.DoubleSlash,
        '.jsx': CommentStyle.DoubleSlash,
        '.ts': CommentStyle.DoubleSlash,
        '.tsx': CommentStyle.DoubleSlash,
        '.mjs': CommentStyle.DoubleSlash,
        '.cjs': CommentStyle.DoubleSlash,

        // Dart
        '.dart': CommentStyle.DoubleSlash,

        // C family
        '.c': CommentStyle.DoubleSlash,
        '.cpp': CommentStyle.DoubleSlash,
        '.cc': CommentStyle.DoubleSlash,
        '.h': CommentStyle.DoubleSlash,
        '.hpp': CommentStyle.DoubleSlash,
        '.java': CommentStyle.DoubleSlash,
        '.cs': CommentStyle.DoubleSlash,
        '.go': CommentStyle.DoubleSlash,
        '.rs': CommentStyle.DoubleSlash,
        '.swift': CommentStyle.DoubleSlash,
        '.kt': CommentStyle.DoubleSlash,

        // SQL
        '.sql': CommentStyle.DoubleDash,

        // Python family
        '.py': CommentStyle.Hash,
        '.pyw': CommentStyle.Hash,
        '.rb': CommentStyle.Hash,
        '.sh': CommentStyle.Hash,
        '.bash': CommentStyle.Hash,
        '.zsh': CommentStyle.Hash,
        '.fish': CommentStyle.Hash,
        '.yml': CommentStyle.Hash,
        '.yaml': CommentStyle.Hash,
        '.toml': CommentStyle.Hash,
        '.pl': CommentStyle.Hash,
        '.r': CommentStyle.Hash,

        // Markup
        '.html': CommentStyle.Html,
        '.htm': CommentStyle.Html,
        '.xml': CommentStyle.Html,
        '.md': CommentStyle.Html,
        '.markdown': CommentStyle.Html,
        '.svg': CommentStyle.Html,

        // Lisp family
        '.lisp': CommentStyle.Semicolon,
        '.lsp': CommentStyle.Semicolon,
        '.scm': CommentStyle.Semicolon,
        '.clj': CommentStyle.Semicolon,
        '.asm': CommentStyle.Semicolon,
    };

    return styleMap[ext] || CommentStyle.DoubleSlash;
}

/**
 * Get comment prefix for a file
 */
export function getCommentPrefix(fileName: string): string {
    const style = detectCommentStyle(fileName);
    return style.toString();
}

/**
 * Get comment suffix for HTML-style comments
 */
export function getCommentSuffix(fileName: string): string {
    const style = detectCommentStyle(fileName);
    return style === CommentStyle.Html ? ' -->' : '';
}
