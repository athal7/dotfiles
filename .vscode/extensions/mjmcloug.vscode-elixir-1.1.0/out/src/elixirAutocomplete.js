"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
class ElixirAutocomplete {
    constructor(elixirServer) {
        this.elixirServer = elixirServer;
    }
    // tslint:disable-next-line:max-line-length
    provideCompletionItems(document, position, token) {
        return new Promise((resolve, reject) => {
            this.elixirServer.getCompletions(document, position, (result) => {
                if (!token.isCancellationRequested) {
                    resolve(result);
                }
                else {
                    console.error('rejecting');
                    reject();
                }
            });
        });
    }
}
exports.ElixirAutocomplete = ElixirAutocomplete;
//# sourceMappingURL=elixirAutocomplete.js.map