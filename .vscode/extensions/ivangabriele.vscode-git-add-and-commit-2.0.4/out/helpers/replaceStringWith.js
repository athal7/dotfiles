"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
function replaceStringWith(str, patterns) {
    return patterns.reduce((reducedStr, { pattern, with: val }) => {
        return reducedStr.replace(pattern, val);
    }, str);
}
exports.default = replaceStringWith;
