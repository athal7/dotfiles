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
const gitStatus_1 = require("./gitStatus");
const GIT_SHORT_ACTIONS = {
    A: 'ADDED',
    D: 'DELETED',
    M: 'MODIFIED',
    R: 'RENAMED'
};
function default_1() {
    return __awaiter(this, void 0, void 0, function* () {
        const files = [];
        const workspaceRootAbsolutePath = vscode.workspace.workspaceFolders[0].uri.fsPath;
        let gitStatusStdOut;
        try {
            gitStatusStdOut = yield gitStatus_1.default();
        }
        catch (err) {
            console.error(err);
        }
        const matches = gitStatusStdOut.match(/[^\r\n]+/g);
        return matches === null
            ? []
            : matches.reduce((linesPartial, line) => {
                if (line.length === 0)
                    return linesPartial;
                const reg = line[0] === 'R' ? /^(\w)\s+(.*)(?=\s->\s|$)(\s->\s)(.*)/ : /^(\w)\s+(.*)/;
                const regRes = line.match(reg);
                if (regRes === null || regRes.length !== 3 && regRes.length !== 5)
                    return linesPartial;
                linesPartial.push(Object.assign({
                    path: regRes[2],
                    state: GIT_SHORT_ACTIONS[regRes[1]]
                }, line[0] === 'R'
                    ? {
                        oldPath: regRes[2],
                        path: regRes[4]
                    }
                    : undefined));
                return linesPartial;
            }, []);
    });
}
exports.default = default_1;
