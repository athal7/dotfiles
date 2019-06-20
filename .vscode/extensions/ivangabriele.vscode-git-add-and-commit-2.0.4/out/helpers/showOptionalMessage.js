"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const vscode = require("vscode");
function default_1(message, settings, isWarning = false) {
    if (settings.prefillCommitMessage.disableOptionalMessages) {
        vscode.window.setStatusBarMessage(`${isWarning ? 'Warning: ' : ''}${message}`, 6000);
    }
    else {
        if (isWarning) {
            vscode.window.showWarningMessage(message);
        }
        else {
            vscode.window.showInformationMessage(message);
        }
    }
}
exports.default = default_1;
