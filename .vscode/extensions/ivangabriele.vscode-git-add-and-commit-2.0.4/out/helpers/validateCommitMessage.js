"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
function validateCommitMessage(message) {
    return message !== undefined && message !== null && message.trim() !== '';
}
exports.default = validateCommitMessage;
