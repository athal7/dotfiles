"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
class ElixirHoverProvider {
    constructor(server) {
        this.server = server;
    }
    provideHover(document, position, token) {
        return new Promise((resolve, reject) => {
            this.server.getDocumentation(document, position, (hover) => {
                if (!token.isCancellationRequested) {
                    resolve(hover);
                }
                else {
                    console.error('rejecting');
                    reject();
                }
            });
        });
    }
}
exports.ElixirHoverProvider = ElixirHoverProvider;
//# sourceMappingURL=elixirHoverProvider.js.map