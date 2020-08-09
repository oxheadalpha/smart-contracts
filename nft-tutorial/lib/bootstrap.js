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
exports.kill = exports.start = void 0;
const child = __importStar(require("child_process"));
const kleur = __importStar(require("kleur"));
const config_util_1 = require("./config-util");
function start() {
    return __awaiter(this, void 0, void 0, function* () {
        const config = config_util_1.loadUserConfig();
        const { network, configKey } = config_util_1.getActiveNetworkCfg(config);
        if (network === 'sandbox') {
            //start and wait
            yield new Promise((resolve, reject) => child.exec('sh ../flextesa/start-sandbox.sh', { cwd: __dirname }, (err, stdout, errout) => {
                if (err) {
                    console.log(kleur.red('failed to start sandbox'));
                    console.log(kleur.red().dim(errout));
                    reject();
                }
                else {
                    console.log(kleur.yellow().dim(stdout));
                    resolve();
                }
            }));
            console.log(kleur.yellow('starting sandbox...'));
        }
    });
}
exports.start = start;
function kill() {
    return __awaiter(this, void 0, void 0, function* () {
        const config = config_util_1.loadUserConfig();
        const { network, configKey } = config_util_1.getActiveNetworkCfg(config);
        if (network === 'sandbox') {
            //start and wait
            yield new Promise((resolve, reject) => child.exec('sh ../flextesa/kill-sandbox.sh', { cwd: __dirname }, (err, stdout, errout) => {
                if (err) {
                    console.log(kleur.red('failed to stop sandbox'));
                    console.log(kleur.red().dim(errout));
                    reject();
                }
                else {
                    console.log(kleur.yellow().dim(stdout));
                    resolve();
                }
            }));
            console.log(kleur.yellow('killed sandbox.'));
        }
    });
}
exports.kill = kill;
