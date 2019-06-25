"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const path_1 = require("path");
const vscode = require("vscode");
const elixirSenseValidations_1 = require("./elixirSenseValidations");
class ElixirSenseHoverProvider {
    constructor(elixirSenseClient) {
        this.elixirSenseClient = elixirSenseClient;
    }
    provideHover(document, position, token) {
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
                .then((elixirSenseClient) => elixirSenseClient.send('docs', payload))
                .then((result) => elixirSenseValidations_1.checkTokenCancellation(token, result))
                .then((result) => {
                const { actual_subject, docs } = result;
                if (!docs) {
                    console.error('rejecting');
                    reject();
                    return;
                }
                const wordAtPosition = document.getWordRangeAtPosition(position);
                const hover = new vscode.Hover(docs.docs, wordAtPosition);
                resolve(hover);
            })
                .catch((err) => {
                console.error('rejecting', err);
                reject();
            });
        });
    }
}
exports.ElixirSenseHoverProvider = ElixirSenseHoverProvider;
//# sourceMappingURL=elixirSenseHoverProvider.js.map