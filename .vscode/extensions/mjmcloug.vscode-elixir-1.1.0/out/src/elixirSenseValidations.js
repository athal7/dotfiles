"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
function checkTokenCancellation(token, result) {
    if (token.isCancellationRequested) {
        throw new Error('The request was cancelled');
    }
    return result;
}
exports.checkTokenCancellation = checkTokenCancellation;
function checkElixirSenseClientInitialized(elixirSenseClient) {
    if (!elixirSenseClient) {
        throw new Error('Elixirsense client not ready');
    }
    return elixirSenseClient;
}
exports.checkElixirSenseClientInitialized = checkElixirSenseClientInitialized;
//# sourceMappingURL=elixirSenseValidations.js.map