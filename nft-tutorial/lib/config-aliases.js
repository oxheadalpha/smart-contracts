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
exports.removeAlias = exports.addAlias = exports.showAlias = void 0;
const kleur = __importStar(require("kleur"));
const config_util_1 = require("./config-util");
function showAlias(alias) {
    const config = config_util_1.loadUserConfig();
    const accKey = config_util_1.getActiveAccountsCfgKey(config);
    if (alias) {
        const aliasKey = `${accKey}.${alias}`;
        if (config.has(aliasKey)) {
            const key_or_address = config.get(aliasKey);
            console.log(kleur.yellow(`${alias}\t${key_or_address}`));
        }
        else
            console.log(kleur.red(`alias ${kleur.yellow(alias)} is not configured`));
    }
    else {
        const allAliases = Object.getOwnPropertyNames(config.get(accKey));
        for (let a of allAliases) {
            const aliasKey = `${accKey}.${a}`;
            const key_or_address = config.get(aliasKey);
            console.log(kleur.yellow(`${a}\t${key_or_address}`));
        }
    }
}
exports.showAlias = showAlias;
function addAlias(alias, key_or_address) {
    const config = config_util_1.loadUserConfig();
    const accKey = config_util_1.getActiveAccountsCfgKey(config);
    const aliasKey = `${accKey}.${alias}`;
    if (config.has(aliasKey)) {
        console.log(kleur.red(`alias ${kleur.yellow(alias)} already exists`));
        return;
    }
    if (!(key_or_address.startsWith('tz') || key_or_address.startsWith('edsk'))) {
        console.log(kleur.red('alias value can be either private key or tz address'));
        return;
    }
    config.set(aliasKey, key_or_address);
}
exports.addAlias = addAlias;
function removeAlias(alias) {
    const config = config_util_1.loadUserConfig();
    const accKey = config_util_1.getActiveAccountsCfgKey(config);
    const aliasKey = `${accKey}.${alias}`;
    if (!config.has(aliasKey)) {
        console.log(kleur.red(`alias ${kleur.yellow(alias)} does not exists`));
        return;
    }
    config.delete(aliasKey);
}
exports.removeAlias = removeAlias;
