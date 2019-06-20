"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
function normalizePattern(pattern) {
    let normalizedPattern = pattern;
    if (pattern.length > 1
        && pattern.substr(0, 1) === '/'
        && pattern.substr(pattern.length - 1, 1) === '/') {
        normalizedPattern = new RegExp(pattern.substr(1, pattern.length - 2));
    }
    return normalizedPattern;
}
exports.default = normalizePattern;
