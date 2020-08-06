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
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.showConfig = exports.setNetwork = exports.showActiveNetwork = exports.initUserConfig = void 0;
const conf_1 = __importDefault(require("conf"));
// import {Schema} from 'conf';
const path = __importStar(require("path"));
const fs = __importStar(require("fs"));
const kleur = __importStar(require("kleur"));
const userConfigFile = path.join(process.cwd(), 'tznft');
const userConfigFileWithExt = userConfigFile + '.json';
function loadUserConfig() {
    if (fs.existsSync(userConfigFileWithExt))
        return new conf_1.default({
            configName: 'tznft',
            cwd: process.cwd(),
            serialize: v => JSON.stringify(v, null, 2)
        });
    else {
        console.log(kleur.red('no tznft.json config file found'));
        console.log(`Try to run ${kleur.green('tznft config init')} command to create default config`);
        throw new Error('no tznft.json config file found');
    }
}
function initUserConfig() {
    if (fs.existsSync(userConfigFileWithExt)) {
        console.log(kleur.yellow('tznft.json config file already exists'));
    }
    else {
        fs.copyFileSync(path.join(__dirname, '../tznft.json'), userConfigFileWithExt);
        console.log(`${kleur.green('tznft.json')} config file created`);
    }
}
exports.initUserConfig = initUserConfig;
function showActiveNetwork() {
    const config = loadUserConfig();
    const network = config.get('activeNetwork', 'no network selected');
    console.log(`active network: ${kleur.green(network)}`);
}
exports.showActiveNetwork = showActiveNetwork;
function setNetwork(network) {
    const config = loadUserConfig();
    if (!config.has(`availableNetworks.${network}`))
        console.log(kleur.red(`network ${kleur.yellow(network)} is not available in configuration`));
    else {
        config.set('activeNetwork', network);
        console.log(`network ${kleur.green(network)} is selected`);
    }
}
exports.setNetwork = setNetwork;
function showConfig() {
    const config = loadUserConfig();
    const c = JSON.stringify(config.store, null, 2);
    console.info(c);
}
exports.showConfig = showConfig;
