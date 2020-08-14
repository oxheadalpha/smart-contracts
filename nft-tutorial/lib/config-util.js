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
exports.loadFile = exports.inspectorKey = exports.aliasKey = exports.allAliasesKey = exports.activeNetworkKey = exports.loadUserConfig = exports.initUserConfig = exports.userConfigFileWithExt = void 0;
// import Conf from 'conf';
const configstore_1 = __importDefault(require("configstore"));
const path = __importStar(require("path"));
const fs = __importStar(require("fs"));
const kleur = __importStar(require("kleur"));
const packageJson = require('../package.json');
const userConfigFile = path.join(process.cwd(), 'tznft');
exports.userConfigFileWithExt = userConfigFile + '.json';
function initUserConfig() {
    if (fs.existsSync(exports.userConfigFileWithExt)) {
        console.log(kleur.yellow('tznft.json config file already exists'));
    }
    else {
        fs.copyFileSync(path.join(__dirname, '../tznft.json'), exports.userConfigFileWithExt);
        console.log(`${kleur.green('tznft.json')} config file created`);
    }
}
exports.initUserConfig = initUserConfig;
function loadUserConfig() {
    if (fs.existsSync(exports.userConfigFileWithExt)) {
        return new configstore_1.default(packageJson.name, {}, { configPath: exports.userConfigFileWithExt });
    }
    else {
        const msg = 'no tznft.json config file found';
        console.log(kleur.red(msg));
        suggestCommand('config-int');
        throw new Error(msg);
    }
}
exports.loadUserConfig = loadUserConfig;
function activeNetworkKey(config) {
    const network = config.get('activeNetwork');
    if (typeof network === 'string') {
        return `availableNetworks.${network}`;
    }
    else {
        const msg = 'no active network selected';
        console.log(kleur.red(msg));
        suggestCommand('set-network');
        throw new Error(msg);
    }
}
exports.activeNetworkKey = activeNetworkKey;
exports.allAliasesKey = (config) => `${activeNetworkKey(config)}.aliases`;
exports.aliasKey = (alias, config) => `${exports.allAliasesKey(config)}.${alias}`;
exports.inspectorKey = (config) => `${activeNetworkKey(config)}.inspector`;
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
