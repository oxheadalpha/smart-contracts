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
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.loadFile = exports.getInspectorKey = exports.getActiveAliasesCfgKey = exports.getActiveNetworkCfg = exports.loadUserConfig = exports.userConfigFileWithExt = void 0;
const conf_1 = __importDefault(require("conf"));
const path = __importStar(require("path"));
const fs = __importStar(require("fs"));
const kleur = __importStar(require("kleur"));
const userConfigFile = path.join(process.cwd(), 'tznft');
exports.userConfigFileWithExt = userConfigFile + '.json';
function loadUserConfig() {
    if (fs.existsSync(exports.userConfigFileWithExt))
        return new conf_1.default({
            configName: 'tznft',
            cwd: process.cwd(),
            serialize: v => JSON.stringify(v, null, 2)
        });
    else {
        const msg = 'no tznft.json config file found';
        console.log(kleur.red(msg));
        suggestCommand('config-int');
        throw new Error(msg);
    }
}
exports.loadUserConfig = loadUserConfig;
function getActiveNetworkCfg(config) {
    const network = config.get('activeNetwork');
    if (!network) {
        console.log(kleur.red('No active network selected'));
        suggestCommand('set-network <network>');
        throw new Error('No active network selected');
    }
    const configKey = `availableNetworks.${network}`;
    if (!config.has(configKey)) {
        const msg = `Currently active network ${kleur.yellow(network)}  is not configured`;
        console.log(kleur.red(msg));
        suggestCommand('set-network <network>');
        throw new Error(msg);
    }
    return { network, configKey };
}
exports.getActiveNetworkCfg = getActiveNetworkCfg;
function getActiveAliasesCfgKey(config, validate = true) {
    const { configKey } = getActiveNetworkCfg(config);
    const aliasesConfigKey = `${configKey}.aliases`;
    if (!config.has(aliasesConfigKey) && validate) {
        const msg = 'there are no configured account aliases';
        console.log(kleur.red(msg));
        throw new Error(msg);
    }
    return aliasesConfigKey;
}
exports.getActiveAliasesCfgKey = getActiveAliasesCfgKey;
function getInspectorKey(config) {
    const { configKey } = getActiveNetworkCfg(config);
    return `${configKey}.inspector`;
}
exports.getInspectorKey = getInspectorKey;
function loadFile(filePath) {
    return __awaiter(this, void 0, void 0, function* () {
        return new Promise((resolve, reject) => {
            if (!fs.existsSync(filePath))
                reject(`file ${filePath} does not exist`);
            else
                fs.readFile(filePath, (err, buff) => err ? reject(err) : resolve(buff.toString()));
        });
    });
}
exports.loadFile = loadFile;
function suggestCommand(cmd) {
    console.log(`Try to run ${kleur.green(`tznft ${cmd}`)} command to create default config`);
}
