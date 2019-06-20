"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
function default_1(commitMessage, state, customActions) {
    const customAction = customActions.find(({ pattern: actionPattern, state: actionState }) => {
        if (actionState !== state)
            return false;
        return typeof actionPattern === 'string'
            ? commitMessage.includes(actionPattern)
            : actionPattern.test(commitMessage);
    }, customActions);
    if (customAction === undefined) {
        switch (state) {
            case 'ADDED':
                commitMessage += 'create';
                break;
            case 'DELETED':
                commitMessage += 'remove';
                break;
            case 'RENAMED':
                commitMessage += 'move';
                break;
            default:
                break;
        }
        return commitMessage;
    }
    return commitMessage += customAction.action;
}
exports.default = default_1;
