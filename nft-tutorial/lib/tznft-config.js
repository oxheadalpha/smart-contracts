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
const conf = __importStar(require("./config"));
const cli = new commander_1.Command();
const cfg = cli.command('config');
//prettier-ignore
cfg
    .command('init')
    .description('creates tznft.config file')
    .action(conf.initUserConfig);
//prettier-ignore
cfg
    .command('show-network')
    .description('shows currently selected active network')
    .action(conf.showActiveNetwork);
//prettier-ignore
cfg
    .command('set-network')
    .arguments('<network>')
    .description('selected network to originate contracts')
    .action(conf.setNetwork);
//prettier-ignore
cfg
    .command('show-all')
    .action(conf.showConfig);
cfg.parse();
