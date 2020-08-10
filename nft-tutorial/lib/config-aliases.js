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
var __awaiter = (this && this.__awaiter) || function (thisArg, _arguments, P, generator) {
    function adopt(value) { return value instanceof P ? value : new P(function (resolve) { resolve(value); }); }
    return new (P || (P = Promise))(function (resolve, reject) {
        function fulfilled(value) { try { step(generator.next(value)); } catch (e) { reject(e); } }
        function rejected(value) { try { step(generator["throw"](value)); } catch (e) { reject(e); } }
        function step(result) { result.done ? resolve(result.value) : adopt(result.value).then(fulfilled, rejected); }
        step((generator = generator.apply(thisArg, _arguments || [])).next());
    });
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.resolveAlias2Address = exports.resolveAlias2Signer = exports.removeAlias = exports.addAlias = exports.showAlias = void 0;
const kleur = __importStar(require("kleur"));
const utils_1 = require("@taquito/utils");
const signer_1 = require("@taquito/signer");
const config_util_1 = require("./config-util");
function showAlias(alias) {
    const config = config_util_1.loadUserConfig();
    const aliasesKey = config_util_1.getActiveAliasesCfgKey(config);
    if (alias) {
        const aliasKey = `${aliasesKey}.${alias}`;
        if (config.has(aliasKey)) {
            const aliasDef = config.get(aliasKey);
            console.log(kleur.yellow(formatAlias(alias, aliasDef)));
        }
        else
            console.log(kleur.red(`alias ${kleur.yellow(alias)} is not configured`));
    }
    else {
        const allAliases = Object.getOwnPropertyNames(config.get(aliasesKey));
        for (let a of allAliases) {
            const aliasKey = `${aliasesKey}.${a}`;
            const aliasDef = config.get(aliasKey);
            console.log(kleur.yellow(formatAlias(a, aliasDef)));
        }
    }
}
exports.showAlias = showAlias;
function formatAlias(alias, def) {
    return `${alias}\t${def.address}\t${def.secret ? def.secret : ''}`;
}
function addAlias(alias, key_or_address) {
    return __awaiter(this, void 0, void 0, function* () {
        const config = config_util_1.loadUserConfig();
        const aliasKey = `${config_util_1.getActiveAliasesCfgKey(config)}.${alias}`;
        if (config.has(aliasKey)) {
            console.log(kleur.red(`alias ${kleur.yellow(alias)} already exists`));
            return;
        }
        const aliasDef = yield validateKey(key_or_address);
        if (!aliasDef) {
            console.log(kleur.red('invalid address or secret key'));
            return;
        }
        config.set(aliasKey, aliasDef);
    });
}
exports.addAlias = addAlias;
function validateKey(key_or_address) {
    return __awaiter(this, void 0, void 0, function* () {
        if (utils_1.validateAddress(key_or_address) === utils_1.ValidationResult.VALID)
            return { address: key_or_address };
        else
            try {
                const signer = yield signer_1.InMemorySigner.fromSecretKey(key_or_address);
                const address = yield signer.publicKeyHash();
                return { address, secret: key_or_address, signer };
            }
            catch (_a) {
                return undefined;
            }
    });
}
function removeAlias(alias) {
    const config = config_util_1.loadUserConfig();
    const aliasKey = `${config_util_1.getActiveAliasesCfgKey(config)}.${alias}`;
    if (!config.has(aliasKey)) {
        console.log(kleur.red(`alias ${kleur.yellow(alias)} does not exists`));
        return;
    }
    config.delete(aliasKey);
}
exports.removeAlias = removeAlias;
function resolveAlias2Signer(alias_or_address, config) {
    return __awaiter(this, void 0, void 0, function* () {
        const aliasKey = `${config_util_1.getActiveAliasesCfgKey(config)}.${alias_or_address}`;
        const aliasDef = config.get(aliasKey);
        if (aliasDef === null || aliasDef === void 0 ? void 0 : aliasDef.secret) {
            const ad = yield validateKey(aliasDef.secret);
            if (ad === null || ad === void 0 ? void 0 : ad.signer)
                return ad.signer;
        }
        if (utils_1.validateAddress(alias_or_address) !== utils_1.ValidationResult.VALID)
            return cannotResolve(alias_or_address);
        const ad = findAlias(config, ad => ad.address === alias_or_address);
        if (!(ad === null || ad === void 0 ? void 0 : ad.secret))
            return cannotResolve(alias_or_address);
        return signer_1.InMemorySigner.fromSecretKey(ad.secret);
    });
}
exports.resolveAlias2Signer = resolveAlias2Signer;
function findAlias(config, predicate) {
    const aliasesKey = config_util_1.getActiveAliasesCfgKey(config);
    const allAliases = Object.getOwnPropertyNames(config.get(aliasesKey));
    for (let a of allAliases) {
        const aliasKey = `${aliasesKey}.${a}`;
        const aliasDef = config.get(aliasKey);
        if (predicate(aliasDef))
            return aliasDef;
    }
    return undefined;
}
function resolveAlias2Address(alias_or_address, config) {
    return __awaiter(this, void 0, void 0, function* () {
        if (utils_1.validateAddress(alias_or_address) === utils_1.ValidationResult.VALID)
            return alias_or_address;
        const aliasKey = `${config_util_1.getActiveAliasesCfgKey(config)}.${alias_or_address}`;
        if (!config.has(aliasKey))
            return cannotResolve(alias_or_address);
        const aliasDef = config.get(aliasKey);
        return aliasDef.address;
    });
}
exports.resolveAlias2Address = resolveAlias2Address;
function cannotResolve(alias_or_address) {
    console.log(kleur.red(`${kleur.yellow(alias_or_address)} is not a valid address or configured alias`));
    return Promise.reject('cannot resolve address or alias');
}
