"use strict";
var __awaiter = (this && this.__awaiter) || function (thisArg, _arguments, P, generator) {
    return new (P || (P = Promise))(function (resolve, reject) {
        function fulfilled(value) { try { step(generator.next(value)); } catch (e) { reject(e); } }
        function rejected(value) { try { step(generator["throw"](value)); } catch (e) { reject(e); } }
        function step(result) { result.done ? resolve(result.value) : new P(function (resolve) { resolve(result.value); }).then(fulfilled, rejected); }
        step((generator = generator.apply(thisArg, _arguments || [])).next());
    });
};
Object.defineProperty(exports, "__esModule", { value: true });
const gitReset_1 = require("../helpers/gitReset");
const showOptionalMessage_1 = require("../helpers/showOptionalMessage");
function default_1(filesRelativePaths, settings) {
    return __awaiter(this, void 0, void 0, function* () {
        showOptionalMessage_1.default(`Add & Commit canceled.`, settings, true);
        return gitReset_1.default(filesRelativePaths);
    });
}
exports.default = default_1;
