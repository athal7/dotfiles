"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const vscode_1 = require("vscode");
const vscode_2 = require("vscode");
const cp = require("child_process");
var path = require('path');
function fullDocumentRange(document) {
    const lastLineId = document.lineCount - 1;
    return new vscode_2.Range(0, 0, lastLineId, document.lineAt(lastLineId).text.length);
}
function format(document) {
    return new Promise((resolve, reject) => {
        // Create mix command
        const mixFormatArgs = vscode_2.workspace.getConfiguration("elixir.formatter").get("mixFormatArgs") || "";
        const cmd = `mix format ${mixFormatArgs} ${document.fileName}`;
        // Figure out the working directory to run mix format in
        const workspaceRootPath = vscode_2.workspace.rootPath ? vscode_2.workspace.rootPath : "";
        const relativePath = vscode_2.workspace.getConfiguration("elixir.formatter").get("formatterCwd") || "";
        const cwd = path.resolve(workspaceRootPath, relativePath);
        // Run the command
        cp.exec(cmd, {
            cwd
        }, function (error, stdout, stderr) {
            if (error !== null) {
                const message = `Cannot format due to syntax errors.: ${stderr}`;
                vscode_2.window.showErrorMessage(message);
                return reject(message);
            }
            else {
                return [vscode_2.TextEdit.replace(fullDocumentRange(document), stdout)];
            }
        });
    });
}
function activate(context) {
    vscode_1.languages.registerDocumentFormattingEditProvider('elixir', {
        provideDocumentFormattingEdits(document) {
            return document.save().then(() => {
                return format(document);
            });
        }
    });
}
exports.activate = activate;
//# sourceMappingURL=extension.js.map