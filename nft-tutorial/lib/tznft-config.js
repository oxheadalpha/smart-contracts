"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
var commander_1 = require("commander");
var cfg = new commander_1.Command();
//prettier-ignore
cfg
    .command('config').alias('cfg')
    .arguments('<foo> [bar]')
    .parse();
