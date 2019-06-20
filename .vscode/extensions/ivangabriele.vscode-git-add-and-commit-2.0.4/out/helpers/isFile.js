"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const fs = require("fs");
function default_1(fileAbsolutePath) {
    try {
        if (fs.lstatSync(fileAbsolutePath).isFile()) {
            return true;
        }
        return false;
    }
    catch (err) {
        return false;
    }
}
exports.default = default_1;
