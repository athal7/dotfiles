"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const fs_1 = require("fs");
const path_1 = require("path");
const vscode = require("vscode");
const configuration_1 = require("./configuration");
const elixirAutocomplete_1 = require("./elixirAutocomplete");
const elixirDefinitionProvider_1 = require("./elixirDefinitionProvider");
const elixirHoverProvider_1 = require("./elixirHoverProvider");
const elixirSenseAutocompleteProvider_1 = require("./elixirSenseAutocompleteProvider");
const elixirSenseClient_1 = require("./elixirSenseClient");
const elixirSenseDefinitionProvider_1 = require("./elixirSenseDefinitionProvider");
const elixirSenseHoverProvider_1 = require("./elixirSenseHoverProvider");
const elixirSenseServerProcess_1 = require("./elixirSenseServerProcess");
const elixirSenseSignatureHelpProvider_1 = require("./elixirSenseSignatureHelpProvider");
const elixirServer_1 = require("./elixirServer");
const ELIXIR_MODE = { language: 'elixir', scheme: 'file' };
// tslint:disable-next-line:prefer-const
let elixirServer;
// Elixir-Sense
let useElixirSense;
let autoSpawnElixirSenseServers;
const elixirSenseServers = {};
const elixirSenseClients = {};
function activate(ctx) {
    const elixirSetting = vscode.workspace.getConfiguration('elixir');
    useElixirSense = elixirSetting.useElixirSense;
    autoSpawnElixirSenseServers = elixirSetting.autoSpawnElixirSenseServers;
    const projectPath = elixirSetting.projectPath;
    // TODO: detect environment automatically.
    const env = elixirSetting.elixirEnv;
    if (useElixirSense) {
        elixirSenseServerProcess_1.ElixirSenseServerProcess.initClass();
        if (autoSpawnElixirSenseServers) {
            (vscode.workspace.workspaceFolders || []).forEach((workspaceFolder) => {
                startElixirSenseServerForWorkspaceFolder(workspaceFolder, ctx, env, projectPath);
            });
        }
        else if ((vscode.workspace.workspaceFolders || []).length === 1) {
            startElixirSenseServerForWorkspaceFolder(vscode.workspace.workspaceFolders[0], ctx, env);
        }
        vscode.workspace.onDidChangeWorkspaceFolders((e) => {
            (e.removed || []).forEach((workspaceFolder) => stopElixirSenseServerByPath(workspaceFolder.uri.fsPath));
            if (autoSpawnElixirSenseServers) {
                (e.added || []).forEach((workspaceFolder) => startElixirSenseServerForWorkspaceFolder(workspaceFolder, ctx, env));
            }
        });
    }
    else {
        this.elixirServer = new elixirServer_1.ElixirServer();
        this.elixirServer.start();
        ctx.subscriptions.push(vscode.languages.registerCompletionItemProvider(ELIXIR_MODE, new elixirAutocomplete_1.ElixirAutocomplete(this.elixirServer), '.'));
        ctx.subscriptions.push(vscode.languages.registerDefinitionProvider(ELIXIR_MODE, new elixirDefinitionProvider_1.ElixirDefinitionProvider(this.elixirServer)));
        ctx.subscriptions.push(vscode.languages.registerHoverProvider(ELIXIR_MODE, new elixirHoverProvider_1.ElixirHoverProvider(this.elixirServer)));
        ctx.subscriptions.push(vscode.languages.setLanguageConfiguration('elixir', configuration_1.configuration));
    }
    const disposables = [];
    if (useElixirSense) {
        disposables.push(vscode.commands.registerCommand('extension.selectElixirSenseWorkspaceFolder', () => selectElixirSenseWorkspaceFolder(ctx, env)));
    }
    ctx.subscriptions.push(...disposables);
}
exports.activate = activate;
function deactivate() {
    if (useElixirSense) {
        stopAllElixirSenseServers();
    }
    else {
        this.elixirServer.stop();
    }
}
exports.deactivate = deactivate;
function startElixirSenseServerForWorkspaceFolder(workspaceFolder, ctx, env, settingProjectPath = '') {
    const projectPath = path_1.join(workspaceFolder.uri.fsPath, settingProjectPath);
    if (elixirSenseServers[projectPath] || !fs_1.existsSync(path_1.join(projectPath, 'mix.exs'))) {
        const warnmsg = `Could not find a Mix project in ${projectPath}. Elixir support disabled. `;
        const hint = `If your Mix project is in a subfolder, change the elixir.projectPath setting accordingly.`;
        vscode.window.showWarningMessage(warnmsg + hint);
        return;
    }
    let subscriptions;
    const elixirSenseServer = new elixirSenseServerProcess_1.ElixirSenseServerProcess(projectPath, (host, port, authToken) => {
        const elixirSenseClient = new elixirSenseClient_1.ElixirSenseClient(host, port, authToken, env, projectPath);
        elixirSenseClients[projectPath] = elixirSenseClient;
        const autoCompleteProvider = new elixirSenseAutocompleteProvider_1.ElixirSenseAutocompleteProvider(elixirSenseClient);
        const definitionProvider = new elixirSenseDefinitionProvider_1.ElixirSenseDefinitionProvider(elixirSenseClient);
        const hoverProvider = new elixirSenseHoverProvider_1.ElixirSenseHoverProvider(elixirSenseClient);
        const signatureHelpProvider = new elixirSenseSignatureHelpProvider_1.ElixirSenseSignatureHelpProvider(elixirSenseClient);
        subscriptions = [
            vscode.languages.registerCompletionItemProvider(ELIXIR_MODE, autoCompleteProvider, '.', '{', '@'),
            vscode.languages.registerDefinitionProvider(ELIXIR_MODE, definitionProvider),
            vscode.languages.registerHoverProvider(ELIXIR_MODE, hoverProvider),
            vscode.languages.registerSignatureHelpProvider(ELIXIR_MODE, signatureHelpProvider, '(', ','),
            vscode.languages.setLanguageConfiguration('elixir', configuration_1.configuration)
        ];
        ctx.subscriptions.concat(subscriptions);
    });
    elixirSenseServer.start(0, env);
    elixirSenseServers[projectPath] = {
        server: elixirSenseServer,
        subscriptions: () => subscriptions,
    };
}
function stopElixirSenseServerByPath(path) {
    const serverEntry = elixirSenseServers[path];
    if (serverEntry) {
        serverEntry.server.stop();
        (serverEntry.subscriptions() || []).forEach((subscription) => subscription.dispose());
    }
    delete elixirSenseServers[path];
}
function stopAllElixirSenseServers() {
    Object.keys(elixirSenseServers).forEach(stopElixirSenseServerByPath);
}
function selectElixirSenseWorkspaceFolder(ctx, env) {
    if (autoSpawnElixirSenseServers) {
        vscode.window.showInformationMessage('Setting `elixir.autoSpawnElixirSenseServers` is set to `true`'
            + 'so there is no need to manually start the ElixirSense server');
        return;
    }
    const workspaceFolders = vscode.workspace.workspaceFolders || [];
    if (!workspaceFolders.length) {
        vscode.window.showInformationMessage('There are no folders in the current workspace');
        return;
    }
    const items = workspaceFolders
        .map((workspaceFolder) => ({
        label: workspaceFolder.name,
        description: workspaceFolder.uri.fsPath,
    }))
        .filter((item) => !elixirSenseServers[item.description]);
    const options = {
        matchOnDescription: false,
        matchOnDetail: false,
        placeHolder: 'Choose workspace folder...',
    };
    vscode.window.showQuickPick(items, options).then((item) => {
        if (!item) {
            return;
        }
        const workspaceFolder = (vscode.workspace.workspaceFolders || [])
            .find((workspaceFolderTmp) => workspaceFolderTmp.uri.fsPath === item.description);
        if (!workspaceFolder) {
            return;
        }
        stopAllElixirSenseServers();
        startElixirSenseServerForWorkspaceFolder(workspaceFolder, ctx, env);
    }, 
    // tslint:disable-next-line:no-empty
    (reason) => { });
}
//# sourceMappingURL=elixirMain.js.map