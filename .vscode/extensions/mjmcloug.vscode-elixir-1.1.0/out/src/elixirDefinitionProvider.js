"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const vscode = require("vscode");
class ElixirDefinitionProvider {
    constructor(server) {
        this.server = server;
    }
    // tslint:disable-next-line:max-line-length
    provideDefinition(document, position, token) {
        const wordAtPosition = document.getWordRangeAtPosition(position);
        const word = document.getText(wordAtPosition);
        return new Promise((resolve, reject) => {
            this.server.getDefinition(document, position, (res) => {
                if (res === 'non_existing' || !res) {
                    // tslint:disable-next-line:no-null-keyword
                    resolve(null);
                }
                else {
                    const splitAt = res.lastIndexOf(':');
                    let location;
                    if (splitAt !== 1) {
                        const filePath = res.substring(0, splitAt);
                        // tslint:disable-next-line:radix
                        const lineNumber = parseInt(res.substring(splitAt + 1, res.length)) - 1;
                        if (lineNumber >= 0) {
                            // TODO: Need to find the correct (character) position here:
                            location = new vscode.Location(vscode.Uri.file(filePath), new vscode.Position(lineNumber, 0));
                        }
                        else {
                            location = new vscode.Location(vscode.Uri.file(filePath), new vscode.Position(0, 0));
                        }
                    }
                    else {
                        location = new vscode.Location(vscode.Uri.file(res), new vscode.Position(0, 0));
                    }
                    resolve(location);
                }
            });
        });
    }
}
exports.ElixirDefinitionProvider = ElixirDefinitionProvider;
//# sourceMappingURL=elixirDefinitionProvider.js.map