#!/usr/bin/env node
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
const commander_1 = require("commander");
const networkConf = __importStar(require("./config-network"));
const aliasConf = __importStar(require("./config-aliases"));
// configuration commands
//prettier-ignore
commander_1.program
    .command('config-init')
    .alias('ci')
    .description('creates tznft.config file')
    .action(networkConf.initUserConfig);
//prettier-ignore
commander_1.program
    .command('show-network')
    .alias('shown')
    .description('shows currently selected active network', { 'a': 'also shows all available networks' })
    .option('-a --all', 'shows all available configured networks', false)
    .action((options) => networkConf.showActiveNetwork(options.all)).passCommandToAction(false);
//prettier-ignore
commander_1.program
    .command('set-network')
    .alias('setn')
    .arguments('<network>')
    .description('selected network to originate contracts')
    .action(networkConf.setNetwork);
//aliases
//prettier-ignore
commander_1.program
    .command('show-alias')
    .alias('showa')
    .arguments('[alias]')
    .action(aliasConf.showAlias).passCommandToAction(false);
//prettier-ignore
commander_1.program
    .command('add-alias')
    .alias('adda')
    .description('adds new alias to the configuration')
    .arguments('<alias> <key_or_address>')
    .action(aliasConf.addAlias).passCommandToAction(false);
//prettier-ignore
commander_1.program
    .command('remove-alias')
    .alias('rma')
    .description('removes alias from the configuration')
    .arguments('<alias>')
    .action(aliasConf.removeAlias).passCommandToAction(false);
//prettier-ignore
commander_1.program
    .command('config-show-all')
    .description('shows whole raw config')
    .action(networkConf.showConfig);
commander_1.program.parse();
