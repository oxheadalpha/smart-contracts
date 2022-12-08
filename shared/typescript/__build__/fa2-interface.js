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
exports.updateOperators = exports.isRemoveOperator = exports.isAddOperator = exports.transfer = void 0;
var logger_1 = require("@tsed/logger");
function transfer(fa2, operator, txs) {
    return __awaiter(this, void 0, void 0, function () {
        var nftWithOperator, op, hash;
        return __generator(this, function (_a) {
            switch (_a.label) {
                case 0:
                    logger_1.$log.info('transferring');
                    return [4 /*yield*/, operator.contract.at(fa2)];
                case 1:
                    nftWithOperator = _a.sent();
                    return [4 /*yield*/, nftWithOperator.methods.transfer(txs).send()];
                case 2:
                    op = _a.sent();
                    return [4 /*yield*/, op.confirmation(3)];
                case 3:
                    hash = _a.sent();
                    logger_1.$log.info("consumed gas: ".concat(op.consumedGas));
                    return [2 /*return*/];
            }
        });
    });
}
exports.transfer = transfer;
var isAddOperator = function (op) {
    return op.hasOwnProperty('add_operator');
};
exports.isAddOperator = isAddOperator;
var isRemoveOperator = function (op) {
    return op.hasOwnProperty('remove_operator');
};
exports.isRemoveOperator = isRemoveOperator;
function updateOperators(fa2, owner, operators) {
    return __awaiter(this, void 0, void 0, function () {
        var fa2WithOwner, ownerAddress, op;
        return __generator(this, function (_a) {
            switch (_a.label) {
                case 0:
                    logger_1.$log.info('adding operator');
                    return [4 /*yield*/, owner.contract.at(fa2)];
                case 1:
                    fa2WithOwner = _a.sent();
                    return [4 /*yield*/, owner.signer.publicKeyHash()];
                case 2:
                    ownerAddress = _a.sent();
                    return [4 /*yield*/, fa2WithOwner.methods.update_operators(operators).send()];
                case 3:
                    op = _a.sent();
                    return [4 /*yield*/, op.confirmation(3)];
                case 4:
                    _a.sent();
                    logger_1.$log.info("consumed gas: ".concat(op.consumedGas));
                    return [2 /*return*/];
            }
        });
    });
}
exports.updateOperators = updateOperators;
//# sourceMappingURL=data:application/json;base64,eyJ2ZXJzaW9uIjozLCJmaWxlIjoiZmEyLWludGVyZmFjZS5qcyIsInNvdXJjZVJvb3QiOiIiLCJzb3VyY2VzIjpbIi4uL2ZhMi1pbnRlcmZhY2UudHMiXSwibmFtZXMiOltdLCJtYXBwaW5ncyI6Ijs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7O0FBQUEsdUNBQW9DO0FBeUJwQyxTQUFzQixRQUFRLENBQzVCLEdBQVksRUFDWixRQUFzQixFQUN0QixHQUFrQjs7Ozs7O29CQUVsQixhQUFJLENBQUMsSUFBSSxDQUFDLGNBQWMsQ0FBQyxDQUFDO29CQUNGLHFCQUFNLFFBQVEsQ0FBQyxRQUFRLENBQUMsRUFBRSxDQUFDLEdBQUcsQ0FBQyxFQUFBOztvQkFBakQsZUFBZSxHQUFHLFNBQStCO29CQUU1QyxxQkFBTSxlQUFlLENBQUMsT0FBTyxDQUFDLFFBQVEsQ0FBQyxHQUFHLENBQUMsQ0FBQyxJQUFJLEVBQUUsRUFBQTs7b0JBQXZELEVBQUUsR0FBRyxTQUFrRDtvQkFFaEQscUJBQU0sRUFBRSxDQUFDLFlBQVksQ0FBQyxDQUFDLENBQUMsRUFBQTs7b0JBQS9CLElBQUksR0FBRyxTQUF3QjtvQkFDckMsYUFBSSxDQUFDLElBQUksQ0FBQyx3QkFBaUIsRUFBRSxDQUFDLFdBQVcsQ0FBRSxDQUFDLENBQUM7Ozs7O0NBQzlDO0FBWkQsNEJBWUM7QUFXTSxJQUFNLGFBQWEsR0FBRyxVQUFDLEVBQWtCO0lBQzlDLE9BQUEsRUFBRSxDQUFDLGNBQWMsQ0FBQyxjQUFjLENBQUM7QUFBakMsQ0FBaUMsQ0FBQztBQUR2QixRQUFBLGFBQWEsaUJBQ1U7QUFFN0IsSUFBTSxnQkFBZ0IsR0FBRyxVQUFDLEVBQWtCO0lBQ2pELE9BQUEsRUFBRSxDQUFDLGNBQWMsQ0FBQyxpQkFBaUIsQ0FBQztBQUFwQyxDQUFvQyxDQUFDO0FBRDFCLFFBQUEsZ0JBQWdCLG9CQUNVO0FBRXZDLFNBQXNCLGVBQWUsQ0FDbkMsR0FBWSxFQUNaLEtBQW1CLEVBQ25CLFNBQTJCOzs7Ozs7b0JBRTNCLGFBQUksQ0FBQyxJQUFJLENBQUMsaUJBQWlCLENBQUMsQ0FBQztvQkFDUixxQkFBTSxLQUFLLENBQUMsUUFBUSxDQUFDLEVBQUUsQ0FBQyxHQUFHLENBQUMsRUFBQTs7b0JBQTNDLFlBQVksR0FBRyxTQUE0QjtvQkFDNUIscUJBQU0sS0FBSyxDQUFDLE1BQU0sQ0FBQyxhQUFhLEVBQUUsRUFBQTs7b0JBQWpELFlBQVksR0FBRyxTQUFrQztvQkFDNUMscUJBQU0sWUFBWSxDQUFDLE9BQU8sQ0FBQyxnQkFBZ0IsQ0FBQyxTQUFTLENBQUMsQ0FBQyxJQUFJLEVBQUUsRUFBQTs7b0JBQWxFLEVBQUUsR0FBRyxTQUE2RDtvQkFDeEUscUJBQU0sRUFBRSxDQUFDLFlBQVksQ0FBQyxDQUFDLENBQUMsRUFBQTs7b0JBQXhCLFNBQXdCLENBQUM7b0JBQ3pCLGFBQUksQ0FBQyxJQUFJLENBQUMsd0JBQWlCLEVBQUUsQ0FBQyxXQUFXLENBQUUsQ0FBQyxDQUFDOzs7OztDQUM5QztBQVhELDBDQVdDIiwic291cmNlc0NvbnRlbnQiOlsiaW1wb3J0IHsgJGxvZyB9IGZyb20gJ0B0c2VkL2xvZ2dlcic7XG5pbXBvcnQgeyBUZXpvc1Rvb2xraXQgfSBmcm9tICdAdGFxdWl0by90YXF1aXRvJztcbmltcG9ydCB7IENvbnRyYWN0LCBhZGRyZXNzLCBuYXQgfSBmcm9tICcuL3R5cGUtYWxpYXNlcyc7XG5cbmV4cG9ydCBpbnRlcmZhY2UgRmEyVHJhbnNmZXJEZXN0aW5hdGlvbiB7XG4gIHRvXzogYWRkcmVzcztcbiAgdG9rZW5faWQ6IG5hdDtcbiAgYW1vdW50OiBuYXQ7XG59XG5cbmV4cG9ydCBpbnRlcmZhY2UgRmEyVHJhbnNmZXIge1xuICBmcm9tXz86IGFkZHJlc3M7XG4gIHR4czogRmEyVHJhbnNmZXJEZXN0aW5hdGlvbltdO1xufVxuXG5leHBvcnQgaW50ZXJmYWNlIEJhbGFuY2VPZlJlcXVlc3Qge1xuICBvd25lcjogYWRkcmVzcztcbiAgdG9rZW5faWQ6IG5hdDtcbn1cblxuZXhwb3J0IGludGVyZmFjZSBCYWxhbmNlT2ZSZXNwb25zZSB7XG4gIGJhbGFuY2U6IG5hdDtcbiAgcmVxdWVzdDogQmFsYW5jZU9mUmVxdWVzdDtcbn1cblxuZXhwb3J0IGFzeW5jIGZ1bmN0aW9uIHRyYW5zZmVyKFxuICBmYTI6IGFkZHJlc3MsXG4gIG9wZXJhdG9yOiBUZXpvc1Rvb2xraXQsXG4gIHR4czogRmEyVHJhbnNmZXJbXVxuKTogUHJvbWlzZTx2b2lkPiB7XG4gICRsb2cuaW5mbygndHJhbnNmZXJyaW5nJyk7XG4gIGNvbnN0IG5mdFdpdGhPcGVyYXRvciA9IGF3YWl0IG9wZXJhdG9yLmNvbnRyYWN0LmF0KGZhMik7XG5cbiAgY29uc3Qgb3AgPSBhd2FpdCBuZnRXaXRoT3BlcmF0b3IubWV0aG9kcy50cmFuc2Zlcih0eHMpLnNlbmQoKTtcblxuICBjb25zdCBoYXNoID0gYXdhaXQgb3AuY29uZmlybWF0aW9uKDMpO1xuICAkbG9nLmluZm8oYGNvbnN1bWVkIGdhczogJHtvcC5jb25zdW1lZEdhc31gKTtcbn1cblxuZXhwb3J0IHR5cGUgT3BlcmF0b3JQYXJhbSA9IHtcbiAgb3duZXI6IGFkZHJlc3M7XG4gIG9wZXJhdG9yOiBhZGRyZXNzO1xuICB0b2tlbl9pZDogbmF0O1xufTtcbmV4cG9ydCB0eXBlIEFkZE9wZXJhdG9yID0geyBhZGRfb3BlcmF0b3I6IE9wZXJhdG9yUGFyYW0gfTtcbmV4cG9ydCB0eXBlIFJlbW92ZU9wZXJhdG9yID0geyByZW1vdmVfb3BlcmF0b3I6IE9wZXJhdG9yUGFyYW0gfTtcbmV4cG9ydCB0eXBlIFVwZGF0ZU9wZXJhdG9yID0gQWRkT3BlcmF0b3IgfCBSZW1vdmVPcGVyYXRvcjtcblxuZXhwb3J0IGNvbnN0IGlzQWRkT3BlcmF0b3IgPSAob3A6IFVwZGF0ZU9wZXJhdG9yKTogb3AgaXMgQWRkT3BlcmF0b3IgPT5cbiAgb3AuaGFzT3duUHJvcGVydHkoJ2FkZF9vcGVyYXRvcicpO1xuXG5leHBvcnQgY29uc3QgaXNSZW1vdmVPcGVyYXRvciA9IChvcDogVXBkYXRlT3BlcmF0b3IpOiBvcCBpcyBSZW1vdmVPcGVyYXRvciA9PlxuICBvcC5oYXNPd25Qcm9wZXJ0eSgncmVtb3ZlX29wZXJhdG9yJyk7XG5cbmV4cG9ydCBhc3luYyBmdW5jdGlvbiB1cGRhdGVPcGVyYXRvcnMoXG4gIGZhMjogYWRkcmVzcyxcbiAgb3duZXI6IFRlem9zVG9vbGtpdCxcbiAgb3BlcmF0b3JzOiBVcGRhdGVPcGVyYXRvcltdXG4pOiBQcm9taXNlPHZvaWQ+IHtcbiAgJGxvZy5pbmZvKCdhZGRpbmcgb3BlcmF0b3InKTtcbiAgY29uc3QgZmEyV2l0aE93bmVyID0gYXdhaXQgb3duZXIuY29udHJhY3QuYXQoZmEyKTtcbiAgY29uc3Qgb3duZXJBZGRyZXNzID0gYXdhaXQgb3duZXIuc2lnbmVyLnB1YmxpY0tleUhhc2goKTtcbiAgY29uc3Qgb3AgPSBhd2FpdCBmYTJXaXRoT3duZXIubWV0aG9kcy51cGRhdGVfb3BlcmF0b3JzKG9wZXJhdG9ycykuc2VuZCgpO1xuICBhd2FpdCBvcC5jb25maXJtYXRpb24oMyk7XG4gICRsb2cuaW5mbyhgY29uc3VtZWQgZ2FzOiAke29wLmNvbnN1bWVkR2FzfWApO1xufVxuIl19