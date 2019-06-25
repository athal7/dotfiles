"use strict";
exports.useRegex = /^\s+use\s+([A-Za-z0-9\.]+)'/gm;
exports.aliasRegexAs = /^\s+alias\s+([-:_A-Za-z0-9,\.\?!]+)(\s*,\s*as:\s*)?([-_A-Za-z0-9,\.\?!]+)?/gm;
exports.importRegex = /^\s+import\s+([A-Za-z0-9\.]+)/gm;
function getUsedModules(documentText) {
    return exports.useRegex.exec(documentText);
}
exports.getUsedModules = getUsedModules;
function getAliases(documentText) {
    var aliasRegex = /^\s+alias\s+([-:_A-Za-z0-9,\.\?!]+)\.{([-:_A-Za-z0-9\s,\.\?!]+)}/gm;
    var m;
    var aliases = new Array();
    var _loop_1 = function() {
        // This is necessary to avoid infinite loops with zero-width matches
        if (m.index === aliasRegex.lastIndex) {
            aliasRegex.lastIndex++;
        }
        // The result can be accessed through the `m`-variable.
        var modulePrefix = m[1];
        m[2].split(',').forEach(function (name) {
            name = name.trim();
            aliases.push("{" + name + ", " + modulePrefix + "." + name + "}");
        });
    };
    while ((m = aliasRegex.exec(documentText)) !== null) {
        _loop_1();
    }
    return aliases;
}
exports.getAliases = getAliases;
function getImports(documentText) {
    return exports.importRegex.exec(documentText);
}
exports.getImports = getImports;
function buildContext(documentText) {
    var aliasesTwoPlus = getAliases(documentText);
    var aliasesJoined = aliasesTwoPlus.join(', ');
    var aliasesString = "[" + aliasesJoined + "]";
    return "[ context: Elixir, imports: [], aliases: " + aliasesString + " ]";
}
exports.buildContext = buildContext;
//# sourceMappingURL=elixirContext.js.map