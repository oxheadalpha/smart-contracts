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
exports.addOperator = exports.transfer = void 0;
const kleur = __importStar(require("kleur"));
function transfer(fa2, operator, txs) {
    return __awaiter(this, void 0, void 0, function* () {
        console.log(kleur.yellow('transferring tokens...'));
        const nftWithOperator = yield operator.contract.at(fa2);
        const op = yield nftWithOperator.methods.transfer(txs).send();
        const hash = yield op.confirmation();
        console.log(kleur.green('tokens transferred'));
    });
}
exports.transfer = transfer;
function addOperator(fa2, owner, operator) {
    return __awaiter(this, void 0, void 0, function* () {
        console.log(kleur.yellow('adding operator...'));
        const fa2WithOwner = yield owner.contract.at(fa2);
        const ownerAddress = yield owner.signer.publicKeyHash();
        const op = yield fa2WithOwner.methods
            .update_operators([
            {
                add_operator: {
                    owner: ownerAddress,
                    operator
                }
            }
        ])
            .send();
        yield op.confirmation();
        console.log(kleur.green('added operator'));
    });
}
exports.addOperator = addOperator;
