#!/usr/bin/env node
"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
var commander_1 = require("commander");
var cli = new commander_1.Command();
//prettier-ignore
cli
    .command('config', 'configure something')
    .command('originate', 'originate something')
    .parse();
