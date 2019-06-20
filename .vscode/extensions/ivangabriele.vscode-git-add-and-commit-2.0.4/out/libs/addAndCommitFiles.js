"use strict";
var __awaiter = (this && this.__awaiter) || function (thisArg, _arguments, P, generator) {
    return new (P || (P = Promise))(function (resolve, reject) {
        function fulfilled(value) { try { step(generator.next(value)); } catch (e) { reject(e); } }
        function rejected(value) { try { step(generator["throw"](value)); } catch (e) { reject(e); } }
        function step(result) { result.done ? resolve(result.value) : new P(function (resolve) { resolve(result.value); }).then(fulfilled, rejected); }
        step((generator = generator.apply(thisArg, _arguments || [])).next());
    });
};
Object.defineProperty(exports, "__esModule", { value: true });
const vscode = require("vscode");
const cancelAdd_1 = require("./cancelAdd");
const getCommonPathOfGitFiles_1 = require("../helpers/getCommonPathOfGitFiles");
const getGitStatusFiles_1 = require("../helpers/getGitStatusFiles");
const gitAdd_1 = require("../helpers/gitAdd");
const gitCommit_1 = require("../helpers/gitCommit");
const guessAction_1 = require("../helpers/guessAction");
const replaceStringWith_1 = require("../helpers/replaceStringWith");
const showOptionalMessage_1 = require("../helpers/showOptionalMessage");
const validateCommitMessage_1 = require("../helpers/validateCommitMessage");
function addAndCommitFiles(filesRelativePaths, settings) {
    return __awaiter(this, void 0, void 0, function* () {
        // ----------------------------------
        // GIT ADD
        try {
            yield gitAdd_1.default(filesRelativePaths);
        }
        catch (err) {
            // Git warnings are also caught here, so let's ignore them
            if (typeof err !== 'string' || !/^warning/i.test(err)) {
                vscode.window.showErrorMessage(err);
                console.error(err);
                return;
            }
        }
        // ----------------------------------
        // COMMIT MESSAGE
        let commitMessage = '';
        let commonFilePath;
        try {
            const gitStatusFiles = yield getGitStatusFiles_1.default();
            // If Git didn't find anything to add
            if (gitStatusFiles.length === 0) {
                showOptionalMessage_1.default(`Nothing to commit, did you save your changes ?.`, settings, true);
                return;
            }
            // Prepare the common path that may be used to prefill the commit message
            if (gitStatusFiles.length === 1) {
                commonFilePath = gitStatusFiles[0].path;
            }
            else {
                commonFilePath = getCommonPathOfGitFiles_1.default(gitStatusFiles);
            }
            // Enable the commit message auto-fill ONLY if we were able to find a common path
            if (commonFilePath.length !== 0) {
                // Prefill the commit message with file path
                if (settings.prefillCommitMessage.withFileWorkspacePath) {
                    commitMessage += commonFilePath + ': ';
                    if (settings.prefillCommitMessage.ignoreFileExtension) {
                        const matches = commitMessage.match(/[^\/](\.\w+):/);
                        if (matches !== null && matches.length === 2) {
                            commitMessage = commitMessage.replace(matches[1], '');
                        }
                    }
                }
                // Force the commit message into lower case
                if (settings.prefillCommitMessage.forceLowerCase) {
                    commitMessage = commitMessage.toLocaleLowerCase();
                }
                // Prefill the commit message with the guessed action
                if (gitStatusFiles.length === 1) {
                    commitMessage = guessAction_1.default(commitMessage, gitStatusFiles[0].state, settings.prefillCommitMessage.withGuessedCustomActions);
                }
                // Prefill the commit message with settings patterns
                commitMessage = replaceStringWith_1.default(commitMessage, settings.prefillCommitMessage.replacePatternWith);
            }
            // Prompt user for the commit message
            commitMessage = yield vscode.window.showInputBox({
                ignoreFocusOut: true,
                prompt: 'Git commit message ?',
                validateInput: commitMessage => !validateCommitMessage_1.default(commitMessage)
                    ? `You can't commit with an empty commit message. Write something or press ESC to cancel.`
                    : undefined,
                value: commitMessage
            });
        }
        catch (err) {
            vscode.window.showErrorMessage(err);
            console.error(err);
            return cancelAdd_1.default(filesRelativePaths, settings);
        }
        // Check if the commit message is valid
        if (!validateCommitMessage_1.default(commitMessage)) {
            showOptionalMessage_1.default(`You can't commit with an empty commit message.`, settings, true);
            return cancelAdd_1.default(filesRelativePaths, settings);
        }
        // ----------------------------------
        // GIT COMMIT
        try {
            yield gitCommit_1.default(commitMessage);
        }
        catch (err) {
            // Git warnings are also caught here, so let's ignore them
            if (typeof err !== 'string' || !/^warning/i.test(err)) {
                vscode.window.showErrorMessage(err);
                console.error(err);
                return cancelAdd_1.default(filesRelativePaths, settings);
            }
        }
        // ----------------------------------
        // END
        showOptionalMessage_1.default(`File(s) committed to Git with the message: "${commitMessage}".`, settings);
    });
}
exports.default = addAndCommitFiles;
