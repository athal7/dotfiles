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
const childProcess = require("child_process");
const vscode_1 = require("vscode");
const cwd = vscode_1.workspace.workspaceFolders[0].uri.fsPath;
function default_1(command, args) {
    return __awaiter(this, void 0, void 0, function* () {
        return new Promise((resolve, reject) => {
            let res, stderr = '', stdout = '';
            try {
                const batch = childProcess.spawn(command, args, { cwd });
                batch.stdout.on('data', function (data) {
                    stdout += data.toString();
                });
                batch.stderr.on('data', data => stdout += data.toString());
                batch.stderr.on('data', data => stderr += data.toString());
                batch.on('close', function () {
                    if (stderr !== '')
                        return reject(stderr.trim());
                    resolve(stdout);
                });
            }
            catch (err) {
                reject(err);
            }
        });
    });
}
exports.default = default_1;
