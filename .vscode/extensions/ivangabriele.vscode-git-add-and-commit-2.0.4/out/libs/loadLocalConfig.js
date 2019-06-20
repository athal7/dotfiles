"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const fs = require("fs");
const path = require("path");
const vscode = require("vscode");
const isFile_1 = require("../helpers/isFile");
const merge_1 = require("../helpers/merge");
const normalizePattern_1 = require("../helpers/normalizePattern");
function default_1(workspaceRootAbsolutePath) {
    const workspaceSettingsAbsolutePath = path
        .resolve(workspaceRootAbsolutePath, '.vscode', 'vscode-git-add-and-commit.json');
    const defaultSettings = { prefillCommitMessage: vscode.workspace.getConfiguration('gaac') };
    let userSettings = {};
    if (isFile_1.default(workspaceSettingsAbsolutePath)) {
        try {
            const settingsSource = fs.readFileSync(workspaceSettingsAbsolutePath, 'utf8');
            userSettings = JSON.parse(settingsSource);
        }
        catch (err) {
            vscode.window.showWarningMessage(`
        Can't load ".vscode/vscode-git-add-and-commit.json".
        Please check the file content format.
      `);
            console.error(err);
        }
    }
    // const schemaRes = schemaValidate(settings, SettingsSchema)
    // if (!schemaRes.valid) {
    //   vscode.window.showWarningMessage(`
    //     Settings validation error. Please check the properties in ".vscode/vscode-git-add-and-commit.json"
    //     or remove this file and use your user/workspace settings instead.
    //   `)
    //   schemaRes.errors.forEach(err => console.error(err.message))
    //   return defaultSettings
    // }
    const normalizedSettings = merge_1.default(defaultSettings, userSettings);
    normalizedSettings.prefillCommitMessage.replacePatternWith =
        normalizedSettings.prefillCommitMessage.replacePatternWith
            .map(settingsPattern => ({
            pattern: normalizePattern_1.default(settingsPattern.pattern),
            with: settingsPattern.with
        }));
    normalizedSettings.prefillCommitMessage.withGuessedCustomActions =
        normalizedSettings.prefillCommitMessage.withGuessedCustomActions
            .map(settingsPattern => ({
            action: settingsPattern.action,
            pattern: normalizePattern_1.default(settingsPattern.pattern),
            state: settingsPattern.state
        }));
    return normalizedSettings;
}
exports.default = default_1;
