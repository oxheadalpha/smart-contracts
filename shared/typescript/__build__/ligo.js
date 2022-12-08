"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
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
    if (mod != null) for (var k in mod) if (k !== "default" && Object.prototype.hasOwnProperty.call(mod, k)) __createBinding(result, mod, k);
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
exports.token_meta_literal = exports.originateContract = exports.compileExpression = exports.compileAndLoadContract = exports.defaultLigoEnv = exports.LigoEnv = void 0;
var child = __importStar(require("child_process"));
var fs = __importStar(require("fs"));
var path = __importStar(require("path"));
var logger_1 = require("@tsed/logger");
var tzip16_1 = require("@taquito/tzip16");
var ligoVersion = '0.12.0';
var ligoCmd = "docker run --rm -v \"$PWD\":\"$PWD\" -w \"$PWD\" ligolang/ligo:".concat(ligoVersion, " \"$@\"");
var LigoEnv = /** @class */ (function () {
    function LigoEnv(cwd, srcDir, outDir) {
        this.cwd = cwd;
        this.srcDir = srcDir;
        this.outDir = outDir;
    }
    LigoEnv.prototype.srcFilePath = function (srcFileName) {
        return path.join(this.srcDir, srcFileName);
    };
    LigoEnv.prototype.outFilePath = function (outFileName) {
        return path.join(this.outDir, outFileName);
    };
    return LigoEnv;
}());
exports.LigoEnv = LigoEnv;
function defaultLigoEnv(cwd, ligoDir) {
    if (ligoDir === void 0) { ligoDir = 'ligo'; }
    var src = path.join(ligoDir, 'src');
    var out = path.join(ligoDir, 'out');
    return new LigoEnv(path.resolve(cwd), path.resolve(src), path.resolve(out));
}
exports.defaultLigoEnv = defaultLigoEnv;
function compileAndLoadContract(env, srcFile, main, dstFile) {
    return __awaiter(this, void 0, void 0, function () {
        var src, out;
        return __generator(this, function (_a) {
            switch (_a.label) {
                case 0:
                    src = env.srcFilePath(srcFile);
                    out = env.outFilePath(dstFile);
                    return [4 /*yield*/, compileContract(env.cwd, src, main, out)];
                case 1:
                    _a.sent();
                    return [2 /*return*/, new Promise(function (resolve, reject) {
                            return fs.readFile(out, function (err, buff) {
                                return err ? reject(err) : resolve(buff.toString());
                            });
                        })];
            }
        });
    });
}
exports.compileAndLoadContract = compileAndLoadContract;
function compileContract(cwd, srcFilePath, main, dstFilePath) {
    return __awaiter(this, void 0, void 0, function () {
        var cmd;
        return __generator(this, function (_a) {
            switch (_a.label) {
                case 0:
                    cmd = "".concat(ligoCmd, " compile-contract ").concat(srcFilePath, " ").concat(main, " --output=").concat(dstFilePath);
                    return [4 /*yield*/, runCmd(cwd, cmd)];
                case 1:
                    _a.sent();
                    return [2 /*return*/];
            }
        });
    });
}
function compileExpression(env, srcFile, expression) {
    return __awaiter(this, void 0, void 0, function () {
        var srcFilePath, cmd;
        return __generator(this, function (_a) {
            srcFilePath = env.srcFilePath(srcFile);
            cmd = "".concat(ligoCmd, " compile-expression --init-file=").concat(srcFilePath, " 'cameligo' '").concat(expression, "'");
            return [2 /*return*/, runCmd(env.cwd, cmd)];
        });
    });
}
exports.compileExpression = compileExpression;
function runCmd(cwd, cmd) {
    return __awaiter(this, void 0, void 0, function () {
        return __generator(this, function (_a) {
            return [2 /*return*/, new Promise(function (resolve, reject) {
                    return child.exec(cmd, { cwd: cwd }, function (err, stdout, errout) {
                        if (stdout && (errout || err)) {
                            logger_1.$log.info(stdout);
                        }
                        if (errout) {
                            logger_1.$log.error(errout);
                        }
                        if (err) {
                            reject(err);
                        }
                        else {
                            resolve(stdout);
                        }
                    });
                })];
        });
    });
}
function originateContract(tz, code, storage, name) {
    return __awaiter(this, void 0, void 0, function () {
        var originationOp, contract, error_1, jsonError;
        return __generator(this, function (_a) {
            switch (_a.label) {
                case 0:
                    _a.trys.push([0, 3, , 4]);
                    return [4 /*yield*/, tz.contract.originate({
                            code: code,
                            init: storage
                        })];
                case 1:
                    originationOp = _a.sent();
                    return [4 /*yield*/, originationOp.contract()];
                case 2:
                    contract = _a.sent();
                    logger_1.$log.info("originated contract ".concat(name, " with address ").concat(contract.address));
                    logger_1.$log.info("consumed gas: ".concat(originationOp.consumedGas));
                    return [2 /*return*/, Promise.resolve(contract)];
                case 3:
                    error_1 = _a.sent();
                    jsonError = JSON.stringify(error_1, null, 2);
                    logger_1.$log.fatal("".concat(name, " origination error ").concat(jsonError));
                    return [2 /*return*/, Promise.reject(error_1)];
                case 4: return [2 /*return*/];
            }
        });
    });
}
exports.originateContract = originateContract;
function token_meta_literal(symbol, name, decimals) {
    if (decimals === void 0) { decimals = 0; }
    return "{\n    Elt \"decimals\" 0x".concat((0, tzip16_1.char2Bytes)(decimals.toString()), ";\n    Elt \"name\" 0x").concat((0, tzip16_1.char2Bytes)(name), ";\n    Elt \"symbol\" 0x").concat((0, tzip16_1.char2Bytes)(symbol), ";\n  }");
}
exports.token_meta_literal = token_meta_literal;
//# sourceMappingURL=data:application/json;base64,eyJ2ZXJzaW9uIjozLCJmaWxlIjoibGlnby5qcyIsInNvdXJjZVJvb3QiOiIiLCJzb3VyY2VzIjpbIi4uL2xpZ28udHMiXSwibmFtZXMiOltdLCJtYXBwaW5ncyI6Ijs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7QUFBQSxtREFBdUM7QUFDdkMscUNBQXlCO0FBQ3pCLHlDQUE2QjtBQUM3Qix1Q0FBb0M7QUFHcEMsMENBQTZDO0FBRzdDLElBQU0sV0FBVyxHQUFHLFFBQVEsQ0FBQztBQUM3QixJQUFNLE9BQU8sR0FBRyx5RUFBNEQsV0FBVyxZQUFPLENBQUM7QUFFL0Y7SUFLRSxpQkFBWSxHQUFXLEVBQUUsTUFBYyxFQUFFLE1BQWM7UUFDckQsSUFBSSxDQUFDLEdBQUcsR0FBRyxHQUFHLENBQUM7UUFDZixJQUFJLENBQUMsTUFBTSxHQUFHLE1BQU0sQ0FBQztRQUNyQixJQUFJLENBQUMsTUFBTSxHQUFHLE1BQU0sQ0FBQztJQUN2QixDQUFDO0lBRUQsNkJBQVcsR0FBWCxVQUFZLFdBQW1CO1FBQzdCLE9BQU8sSUFBSSxDQUFDLElBQUksQ0FBQyxJQUFJLENBQUMsTUFBTSxFQUFFLFdBQVcsQ0FBQyxDQUFDO0lBQzdDLENBQUM7SUFFRCw2QkFBVyxHQUFYLFVBQVksV0FBbUI7UUFDN0IsT0FBTyxJQUFJLENBQUMsSUFBSSxDQUFDLElBQUksQ0FBQyxNQUFNLEVBQUUsV0FBVyxDQUFDLENBQUM7SUFDN0MsQ0FBQztJQUNILGNBQUM7QUFBRCxDQUFDLEFBbEJELElBa0JDO0FBbEJZLDBCQUFPO0FBb0JwQixTQUFnQixjQUFjLENBQUMsR0FBVyxFQUFFLE9BQXdCO0lBQXhCLHdCQUFBLEVBQUEsZ0JBQXdCO0lBQ2xFLElBQU0sR0FBRyxHQUFHLElBQUksQ0FBQyxJQUFJLENBQUMsT0FBTyxFQUFFLEtBQUssQ0FBQyxDQUFDO0lBQ3RDLElBQU0sR0FBRyxHQUFHLElBQUksQ0FBQyxJQUFJLENBQUMsT0FBTyxFQUFFLEtBQUssQ0FBQyxDQUFD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QUE7O29CQUhJLGFBQWEsR0FBRyxTQUdwQjtvQkFFZSxxQkFBTSxhQUFhLENBQUMsUUFBUSxFQUFFLEVBQUE7O29CQUF6QyxRQUFRLEdBQUcsU0FBOEI7b0JBQy9DLGFBQUksQ0FBQyxJQUFJLENBQUMsOEJBQXVCLElBQUksMkJBQWlCLFFBQVEsQ0FBQyxPQUFPLENBQUUsQ0FBQyxDQUFDO29CQUMxRSxhQUFJLENBQUMsSUFBSSxDQUFDLHdCQUFpQixhQUFhLENBQUMsV0FBVyxDQUFFLENBQUMsQ0FBQztvQkFDeEQsc0JBQU8sT0FBTyxDQUFDLE9BQU8sQ0FBQyxRQUFRLENBQUMsRUFBQzs7O29CQUUzQixTQUFTLEdBQUcsSUFBSSxDQUFDLFNBQVMsQ0FBQyxPQUFLLEVBQUUsSUFBSSxFQUFFLENBQUMsQ0FBQyxDQUFDO29CQUNqRCxhQUFJLENBQUMsS0FBSyxDQUFDLFVBQUcsSUFBSSxnQ0FBc0IsU0FBUyxDQUFFLENBQUMsQ0FBQztvQkFDckQsc0JBQU8sT0FBTyxDQUFDLE1BQU0sQ0FBQyxPQUFLLENBQUMsRUFBQzs7Ozs7Q0FFaEM7QUFyQkQsOENBcUJDO0FBRUQsU0FBZ0Isa0JBQWtCLENBQ2hDLE1BQWMsRUFDZCxJQUFZLEVBQ1osUUFBb0I7SUFBcEIseUJBQUEsRUFBQSxZQUFvQjtJQUVwQixPQUFPLG9DQUNjLElBQUEsbUJBQVUsRUFBQyxRQUFRLENBQUMsUUFBUSxFQUFFLENBQUMsbUNBQ25DLElBQUEsbUJBQVUsRUFBQyxJQUFJLENBQUMscUNBQ2QsSUFBQSxtQkFBVSxFQUFDLE1BQU0sQ0FBQyxXQUNuQyxDQUFDO0FBQ0wsQ0FBQztBQVZELGdEQVVDIiwic291cmNlc0NvbnRlbnQiOlsiaW1wb3J0ICogYXMgY2hpbGQgZnJvbSAnY2hpbGRfcHJvY2Vzcyc7XG5pbXBvcnQgKiBhcyBmcyBmcm9tICdmcyc7XG5pbXBvcnQgKiBhcyBwYXRoIGZyb20gJ3BhdGgnO1xuaW1wb3J0IHsgJGxvZyB9IGZyb20gJ0B0c2VkL2xvZ2dlcic7XG5cbmltcG9ydCB7IFRlem9zVG9vbGtpdCB9IGZyb20gJ0B0YXF1aXRvL3RhcXVpdG8nO1xuaW1wb3J0IHsgY2hhcjJCeXRlcyB9IGZyb20gJ0B0YXF1aXRvL3R6aXAxNic7XG5pbXBvcnQgeyBDb250cmFjdCB9IGZyb20gJy4vdHlwZS1hbGlhc2VzJztcblxuY29uc3QgbGlnb1ZlcnNpb24gPSAnMC4xMi4wJztcbmNvbnN0IGxpZ29DbWQgPSBgZG9ja2VyIHJ1biAtLXJtIC12IFwiJFBXRFwiOlwiJFBXRFwiIC13IFwiJFBXRFwiIGxpZ29sYW5nL2xpZ286JHtsaWdvVmVyc2lvbn0gXCIkQFwiYDtcblxuZXhwb3J0IGNsYXNzIExpZ29FbnYge1xuICByZWFkb25seSBjd2Q6IHN0cmluZztcbiAgcmVhZG9ubHkgc3JjRGlyOiBzdHJpbmc7XG4gIHJlYWRvbmx5IG91dERpcjogc3RyaW5nO1xuXG4gIGNvbnN0cnVjdG9yKGN3ZDogc3RyaW5nLCBzcmNEaXI6IHN0cmluZywgb3V0RGlyOiBzdHJpbmcpIHtcbiAgICB0aGlzLmN3ZCA9IGN3ZDtcbiAgICB0aGlzLnNyY0RpciA9IHNyY0RpcjtcbiAgICB0aGlzLm91dERpciA9IG91dERpcjtcbiAgfVxuXG4gIHNyY0ZpbGVQYXRoKHNyY0ZpbGVOYW1lOiBzdHJpbmcpOiBzdHJpbmcge1xuICAgIHJldHVybiBwYXRoLmpvaW4odGhpcy5zcmNEaXIsIHNyY0ZpbGVOYW1lKTtcbiAgfVxuXG4gIG91dEZpbGVQYXRoKG91dEZpbGVOYW1lOiBzdHJpbmcpOiBzdHJpbmcge1xuICAgIHJldHVybiBwYXRoLmpvaW4odGhpcy5vdXREaXIsIG91dEZpbGVOYW1lKTtcbiAgfVxufVxuXG5leHBvcnQgZnVuY3Rpb24gZGVmYXVsdExpZ29FbnYoY3dkOiBzdHJpbmcsIGxpZ29EaXI6IHN0cmluZyA9ICdsaWdvJyk6IExpZ29FbnYge1xuICBjb25zdCBzcmMgPSBwYXRoLmpvaW4obGlnb0RpciwgJ3NyYycpO1xuICBjb25zdCBvdXQgPSBwYXRoLmpvaW4obGlnb0RpciwgJ291dCcpO1xuICByZXR1cm4gbmV3IExpZ29FbnYocGF0aC5yZXNvbHZlKGN3ZCksIHBhdGgucmVzb2x2ZShzcmMpLCBwYXRoLnJlc29sdmUob3V0KSk7XG59XG5cbmV4cG9ydCBhc3luYyBmdW5jdGlvbiBjb21waWxlQW5kTG9hZENvbnRyYWN0KFxuICBlbnY6IExpZ29FbnYsXG4gIHNyY0ZpbGU6IHN0cmluZyxcbiAgbWFpbjogc3RyaW5nLFxuICBkc3RGaWxlOiBzdHJpbmdcbik6IFByb21pc2U8c3RyaW5nPiB7XG4gIGNvbnN0IHNyYyA9IGVudi5zcmNGaWxlUGF0aChzcmNGaWxlKTtcbiAgY29uc3Qgb3V0ID0gZW52Lm91dEZpbGVQYXRoKGRzdEZpbGUpO1xuICBhd2FpdCBjb21waWxlQ29udHJhY3QoZW52LmN3ZCwgc3JjLCBtYWluLCBvdXQpO1xuXG4gIHJldHVybiBuZXcgUHJvbWlzZTxzdHJpbmc+KChyZXNvbHZlLCByZWplY3QpID0+XG4gICAgZnMucmVhZEZpbGUob3V0LCAoZXJyLCBidWZmKSA9PlxuICAgICAgZXJyID8gcmVqZWN0KGVycikgOiByZXNvbHZlKGJ1ZmYudG9TdHJpbmcoKSlcbiAgICApXG4gICk7XG59XG5cbmFzeW5jIGZ1bmN0aW9uIGNvbXBpbGVDb250cmFjdChcbiAgY3dkOiBzdHJpbmcsXG4gIHNyY0ZpbGVQYXRoOiBzdHJpbmcsXG4gIG1haW46IHN0cmluZyxcbiAgZHN0RmlsZVBhdGg6IHN0cmluZ1xuKTogUHJvbWlzZTx2b2lkPiB7XG4gIGNvbnN0IGNtZCA9IGAke2xpZ29DbWR9IGNvbXBpbGUtY29udHJhY3QgJHtzcmNGaWxlUGF0aH0gJHttYWlufSAtLW91dHB1dD0ke2RzdEZpbGVQYXRofWA7XG4gIGF3YWl0IHJ1bkNtZChjd2QsIGNtZCk7XG59XG5cbmV4cG9ydCBhc3luYyBmdW5jdGlvbiBjb21waWxlRXhwcmVzc2lvbihcbiAgZW52OiBMaWdvRW52LFxuICBzcmNGaWxlOiBzdHJpbmcsXG4gIGV4cHJlc3Npb246IHN0cmluZ1xuKTogUHJvbWlzZTxzdHJpbmc+IHtcbiAgY29uc3Qgc3JjRmlsZVBhdGggPSBlbnYuc3JjRmlsZVBhdGgoc3JjRmlsZSk7XG4gIGNvbnN0IGNtZCA9IGAke2xpZ29DbWR9IGNvbXBpbGUtZXhwcmVzc2lvbiAtLWluaXQtZmlsZT0ke3NyY0ZpbGVQYXRofSAnY2FtZWxpZ28nICcke2V4cHJlc3Npb259J2A7XG4gIHJldHVybiBydW5DbWQoZW52LmN3ZCwgY21kKTtcbn1cblxuYXN5bmMgZnVuY3Rpb24gcnVuQ21kKGN3ZDogc3RyaW5nLCBjbWQ6IHN0cmluZyk6IFByb21pc2U8c3RyaW5nPiB7XG4gIHJldHVybiBuZXcgUHJvbWlzZTxzdHJpbmc+KChyZXNvbHZlLCByZWplY3QpID0+XG4gICAgY2hpbGQuZXhlYyhjbWQsIHsgY3dkIH0sIChlcnIsIHN0ZG91dCwgZXJyb3V0KSA9PiB7XG4gICAgICBpZiAoc3Rkb3V0ICYmIChlcnJvdXQgfHwgZXJyKSkge1xuICAgICAgICAkbG9nLmluZm8oc3Rkb3V0KTtcbiAgICAgIH1cbiAgICAgIGlmIChlcnJvdXQpIHtcbiAgICAgICAgJGxvZy5lcnJvcihlcnJvdXQpO1xuICAgICAgfVxuICAgICAgaWYgKGVycikge1xuICAgICAgICByZWplY3QoZXJyKTtcbiAgICAgIH0gZWxzZSB7XG4gICAgICAgIHJlc29sdmUoc3Rkb3V0KTtcbiAgICAgIH1cbiAgICB9KVxuICApO1xufVxuXG5leHBvcnQgYXN5bmMgZnVuY3Rpb24gb3JpZ2luYXRlQ29udHJhY3QoXG4gIHR6OiBUZXpvc1Rvb2xraXQsXG4gIGNvZGU6IHN0cmluZyxcbiAgc3RvcmFnZTogYW55LFxuICBuYW1lOiBzdHJpbmdcbik6IFByb21pc2U8Q29udHJhY3Q+IHtcbiAgdHJ5IHtcbiAgICBjb25zdCBvcmlnaW5hdGlvbk9wID0gYXdhaXQgdHouY29udHJhY3Qub3JpZ2luYXRlKHtcbiAgICAgIGNvZGUsXG4gICAgICBpbml0OiBzdG9yYWdlXG4gICAgfSk7XG5cbiAgICBjb25zdCBjb250cmFjdCA9IGF3YWl0IG9yaWdpbmF0aW9uT3AuY29udHJhY3QoKTtcbiAgICAkbG9nLmluZm8oYG9yaWdpbmF0ZWQgY29udHJhY3QgJHtuYW1lfSB3aXRoIGFkZHJlc3MgJHtjb250cmFjdC5hZGRyZXNzfWApO1xuICAgICRsb2cuaW5mbyhgY29uc3VtZWQgZ2FzOiAke29yaWdpbmF0aW9uT3AuY29uc3VtZWRHYXN9YCk7XG4gICAgcmV0dXJuIFByb21pc2UucmVzb2x2ZShjb250cmFjdCk7XG4gIH0gY2F0Y2ggKGVycm9yKSB7XG4gICAgY29uc3QganNvbkVycm9yID0gSlNPTi5zdHJpbmdpZnkoZXJyb3IsIG51bGwsIDIpO1xuICAgICRsb2cuZmF0YWwoYCR7bmFtZX0gb3JpZ2luYXRpb24gZXJyb3IgJHtqc29uRXJyb3J9YCk7XG4gICAgcmV0dXJuIFByb21pc2UucmVqZWN0KGVycm9yKTtcbiAgfVxufVxuXG5leHBvcnQgZnVuY3Rpb24gdG9rZW5fbWV0YV9saXRlcmFsKFxuICBzeW1ib2w6IHN0cmluZyxcbiAgbmFtZTogc3RyaW5nLFxuICBkZWNpbWFsczogbnVtYmVyID0gMFxuKTogc3RyaW5nIHtcbiAgcmV0dXJuIGB7XG4gICAgRWx0IFwiZGVjaW1hbHNcIiAweCR7Y2hhcjJCeXRlcyhkZWNpbWFscy50b1N0cmluZygpKX07XG4gICAgRWx0IFwibmFtZVwiIDB4JHtjaGFyMkJ5dGVzKG5hbWUpfTtcbiAgICBFbHQgXCJzeW1ib2xcIiAweCR7Y2hhcjJCeXRlcyhzeW1ib2wpfTtcbiAgfWA7XG59XG4iXX0=