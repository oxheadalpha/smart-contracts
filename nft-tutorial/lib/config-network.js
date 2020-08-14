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
exports.showConfig = exports.setNetwork = exports.showActiveNetwork = void 0;
const kleur = __importStar(require("kleur"));
const config_util_1 = require("./config-util");
function showActiveNetwork(all) {
    const config = config_util_1.loadUserConfig();
    const network = config.get('activeNetwork');
    if (!all)
        console.log(`active network: ${network ? kleur.green(network) : kleur.red('not selected')}`);
    else {
        const allNetworks = Object.getOwnPropertyNames(config.all.availableNetworks);
        for (let n of allNetworks) {
            if (n === network)
                console.log(kleur.bold().green(`* ${n}`));
            else
                console.log(kleur.yellow(`  ${n}`));
        }
        if (!network)
            console.log(`active network: ${kleur.red('not selected')}`);
    }
}
exports.showActiveNetwork = showActiveNetwork;
function setNetwork(network) {
    const config = config_util_1.loadUserConfig();
    if (!config.has(`availableNetworks.${network}`))
        console.log(kleur.red(`network ${kleur.yellow(network)} is not available in configuration`));
    else {
        config.set('activeNetwork', network);
        console.log(`network ${kleur.green(network)} is selected`);
    }
}
exports.setNetwork = setNetwork;
function showConfig() {
    const config = config_util_1.loadUserConfig();
    const c = JSON.stringify(config.all, null, 2);
    console.info(c);
}
exports.showConfig = showConfig;
