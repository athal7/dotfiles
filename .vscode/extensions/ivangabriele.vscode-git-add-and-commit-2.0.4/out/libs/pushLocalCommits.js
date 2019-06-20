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
const await_to_js_1 = require("await-to-js");
const vscode = require("vscode");
const gitPush_1 = require("../helpers/gitPush");
const showProgressNotification_1 = require("../libs/showProgressNotification");
const showOptionalMessage_1 = require("../helpers/showOptionalMessage");
function pushLocalCommits(settings) {
    return __awaiter(this, void 0, void 0, function* () {
        // ----------------------------------
        // GIT PUSH
        const [err] = yield await_to_js_1.default(showProgressNotification_1.default('Pushing your local commits...', gitPush_1.default));
        // Git warnings are also caught here, so let's ignore them
        if (typeof err !== 'string' || !(/^to\s/i.test(err) && !/!\s\[rejected\]/i.test(err))) {
            if (err === 'Everything up-to-date') {
                vscode.window.showInformationMessage(err);
            }
            else {
                vscode.window.showErrorMessage(err);
                console.error(err);
                return;
            }
        }
        // ----------------------------------
        // END
        showOptionalMessage_1.default(`Local commit(s) pushed.`, settings);
    });
}
exports.default = pushLocalCommits;
