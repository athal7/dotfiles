"use strict";
var ElixirSymbolProvider = (function () {
    function ElixirSymbolProvider(elixirServer) {
        this.elixirServer = elixirServer;
    }
    ElixirSymbolProvider.prototype.provideDocumentSymbols = function (document, token) {
        this.elixirServer.getSymbols(document, function () { });
        return [];
    };
    return ElixirSymbolProvider;
}());
exports.ElixirSymbolProvider = ElixirSymbolProvider;
//# sourceMappingURL=elixirSymbolProvider.js.map