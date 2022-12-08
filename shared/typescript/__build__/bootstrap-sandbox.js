"use strict";
var __awaiter = (this && this.__awaiter) || function (thisArg, _arguments, P, generator) {
    function adopt(value) { return value instanceof P ? value : new P(function (resolve) { resolve(value); }); }
    return new (P || (P = Promise))(function (resolve, reject) {
        function fulfilled(value) { try { step(generator.next(value)); } catch (e) { reject(e); } }
        function rejected(value) { try { step(generator["throw"](value)); } catch (e) { reject(e); } }
        function step(result) { result.done ? resolve(result.value) : adopt(result.value).then(fulfilled, rejected); }
        step((generator = generator.apply(thisArg, _arguments || [])).next());
    });
};
var __generator = (this && this.__generator) || function (thisArg, body) {
    var _ = { label: 0, sent: function() { if (t[0] & 1) throw t[1]; return t[1]; }, trys: [], ops: [] }, f, y, t, g;
    return g = { next: verb(0), "throw": verb(1), "return": verb(2) }, typeof Symbol === "function" && (g[Symbol.iterator] = function() { return this; }), g;
    function verb(n) { return function (v) { return step([n, v]); }; }
    function step(op) {
        if (f) throw new TypeError("Generator is already executing.");
        while (g && (g = 0, op[0] && (_ = 0)), _) try {
            if (f = 1, y && (t = op[0] & 2 ? y["return"] : op[0] ? y["throw"] || ((t = y["return"]) && t.call(y), 0) : y.next) && !(t = t.call(y, op[1])).done) return t;
            if (y = 0, t) op = [op[0] & 2, t.value];
            switch (op[0]) {
                case 0: case 1: t = op; break;
                case 4: _.label++; return { value: op[1], done: false };
                case 5: _.label++; y = op[1]; op = [0]; continue;
                case 7: op = _.ops.pop(); _.trys.pop(); continue;
                default:
                    if (!(t = _.trys, t = t.length > 0 && t[t.length - 1]) && (op[0] === 6 || op[0] === 2)) { _ = 0; continue; }
                    if (op[0] === 3 && (!t || (op[1] > t[0] && op[1] < t[3]))) { _.label = op[1]; break; }
                    if (op[0] === 6 && _.label < t[1]) { _.label = t[1]; t = op; break; }
                    if (t && _.label < t[2]) { _.label = t[2]; _.ops.push(op); break; }
                    if (t[2]) _.ops.pop();
                    _.trys.pop(); continue;
            }
            op = body.call(thisArg, _);
        } catch (e) { op = [6, e]; y = 0; } finally { f = t = 0; }
        if (op[0] & 5) throw op[1]; return { value: op[0] ? op[1] : void 0, done: true };
    }
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.bootstrapTestnet = exports.bootstrap = void 0;
var taquito_1 = require("@taquito/taquito");
var signer_1 = require("@taquito/signer");
function flextesaKeys() {
    return __awaiter(this, void 0, void 0, function () {
        var bob, alice;
        return __generator(this, function (_a) {
            switch (_a.label) {
                case 0: return [4 /*yield*/, signer_1.InMemorySigner.fromSecretKey('edsk3RFgDiCt7tWB2oe96w1eRw72iYiiqZPLu9nnEY23MYRp2d8Kkx')];
                case 1:
                    bob = _a.sent();
                    return [4 /*yield*/, signer_1.InMemorySigner.fromSecretKey('edsk3QoqBuvdamxouPhin7swCvkQNgq4jP5KZPbwWNnwdZpSpJiEbq')];
                case 2:
                    alice = _a.sent();
                    return [2 /*return*/, { bob: bob, alice: alice }];
            }
        });
    });
}
function testnetKeys() {
    return __awaiter(this, void 0, void 0, function () {
        var bob, alice;
        return __generator(this, function (_a) {
            switch (_a.label) {
                case 0: return [4 /*yield*/, signer_1.InMemorySigner.fromSecretKey('edskRfLsHb49bP4dTpYzAZ7qHCX4ByK2g6Cwq2LWqRYAQSeRpziaZGBW72vrJnp1ahLGKd9rXUf7RHzm8EmyPgseUi3VS9putT')];
                case 1:
                    bob = _a.sent();
                    return [4 /*yield*/, signer_1.InMemorySigner.fromSecretKey('edskRqb8GgnD4d2B7nR3ofJajDU7kwooUzXz7yMwRdLDP9j7Z1DvhaeBcs8WkJ4ELXXJgVkq5tGwrFibojDjYVaG7n4Tq1qDxZ')];
                case 2:
                    alice = _a.sent();
                    return [2 /*return*/, { bob: bob, alice: alice }];
            }
        });
    });
}
function signerToToolkit(signer, rpc) {
    var tezos = new taquito_1.TezosToolkit(rpc);
    tezos.setProvider({
        signer: signer,
        rpc: rpc
    });
    return tezos;
}
function bootstrap() {
    return __awaiter(this, void 0, void 0, function () {
        var _a, bob, alice, rpc, bobTz;
        return __generator(this, function (_b) {
            switch (_b.label) {
                case 0: return [4 /*yield*/, flextesaKeys()];
                case 1:
                    _a = _b.sent(), bob = _a.bob, alice = _a.alice;
                    rpc = 'http://localhost:20000';
                    bobTz = signerToToolkit(bob, rpc);
                    return [2 /*return*/, {
                            bob: bobTz,
                            alice: signerToToolkit(alice, rpc)
                        }];
            }
        });
    });
}
exports.bootstrap = bootstrap;
function bootstrapTestnet() {
    return __awaiter(this, void 0, void 0, function () {
        var _a, bob, alice, rpc;
        return __generator(this, function (_b) {
            switch (_b.label) {
                case 0: return [4 /*yield*/, testnetKeys()];
                case 1:
                    _a = _b.sent(), bob = _a.bob, alice = _a.alice;
                    rpc = 'https://testnet-tezos.giganode.io';
                    return [2 /*return*/, {
                            bob: signerToToolkit(bob, rpc),
                            alice: signerToToolkit(alice, rpc)
                        }];
            }
        });
    });
}
exports.bootstrapTestnet = bootstrapTestnet;
//# sourceMappingURL=data:application/json;base64,eyJ2ZXJzaW9uIjozLCJmaWxlIjoiYm9vdHN0cmFwLXNhbmRib3guanMiLCJzb3VyY2VSb290IjoiIiwic291cmNlcyI6WyIuLi9ib290c3RyYXAtc2FuZGJveC50cyJdLCJuYW1lcyI6W10sIm1hcHBpbmdzIjoiOzs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7QUFBQSw0Q0FBZ0Q7QUFFaEQsMENBQWlEO0FBT2pELFNBQWUsWUFBWTs7Ozs7d0JBQ2IscUJBQU0sdUJBQWMsQ0FBQyxhQUFhLENBQzVDLHdEQUF3RCxDQUN6RCxFQUFBOztvQkFGSyxHQUFHLEdBQUcsU0FFWDtvQkFDYSxxQkFBTSx1QkFBYyxDQUFDLGFBQWEsQ0FDOUMsd0RBQXdELENBQ3pELEVBQUE7O29CQUZLLEtBQUssR0FBRyxTQUViO29CQUNELHNCQUFPLEVBQUUsR0FBRyxLQUFBLEVBQUUsS0FBSyxPQUFBLEVBQUUsRUFBQzs7OztDQUN2QjtBQUVELFNBQWUsV0FBVzs7Ozs7d0JBQ1oscUJBQU0sdUJBQWMsQ0FBQyxhQUFhLENBQzVDLG9HQUFvRyxDQUNyRyxFQUFBOztvQkFGSyxHQUFHLEdBQUcsU0FFWDtvQkFDYSxxQkFBTSx1QkFBYyxDQUFDLGFBQWEsQ0FDOUMsb0dBQW9HLENBQ3JHLEVBQUE7O29CQUZLLEtBQUssR0FBRyxTQUViO29CQUNELHNCQUFPLEVBQUUsR0FBRyxLQUFBLEVBQUUsS0FBSyxPQUFBLEVBQUUsRUFBQzs7OztDQUN2QjtBQU9ELFNBQVMsZUFBZSxDQUFDLE1BQWMsRUFBRSxHQUFXO0lBQ2xELElBQU0sS0FBSyxHQUFHLElBQUksc0JBQVksQ0FBQyxHQUFHLENBQUMsQ0FBQztJQUNwQyxLQUFLLENBQUMsV0FBVyxDQUFDO1FBQ2hCLE1BQU0sUUFBQTtRQUNOLEdBQUcsS0FBQTtLQUNKLENBQUMsQ0FBQztJQUNILE9BQU8sS0FBSyxDQUFDO0FBQ2YsQ0FBQztBQUVELFNBQXNCLFNBQVM7Ozs7O3dCQUNOLHFCQUFNLFlBQVksRUFBRSxFQUFBOztvQkFBckMsS0FBaUIsU0FBb0IsRUFBbkMsR0FBRyxTQUFBLEVBQUUsS0FBSyxXQUFBO29CQUNaLEdBQUcsR0FBRyx3QkFBd0IsQ0FBQztvQkFDL0IsS0FBSyxHQUFHLGVBQWUsQ0FBQyxHQUFHLEVBQUUsR0FBRyxDQUFDLENBQUM7b0JBRXhDLHNCQUFPOzRCQUNMLEdBQUcsRUFBRSxLQUFLOzRCQUNWLEtBQUssRUFBRSxlQUFlLENBQUMsS0FBSyxFQUFFLEdBQUcsQ0FBQzt5QkFDbkMsRUFBQzs7OztDQUNIO0FBVEQsOEJBU0M7QUFFRCxTQUFzQixnQkFBZ0I7Ozs7O3dCQUNiLHFCQUFNLFdBQVcsRUFBRSxFQUFBOztvQkFBcEMsS0FBaUIsU0FBbUIsRUFBbEMsR0FBRyxTQUFBLEVBQUUsS0FBSyxXQUFBO29CQUNaLEdBQUcsR0FBRyxtQ0FBbUMsQ0FBQztvQkFDaEQsc0JBQU87NEJBQ0wsR0FBRyxFQUFFLGVBQWUsQ0FBQyxHQUFHLEVBQUUsR0FBRyxDQUFDOzRCQUM5QixLQUFLLEVBQUUsZUFBZSxDQUFDLEtBQUssRUFBRSxHQUFHLENBQUM7eUJBQ25DLEVBQUM7Ozs7Q0FDSDtBQVBELDRDQU9DIiwic291cmNlc0NvbnRlbnQiOlsiaW1wb3J0IHsgVGV6b3NUb29sa2l0IH0gZnJvbSAnQHRhcXVpdG8vdGFxdWl0byc7XG5pbXBvcnQgeyBTaWduZXIgfSBmcm9tICdAdGFxdWl0by90YXF1aXRvL2Rpc3QvdHlwZXMvc2lnbmVyL2ludGVyZmFjZSc7XG5pbXBvcnQgeyBJbk1lbW9yeVNpZ25lciB9IGZyb20gJ0B0YXF1aXRvL3NpZ25lcic7XG5cbnR5cGUgVGVzdEtleXMgPSB7XG4gIGJvYjogU2lnbmVyO1xuICBhbGljZTogU2lnbmVyO1xufTtcblxuYXN5bmMgZnVuY3Rpb24gZmxleHRlc2FLZXlzKCk6IFByb21pc2U8VGVzdEtleXM+IHtcbiAgY29uc3QgYm9iID0gYXdhaXQgSW5NZW1vcnlTaWduZXIuZnJvbVNlY3JldEtleShcbiAgICAnZWRzazNSRmdEaUN0N3RXQjJvZTk2dzFlUnc3MmlZaWlxWlBMdTlubkVZMjNNWVJwMmQ4S2t4J1xuICApO1xuICBjb25zdCBhbGljZSA9IGF3YWl0IEluTWVtb3J5U2lnbmVyLmZyb21TZWNyZXRLZXkoXG4gICAgJ2Vkc2szUW9xQnV2ZGFteG91UGhpbjdzd0N2a1FOZ3E0alA1S1pQYndXTm53ZFpwU3BKaUVicSdcbiAgKTtcbiAgcmV0dXJuIHsgYm9iLCBhbGljZSB9O1xufVxuXG5hc3luYyBmdW5jdGlvbiB0ZXN0bmV0S2V5cygpOiBQcm9taXNlPFRlc3RLZXlzPiB7XG4gIGNvbnN0IGJvYiA9IGF3YWl0IEluTWVtb3J5U2lnbmVyLmZyb21TZWNyZXRLZXkoXG4gICAgJ2Vkc2tSZkxzSGI0OWJQNGRUcFl6QVo3cUhDWDRCeUsyZzZDd3EyTFdxUllBUVNlUnB6aWFaR0JXNzJ2ckpucDFhaExHS2Q5clhVZjdSSHptOEVteVBnc2VVaTNWUzlwdXRUJ1xuICApO1xuICBjb25zdCBhbGljZSA9IGF3YWl0IEluTWVtb3J5U2lnbmVyLmZyb21TZWNyZXRLZXkoXG4gICAgJ2Vkc2tScWI4R2duRDRkMkI3blIzb2ZKYWpEVTdrd29vVXpYejd5TXdSZExEUDlqN1oxRHZoYWVCY3M4V2tKNEVMWFhKZ1ZrcTV0R3dyRmlib2pEallWYUc3bjRUcTFxRHhaJ1xuICApO1xuICByZXR1cm4geyBib2IsIGFsaWNlIH07XG59XG5cbmV4cG9ydCB0eXBlIFRlc3RUeiA9IHtcbiAgYm9iOiBUZXpvc1Rvb2xraXQ7XG4gIGFsaWNlOiBUZXpvc1Rvb2xraXQ7XG59O1xuXG5mdW5jdGlvbiBzaWduZXJUb1Rvb2xraXQoc2lnbmVyOiBTaWduZXIsIHJwYzogc3RyaW5nKTogVGV6b3NUb29sa2l0IHtcbiAgY29uc3QgdGV6b3MgPSBuZXcgVGV6b3NUb29sa2l0KHJwYyk7XG4gIHRlem9zLnNldFByb3ZpZGVyKHtcbiAgICBzaWduZXIsXG4gICAgcnBjXG4gIH0pO1xuICByZXR1cm4gdGV6b3M7XG59XG5cbmV4cG9ydCBhc3luYyBmdW5jdGlvbiBib290c3RyYXAoKTogUHJvbWlzZTxUZXN0VHo+IHtcbiAgY29uc3QgeyBib2IsIGFsaWNlIH0gPSBhd2FpdCBmbGV4dGVzYUtleXMoKTtcbiAgY29uc3QgcnBjID0gJ2h0dHA6Ly9sb2NhbGhvc3Q6MjAwMDAnO1xuICBjb25zdCBib2JUeiA9IHNpZ25lclRvVG9vbGtpdChib2IsIHJwYyk7XG5cbiAgcmV0dXJuIHtcbiAgICBib2I6IGJvYlR6LFxuICAgIGFsaWNlOiBzaWduZXJUb1Rvb2xraXQoYWxpY2UsIHJwYylcbiAgfTtcbn1cblxuZXhwb3J0IGFzeW5jIGZ1bmN0aW9uIGJvb3RzdHJhcFRlc3RuZXQoKTogUHJvbWlzZTxUZXN0VHo+IHtcbiAgY29uc3QgeyBib2IsIGFsaWNlIH0gPSBhd2FpdCB0ZXN0bmV0S2V5cygpO1xuICBjb25zdCBycGMgPSAnaHR0cHM6Ly90ZXN0bmV0LXRlem9zLmdpZ2Fub2RlLmlvJztcbiAgcmV0dXJuIHtcbiAgICBib2I6IHNpZ25lclRvVG9vbGtpdChib2IsIHJwYyksXG4gICAgYWxpY2U6IHNpZ25lclRvVG9vbGtpdChhbGljZSwgcnBjKVxuICB9O1xufVxuIl19