#!/usr/bin/env node
"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const commander_1 = require("commander");
const cli = new commander_1.Command();
//prettier-ignore
cli
    .command('config', 'configure tznft').alias('cfg')
    .command('originate', 'originate something')
    .parse();
