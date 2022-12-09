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
var ligoVersion = '0.57.0';
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
                    cmd = "".concat(ligoCmd, " compile contract ").concat(srcFilePath, " -e ").concat(main, " -o ").concat(dstFilePath);
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
            cmd = "".concat(ligoCmd, " compile expression --init-file ").concat(srcFilePath, " 'cameligo' '").concat(expression, "'");
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
                            logger_1.$log.error("failed ligo command ".concat(cmd));
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
//# sourceMappingURL=data:application/json;base64,eyJ2ZXJzaW9uIjozLCJmaWxlIjoibGlnby5qcyIsInNvdXJjZVJvb3QiOiIiLCJzb3VyY2VzIjpbIi4uL2xpZ28udHMiXSwibmFtZXMiOltdLCJtYXBwaW5ncyI6Ijs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7QUFBQSxtREFBdUM7QUFDdkMscUNBQXlCO0FBQ3pCLHlDQUE2QjtBQUM3Qix1Q0FBb0M7QUFHcEMsMENBQTZDO0FBRzdDLElBQU0sV0FBVyxHQUFHLFFBQVEsQ0FBQztBQUM3QixJQUFNLE9BQU8sR0FBRyx5RUFBNEQsV0FBVyxZQUFPLENBQUM7QUFFL0Y7SUFLRSxpQkFBWSxHQUFXLEVBQUUsTUFBYyxFQUFFLE1BQWM7UUFDckQsSUFBSSxDQUFDLEdBQUcsR0FBRyxHQUFHLENBQUM7UUFDZixJQUFJLENBQUMsTUFBTSxHQUFHLE1BQU0sQ0FBQztRQUNyQixJQUFJLENBQUMsTUFBTSxHQUFHLE1BQU0sQ0FBQztJQUN2QixDQUFDO0lBRUQsNkJBQVcsR0FBWCxVQUFZLFdBQW1CO1FBQzdCLE9BQU8sSUFBSSxDQUFDLElBQUksQ0FBQyxJQUFJLENBQUMsTUFBTSxFQUFFLFdBQVcsQ0FBQyxDQUFDO0lBQzdDLENBQUM7SUFFRCw2QkFBVyxHQUFYLFVBQVksV0FBbUI7UUFDN0IsT0FBTyxJQUFJLENBQUMsSUFBSSxDQUFDLElBQUksQ0FBQyxNQUFNLEVBQUUsV0FBVyxDQUFDLENBQUM7SUFDN0MsQ0FBQztJQUNILGNBQUM7QUFBRCxDQUFDLEFBbEJELElBa0JDO0FBbEJZLDBCQUFPO0FBb0JwQixTQUFnQixjQUFjLENBQUMsR0FBVyxFQUFFLE9BQXdCO0lBQXhCLHdCQUFBLEVBQUEsZ0JBQXdCO0lBQ2xFLElBQU0sR0FBRyxHQUFHLElBQUksQ0FBQyxJQUFJLENBQUMsT0FBTyxFQUFFLEtBQUssQ0FBQyxDQUFDO0lBQ3RDLElBQU0sR0FBRyxHQUFHLElBQUksQ0FBQyxJQUFJLENBQUMsT0FBTyxFQUFFLEtBQUssQ0FBQyxDQUFD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QUFDOzRCQUNoRCxJQUFJLE1BQUE7NEJBQ0osSUFBSSxFQUFFLE9BQU87eUJBQ2QsQ0FBQyxFQUFBOztvQkFISSxhQUFhLEdBQUcsU0FHcEI7b0JBRWUscUJBQU0sYUFBYSxDQUFDLFFBQVEsRUFBRSxFQUFBOztvQkFBekMsUUFBUSxHQUFHLFNBQThCO29CQUMvQyxhQUFJLENBQUMsSUFBSSxDQUFDLDhCQUF1QixJQUFJLDJCQUFpQixRQUFRLENBQUMsT0FBTyxDQUFFLENBQUMsQ0FBQztvQkFDMUUsYUFBSSxDQUFDLElBQUksQ0FBQyx3QkFBaUIsYUFBYSxDQUFDLFdBQVcsQ0FBRSxDQUFDLENBQUM7b0JBQ3hELHNCQUFPLE9BQU8sQ0FBQyxPQUFPLENBQUMsUUFBUSxDQUFDLEVBQUM7OztvQkFFM0IsU0FBUyxHQUFHLElBQUksQ0FBQyxTQUFTLENBQUMsT0FBSyxFQUFFLElBQUksRUFBRSxDQUFDLENBQUMsQ0FBQztvQkFDakQsYUFBSSxDQUFDLEtBQUssQ0FBQyxVQUFHLElBQUksZ0NBQXNCLFNBQVMsQ0FBRSxDQUFDLENBQUM7b0JBQ3JELHNCQUFPLE9BQU8sQ0FBQyxNQUFNLENBQUMsT0FBSyxDQUFDLEVBQUM7Ozs7O0NBRWhDO0FBckJELDhDQXFCQztBQUVELFNBQWdCLGtCQUFrQixDQUNoQyxNQUFjLEVBQ2QsSUFBWSxFQUNaLFFBQW9CO0lBQXBCLHlCQUFBLEVBQUEsWUFBb0I7SUFFcEIsT0FBTyxvQ0FDYyxJQUFBLG1CQUFVLEVBQUMsUUFBUSxDQUFDLFFBQVEsRUFBRSxDQUFDLG1DQUNuQyxJQUFBLG1CQUFVLEVBQUMsSUFBSSxDQUFDLHFDQUNkLElBQUEsbUJBQVUsRUFBQyxNQUFNLENBQUMsV0FDbkMsQ0FBQztBQUNMLENBQUM7QUFWRCxnREFVQyIsInNvdXJjZXNDb250ZW50IjpbImltcG9ydCAqIGFzIGNoaWxkIGZyb20gJ2NoaWxkX3Byb2Nlc3MnO1xuaW1wb3J0ICogYXMgZnMgZnJvbSAnZnMnO1xuaW1wb3J0ICogYXMgcGF0aCBmcm9tICdwYXRoJztcbmltcG9ydCB7ICRsb2cgfSBmcm9tICdAdHNlZC9sb2dnZXInO1xuXG5pbXBvcnQgeyBUZXpvc1Rvb2xraXQgfSBmcm9tICdAdGFxdWl0by90YXF1aXRvJztcbmltcG9ydCB7IGNoYXIyQnl0ZXMgfSBmcm9tICdAdGFxdWl0by90emlwMTYnO1xuaW1wb3J0IHsgQ29udHJhY3QgfSBmcm9tICcuL3R5cGUtYWxpYXNlcyc7XG5cbmNvbnN0IGxpZ29WZXJzaW9uID0gJzAuNTcuMCc7XG5jb25zdCBsaWdvQ21kID0gYGRvY2tlciBydW4gLS1ybSAtdiBcIiRQV0RcIjpcIiRQV0RcIiAtdyBcIiRQV0RcIiBsaWdvbGFuZy9saWdvOiR7bGlnb1ZlcnNpb259IFwiJEBcImA7XG5cbmV4cG9ydCBjbGFzcyBMaWdvRW52IHtcbiAgcmVhZG9ubHkgY3dkOiBzdHJpbmc7XG4gIHJlYWRvbmx5IHNyY0Rpcjogc3RyaW5nO1xuICByZWFkb25seSBvdXREaXI6IHN0cmluZztcblxuICBjb25zdHJ1Y3Rvcihjd2Q6IHN0cmluZywgc3JjRGlyOiBzdHJpbmcsIG91dERpcjogc3RyaW5nKSB7XG4gICAgdGhpcy5jd2QgPSBjd2Q7XG4gICAgdGhpcy5zcmNEaXIgPSBzcmNEaXI7XG4gICAgdGhpcy5vdXREaXIgPSBvdXREaXI7XG4gIH1cblxuICBzcmNGaWxlUGF0aChzcmNGaWxlTmFtZTogc3RyaW5nKTogc3RyaW5nIHtcbiAgICByZXR1cm4gcGF0aC5qb2luKHRoaXMuc3JjRGlyLCBzcmNGaWxlTmFtZSk7XG4gIH1cblxuICBvdXRGaWxlUGF0aChvdXRGaWxlTmFtZTogc3RyaW5nKTogc3RyaW5nIHtcbiAgICByZXR1cm4gcGF0aC5qb2luKHRoaXMub3V0RGlyLCBvdXRGaWxlTmFtZSk7XG4gIH1cbn1cblxuZXhwb3J0IGZ1bmN0aW9uIGRlZmF1bHRMaWdvRW52KGN3ZDogc3RyaW5nLCBsaWdvRGlyOiBzdHJpbmcgPSAnbGlnbycpOiBMaWdvRW52IHtcbiAgY29uc3Qgc3JjID0gcGF0aC5qb2luKGxpZ29EaXIsICdzcmMnKTtcbiAgY29uc3Qgb3V0ID0gcGF0aC5qb2luKGxpZ29EaXIsICdvdXQnKTtcbiAgcmV0dXJuIG5ldyBMaWdvRW52KHBhdGgucmVzb2x2ZShjd2QpLCBwYXRoLnJlc29sdmUoc3JjKSwgcGF0aC5yZXNvbHZlKG91dCkpO1xufVxuXG5leHBvcnQgYXN5bmMgZnVuY3Rpb24gY29tcGlsZUFuZExvYWRDb250cmFjdChcbiAgZW52OiBMaWdvRW52LFxuICBzcmNGaWxlOiBzdHJpbmcsXG4gIG1haW46IHN0cmluZyxcbiAgZHN0RmlsZTogc3RyaW5nXG4pOiBQcm9taXNlPHN0cmluZz4ge1xuICBjb25zdCBzcmMgPSBlbnYuc3JjRmlsZVBhdGgoc3JjRmlsZSk7XG4gIGNvbnN0IG91dCA9IGVudi5vdXRGaWxlUGF0aChkc3RGaWxlKTtcbiAgYXdhaXQgY29tcGlsZUNvbnRyYWN0KGVudi5jd2QsIHNyYywgbWFpbiwgb3V0KTtcblxuICByZXR1cm4gbmV3IFByb21pc2U8c3RyaW5nPigocmVzb2x2ZSwgcmVqZWN0KSA9PlxuICAgIGZzLnJlYWRGaWxlKG91dCwgKGVyciwgYnVmZikgPT5cbiAgICAgIGVyciA/IHJlamVjdChlcnIpIDogcmVzb2x2ZShidWZmLnRvU3RyaW5nKCkpXG4gICAgKVxuICApO1xufVxuXG5hc3luYyBmdW5jdGlvbiBjb21waWxlQ29udHJhY3QoXG4gIGN3ZDogc3RyaW5nLFxuICBzcmNGaWxlUGF0aDogc3RyaW5nLFxuICBtYWluOiBzdHJpbmcsXG4gIGRzdEZpbGVQYXRoOiBzdHJpbmdcbik6IFByb21pc2U8dm9pZD4ge1xuICBjb25zdCBjbWQgPSBgJHtsaWdvQ21kfSBjb21waWxlIGNvbnRyYWN0ICR7c3JjRmlsZVBhdGh9IC1lICR7bWFpbn0gLW8gJHtkc3RGaWxlUGF0aH1gO1xuICBhd2FpdCBydW5DbWQoY3dkLCBjbWQpO1xufVxuXG5leHBvcnQgYXN5bmMgZnVuY3Rpb24gY29tcGlsZUV4cHJlc3Npb24oXG4gIGVudjogTGlnb0VudixcbiAgc3JjRmlsZTogc3RyaW5nLFxuICBleHByZXNzaW9uOiBzdHJpbmdcbik6IFByb21pc2U8c3RyaW5nPiB7XG4gIGNvbnN0IHNyY0ZpbGVQYXRoID0gZW52LnNyY0ZpbGVQYXRoKHNyY0ZpbGUpO1xuICBjb25zdCBjbWQgPSBgJHtsaWdvQ21kfSBjb21waWxlIGV4cHJlc3Npb24gLS1pbml0LWZpbGUgJHtzcmNGaWxlUGF0aH0gJ2NhbWVsaWdvJyAnJHtleHByZXNzaW9ufSdgO1xuICByZXR1cm4gcnVuQ21kKGVudi5jd2QsIGNtZCk7XG59XG5cbmFzeW5jIGZ1bmN0aW9uIHJ1bkNtZChjd2Q6IHN0cmluZywgY21kOiBzdHJpbmcpOiBQcm9taXNlPHN0cmluZz4ge1xuICByZXR1cm4gbmV3IFByb21pc2U8c3RyaW5nPigocmVzb2x2ZSwgcmVqZWN0KSA9PlxuICAgIGNoaWxkLmV4ZWMoY21kLCB7IGN3ZCB9LCAoZXJyLCBzdGRvdXQsIGVycm91dCkgPT4ge1xuICAgICAgaWYgKHN0ZG91dCAmJiAoZXJyb3V0IHx8IGVycikpIHtcbiAgICAgICAgJGxvZy5pbmZvKHN0ZG91dCk7XG4gICAgICB9XG4gICAgICBpZiAoZXJyb3V0KSB7XG4gICAgICAgICRsb2cuZXJyb3IoZXJyb3V0KTtcbiAgICAgICAgJGxvZy5lcnJvcihgZmFpbGVkIGxpZ28gY29tbWFuZCAke2NtZH1gKVxuICAgICAgfVxuICAgICAgaWYgKGVycikge1xuICAgICAgICByZWplY3QoZXJyKTtcbiAgICAgIH0gZWxzZSB7XG4gICAgICAgIHJlc29sdmUoc3Rkb3V0KTtcbiAgICAgIH1cbiAgICB9KVxuICApO1xufVxuXG5leHBvcnQgYXN5bmMgZnVuY3Rpb24gb3JpZ2luYXRlQ29udHJhY3QoXG4gIHR6OiBUZXpvc1Rvb2xraXQsXG4gIGNvZGU6IHN0cmluZyxcbiAgc3RvcmFnZTogYW55LFxuICBuYW1lOiBzdHJpbmdcbik6IFByb21pc2U8Q29udHJhY3Q+IHtcbiAgdHJ5IHtcbiAgICBjb25zdCBvcmlnaW5hdGlvbk9wID0gYXdhaXQgdHouY29udHJhY3Qub3JpZ2luYXRlKHtcbiAgICAgIGNvZGUsXG4gICAgICBpbml0OiBzdG9yYWdlXG4gICAgfSk7XG5cbiAgICBjb25zdCBjb250cmFjdCA9IGF3YWl0IG9yaWdpbmF0aW9uT3AuY29udHJhY3QoKTtcbiAgICAkbG9nLmluZm8oYG9yaWdpbmF0ZWQgY29udHJhY3QgJHtuYW1lfSB3aXRoIGFkZHJlc3MgJHtjb250cmFjdC5hZGRyZXNzfWApO1xuICAgICRsb2cuaW5mbyhgY29uc3VtZWQgZ2FzOiAke29yaWdpbmF0aW9uT3AuY29uc3VtZWRHYXN9YCk7XG4gICAgcmV0dXJuIFByb21pc2UucmVzb2x2ZShjb250cmFjdCk7XG4gIH0gY2F0Y2ggKGVycm9yKSB7XG4gICAgY29uc3QganNvbkVycm9yID0gSlNPTi5zdHJpbmdpZnkoZXJyb3IsIG51bGwsIDIpO1xuICAgICRsb2cuZmF0YWwoYCR7bmFtZX0gb3JpZ2luYXRpb24gZXJyb3IgJHtqc29uRXJyb3J9YCk7XG4gICAgcmV0dXJuIFByb21pc2UucmVqZWN0KGVycm9yKTtcbiAgfVxufVxuXG5leHBvcnQgZnVuY3Rpb24gdG9rZW5fbWV0YV9saXRlcmFsKFxuICBzeW1ib2w6IHN0cmluZyxcbiAgbmFtZTogc3RyaW5nLFxuICBkZWNpbWFsczogbnVtYmVyID0gMFxuKTogc3RyaW5nIHtcbiAgcmV0dXJuIGB7XG4gICAgRWx0IFwiZGVjaW1hbHNcIiAweCR7Y2hhcjJCeXRlcyhkZWNpbWFscy50b1N0cmluZygpKX07XG4gICAgRWx0IFwibmFtZVwiIDB4JHtjaGFyMkJ5dGVzKG5hbWUpfTtcbiAgICBFbHQgXCJzeW1ib2xcIiAweCR7Y2hhcjJCeXRlcyhzeW1ib2wpfTtcbiAgfWA7XG59XG4iXX0=