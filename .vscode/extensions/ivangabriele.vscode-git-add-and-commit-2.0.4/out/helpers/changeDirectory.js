"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
function default_1(workspaceRootAbsolutePath) {
    try {
        process.chdir(workspaceRootAbsolutePath);
    }
    catch (err) {
        throw err;
    }
}
exports.default = default_1;
