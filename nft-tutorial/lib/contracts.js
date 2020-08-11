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
exports.transfer = exports.parseTransfers = exports.getBalances = exports.parseTokens = exports.mintNfts = exports.originateInspector = exports.createToolkit = void 0;
const kleur = __importStar(require("kleur"));
const path = __importStar(require("path"));
const bignumber_js_1 = require("bignumber.js");
const taquito_1 = require("@taquito/taquito");
const config_util_1 = require("./config-util");
const config_aliases_1 = require("./config-aliases");
const fa2 = __importStar(require("./fa2-interface"));
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
        const code = yield config_util_1.loadFile(path.join(__dirname, '../ligo/out/inspector.tz'));
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
        const code = yield config_util_1.loadFile(path.join(__dirname, '../ligo/out/fa2_fixed_collection_token.tz'));
        const storage = createNftStorage(tokens, ownerAddress);
        console.log(kleur.yellow('originating new NFT contract'));
        const nftAddress = yield originateContract(tz, code, storage, 'nft');
        console.log(kleur.yellow(`originated NFT collection ${kleur.green(nftAddress)}`));
    });
}
exports.mintNfts = mintNfts;
function parseTokens(descriptor, tokens) {
    const [id, symbol, name] = descriptor.split(',').map(p => p.trim());
    const token = {
        token_id: new bignumber_js_1.BigNumber(id),
        symbol,
        name,
        decimals: new bignumber_js_1.BigNumber(0),
        extras: new taquito_1.MichelsonMap()
    };
    return [token].concat(tokens);
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
function getBalances(operator, nft, owner, tokens) {
    return __awaiter(this, void 0, void 0, function* () {
        const config = config_util_1.loadUserConfig();
        const signer = yield config_aliases_1.resolveAlias2Signer(operator, config);
        const tz = createToolkit(signer, config);
        const ownerAddress = yield config_aliases_1.resolveAlias2Address(owner, config);
        const requests = tokens.map(t => {
            return { token_id: new bignumber_js_1.BigNumber(t), owner: ownerAddress };
        });
        const inspectorKey = config_util_1.getInspectorKey(config);
        const inspectorAddress = config.get(inspectorKey);
        if (!inspectorAddress) {
            console.log(kleur.red('Cannot find deployed balance inspector contract.\nTry to kill and start network again.'));
            return;
        }
        console.log(kleur.yellow(`querying NFT contract ${kleur.green(nft)} using balance inspector ${kleur.green(inspectorAddress)}`));
        const inspector = yield tz.contract.at(inspectorAddress);
        const balanceOp = yield inspector.methods.query(nft, requests).send();
        yield balanceOp.confirmation();
        const storage = yield inspector.storage();
        if (Array.isArray(storage))
            printBalances(storage);
        else {
            console.log(kleur.red('invalid inspector storage state'));
            return Promise.reject('Invalid inspector storage state Empty.');
        }
    });
}
exports.getBalances = getBalances;
function printBalances(balances) {
    console.log(kleur.green('requested NFT balances:'));
    for (let b of balances) {
        console.log(kleur.yellow(`owner: ${kleur.green(b.request.owner)}\ttoken: ${kleur.green(b.request.token_id.toString())}\tbalance: ${kleur.green(b.balance.toString())}`));
    }
}
function parseTransfers(description, transfers) {
    const [from_, to_, token_id] = description.split(',').map(p => p.trim());
    const tx = {
        from_,
        txs: [
            {
                to_,
                token_id: new bignumber_js_1.BigNumber(token_id),
                amount: new bignumber_js_1.BigNumber(1)
            }
        ]
    };
    if (transfers.length > 0 && transfers[0].from_ === from_) {
        //merge last two transfers if their from_ addresses are the same
        transfers[0].txs = transfers[0].txs.concat(tx.txs);
        return transfers;
    }
    return [tx].concat(transfers);
}
exports.parseTransfers = parseTransfers;
function transfer(operator, nft, tokens) {
    return __awaiter(this, void 0, void 0, function* () {
        const config = config_util_1.loadUserConfig();
        const txs = yield resolveTxAddresses(tokens, config);
        const signer = yield config_aliases_1.resolveAlias2Signer(operator, config);
        const operatorAddress = yield signer.publicKeyHash();
        const tz = createToolkit(signer, config);
        yield fa2.transfer(nft, tz, txs);
    });
}
exports.transfer = transfer;
function resolveTxAddresses(tokens, config) {
    return __awaiter(this, void 0, void 0, function* () {
        const resolved = tokens.map((t) => __awaiter(this, void 0, void 0, function* () {
            return {
                from_: yield config_aliases_1.resolveAlias2Address(t.from_, config),
                txs: yield resolveTxDestinationAddresses(t.txs, config)
            };
        }));
        return Promise.all(resolved);
    });
}
function resolveTxDestinationAddresses(txs, config) {
    return __awaiter(this, void 0, void 0, function* () {
        const resolved = txs.map((t) => __awaiter(this, void 0, void 0, function* () {
            return {
                to_: yield config_aliases_1.resolveAlias2Address(t.to_, config),
                amount: t.amount,
                token_id: t.token_id
            };
        }));
        return Promise.all(resolved);
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
