"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const path_1 = require("path");
const vscode = require("vscode");
const elixirSenseValidations_1 = require("./elixirSenseValidations");
function validateResultIsNotNone(result) {
    if (result === 'none') {
        throw new Error();
    }
    return result;
}
class ElixirSenseSignatureHelpProvider {
    constructor(elixirSenseClient) {
        this.elixirSenseClient = elixirSenseClient;
    }
    provideSignatureHelp(document, position, token) {
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
                .then((elixirSenseClient) => elixirSenseClient.send('signature', payload))
                .then((result) => elixirSenseValidations_1.checkTokenCancellation(token, result))
                .then((result) => validateResultIsNotNone(result))
                .then((result) => {
                let paramPosition = result.active_param;
                const pipeBefore = result.pipe_before;
                let signatures = result.signatures.filter((sig) => sig.params.length > paramPosition);
                if (signatures.length === 0 && result.signatures.length > 0) {
                    signatures = result.signatures.slice(result.signatures.length - 1, result.signatures.length);
                    if (signatures[0].params[signatures[0].params.length - 1].includes('\\ []')) {
                        paramPosition = signatures[0].params.length - 1;
                    }
                }
                const vsSigs = this.processSignatures(signatures);
                const signatureHelper = new vscode.SignatureHelp();
                signatureHelper.activeParameter = paramPosition;
                signatureHelper.activeSignature = 0;
                signatureHelper.signatures = vsSigs;
                resolve(signatureHelper);
            })
                .catch((err) => {
                console.error('rejecting', err);
                reject();
            });
        });
    }
    processSignatures(signatures) {
        return Array.from(signatures).map((s) => this.genSignatureInfo(s));
    }
    genSignatureInfo(signature) {
        const si = new vscode.SignatureInformation(signature.name + '(' + signature.params.join(', ') + ')', signature.documentation + '\n' + signature.spec);
        si.parameters = Array.from(signature.params).map((p) => this.genParameterInfo(p));
        return si;
    }
    genParameterInfo(param) {
        return new vscode.ParameterInformation(param);
    }
}
exports.ElixirSenseSignatureHelpProvider = ElixirSenseSignatureHelpProvider;
//# sourceMappingURL=elixirSenseSignatureHelpProvider.js.map