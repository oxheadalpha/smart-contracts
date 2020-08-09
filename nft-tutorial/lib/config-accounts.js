"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    Object.defineProperty(o, k2, { enumerable: true, get: function() { return m[k]; } });
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || function (mod) {
    if (mod && mod.__esModule) return mod;
    var result = {};
    if (mod != null) for (var k in mod) if (k !== "default" && Object.hasOwnProperty.call(mod, k)) __createBinding(result, mod, k);
    __setModuleDefault(result, mod);
    return result;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.removeAccount = exports.addAccount = exports.showAccount = void 0;
const kleur = __importStar(require("kleur"));
const config_util_1 = require("./config-util");
function showAccount(alias) {
    const config = config_util_1.loadUserConfig();
    const accKey = config_util_1.getActiveAccountsCfgKey(config);
    if (alias) {
        const aliasKey = `${accKey}.${alias}`;
        if (config.has(aliasKey)) {
            const key_or_address = config.get(aliasKey);
            console.log(kleur.yellow(`${alias}  ${key_or_address}`));
        }
        else
            console.log(kleur.red(`alias ${kleur.yellow(alias)} is not configured`));
    }
    else {
        //show all accounts
        // config.get[object](accKey)
    }
}
exports.showAccount = showAccount;
function addAccount(alias, key_or_address) { }
exports.addAccount = addAccount;
function removeAccount(alias) { }
exports.removeAccount = removeAccount;
