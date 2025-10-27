"use strict";
/**
 * File type detection for comment style selection
 */
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.CommentStyle = void 0;
exports.detectCommentStyle = detectCommentStyle;
exports.getCommentPrefix = getCommentPrefix;
exports.getCommentSuffix = getCommentSuffix;
const path = __importStar(require("path"));
var CommentStyle;
(function (CommentStyle) {
    CommentStyle["DoubleSlash"] = "//";
    CommentStyle["Hash"] = "#";
    CommentStyle["DoubleDash"] = "--";
    CommentStyle["Html"] = "<!--";
    CommentStyle["Semicolon"] = ";";
})(CommentStyle || (exports.CommentStyle = CommentStyle = {}));
/**
 * Detect comment style based on file extension
 */
function detectCommentStyle(fileName) {
    const ext = path.extname(fileName).toLowerCase();
    const styleMap = {
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
function getCommentPrefix(fileName) {
    const style = detectCommentStyle(fileName);
    return style.toString();
}
/**
 * Get comment suffix for HTML-style comments
 */
function getCommentSuffix(fileName) {
    const style = detectCommentStyle(fileName);
    return style === CommentStyle.Html ? ' -->' : '';
}
//# sourceMappingURL=detector.js.map