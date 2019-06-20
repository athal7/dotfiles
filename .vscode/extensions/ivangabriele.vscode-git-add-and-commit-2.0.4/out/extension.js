"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const vscode = require("vscode");
const path = require("path");
const addAndCommitFiles_1 = require("./libs/addAndCommitFiles");
const loadLocalConfig_1 = require("./libs/loadLocalConfig");
const pushLocalCommits_1 = require("./libs/pushLocalCommits");
const workspaceRootAbsolutePath = vscode.workspace.workspaceFolders[0].uri.fsPath;
function activate(context) {
    const settings = loadLocalConfig_1.default(workspaceRootAbsolutePath);
    const addAndCommitAllFilesDisposable = vscode.commands.registerCommand('extension.vscode-git-automator.addAndCommitAllFiles', () => addAndCommitFiles_1.default(['*'], settings));
    const addAndCommitCurrentFileDisposable = vscode.commands.registerCommand('extension.vscode-git-automator.addAndCommitCurrentFile', () => addAndCommitFiles_1.default([
        path.relative(workspaceRootAbsolutePath, vscode.window.activeTextEditor.document.fileName)
    ], settings));
    const pushLocalCommitsDisposable = vscode.commands.registerCommand('extension.vscode-git-automator.pushLocalCommits', () => pushLocalCommits_1.default(settings));
    context.subscriptions.push(addAndCommitAllFilesDisposable, addAndCommitCurrentFileDisposable, pushLocalCommitsDisposable);
}
exports.activate = activate;
function deactivate() { }
exports.deactivate = deactivate;
