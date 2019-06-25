"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const path_1 = require("path");
const vscode = require("vscode");
const elixirSenseValidations_1 = require("./elixirSenseValidations");
class ElixirSenseDefinitionProvider {
    constructor(elixirSenseClient) {
        this.elixirSenseClient = elixirSenseClient;
    }
    provideDefinition(document, position, token) {
        const wordAtPosition = document.getWordRangeAtPosition(position);
        const word = document.getText(wordAtPosition);
        return new Promise((resolve, reject) => {
            let elixirSenseClientError;
            const resultPromise = Promise.resolve(this.elixirSenseClient)
                .then((elixirSenseClient) => elixirSenseValidations_1.checkElixirSenseClientInitialized(elixirSenseClient))
                .catch((err) => {
                elixirSenseClientError = err;
            });
            if (elixirSenseClientError) {
                console.error('rejecting', elixirSenseClientError);
                reject();
                return;
            }
            const documentPath = (document.uri || { fsPath: '' }).fsPath || '';
            if (!documentPath.startsWith(path_1.join(this.elixirSenseClient.projectPath, path_1.sep))) {
                reject();
                return;
            }
            const payload = {
                buffer: document.getText(),
                line: position.line + 1,
                column: position.character + 1
            };
            return resultPromise
                .then((elixirSenseClient) => elixirSenseClient.send('definition', payload))
                .then((result) => elixirSenseValidations_1.checkTokenCancellation(token, result))
                .then((result) => {
                const filePath = result.substring(0, result.lastIndexOf(':'));
                const lineNumberStr = result.substring(result.lastIndexOf(':') + 1, result.length);
                const lineNumber = Number(lineNumberStr) - 1;
                if (!filePath || filePath === 'non_existing') {
                    resolve(undefined);
                    return;
                }
                const location = new vscode.Location(vscode.Uri.file(filePath), new vscode.Position(lineNumber, 0));
                resolve(location);
            })
                .catch((err) => {
                console.error('rejecting', err);
                reject();
            });
        });
    }
}
exports.ElixirSenseDefinitionProvider = ElixirSenseDefinitionProvider;
//# sourceMappingURL=elixirSenseDefinitionProvider.js.map