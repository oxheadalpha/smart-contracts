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
exports.parseTokens = exports.mintNfts = exports.originateInspector = exports.createToolkit = void 0;
const kleur = __importStar(require("kleur"));
const fs = __importStar(require("fs"));
const path = __importStar(require("path"));
const bignumber_js_1 = require("bignumber.js");
const taquito_1 = require("@taquito/taquito");
const config_util_1 = require("./config-util");
const config_aliases_1 = require("./config-aliases");
function createToolkit(signer, config) {
    const { network, configKey } = config_util_1.getActiveNetworkCfg(config);
    const providerUrl = config.get(`${configKey}.providerUrl`);
    if (!providerUrl) {
        const msg = `network provider for ${kleur.yellow(network)} URL is not configured`;
        console.log(kleur.red(msg));
        throw new Error(msg);
    }
    const toolkit = new taquito_1.TezosToolkit();
    toolkit.setProvider({
        signer,
        rpc: providerUrl,
        config: { confirmationPollingIntervalSecond: 5 }
    });
    return toolkit;
}
exports.createToolkit = createToolkit;
function originateInspector(tezos) {
    return __awaiter(this, void 0, void 0, function* () {
        const code = yield loadFile(path.join(__dirname, '../ligo/out/inspector.tz'));
        const storage = `(Left Unit)`;
        return originateContract(tezos, code, storage, 'inspector');
    });
}
exports.originateInspector = originateInspector;
function mintNfts(owner, tokens) {
    return __awaiter(this, void 0, void 0, function* () {
        const config = config_util_1.loadUserConfig();
        const signer = yield config_aliases_1.resolveAlias2Signer(owner, config);
        const ownerAddress = yield signer.publicKeyHash();
        const tz = createToolkit(signer, config);
        const code = yield loadFile(path.join(__dirname, '../ligo/out/fa2_fixed_collection_token.tz'));
        const storage = createNftStorage(tokens, ownerAddress);
        console.log(kleur.yellow('originating new NFT contract'));
        const nftAddress = yield originateContract(tz, code, storage, 'nft');
        console.log(kleur.yellow(`originated NFT collection ${kleur.green(nftAddress)}`));
    });
}
exports.mintNfts = mintNfts;
function parseTokens(descriptor, tokens) {
    const [id, symbol, name] = descriptor.split(',');
    const token = {
        token_id: new bignumber_js_1.BigNumber(id),
        symbol,
        name,
        decimals: new bignumber_js_1.BigNumber(0),
        extras: new taquito_1.MichelsonMap()
    };
    tokens.push(token);
    return tokens;
}
exports.parseTokens = parseTokens;
function createNftStorage(tokens, owner) {
    const ledger = new taquito_1.MichelsonMap();
    const token_metadata = new taquito_1.MichelsonMap();
    for (let meta of tokens) {
        ledger.set(meta.token_id, owner);
        token_metadata.set(meta.token_id, meta);
    }
    return {
        ledger,
        operators: new taquito_1.MichelsonMap(),
        token_metadata
    };
}
function loadFile(filePath) {
    return __awaiter(this, void 0, void 0, function* () {
        return new Promise((resolve, reject) => fs.readFile(filePath, (err, buff) => err ? reject(err) : resolve(buff.toString())));
    });
}
function originateContract(tz, code, storage, name) {
    return __awaiter(this, void 0, void 0, function* () {
        const origParam = typeof storage === 'string' ? { code, init: storage } : { code, storage };
        try {
            const originationOp = yield tz.contract.originate(origParam);
            const contract = yield originationOp.contract();
            return contract.address;
        }
        catch (error) {
            const jsonError = JSON.stringify(error, null, 2);
            console.log(kleur.red(`${name} origination error ${jsonError}`));
            return Promise.reject(jsonError);
        }
    });
}
