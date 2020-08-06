#!/usr/bin/env node
import { Command } from 'commander';

const cli = new Command();

//prettier-ignore
cli
  .command('config', 'configure tznft').alias('cfg')
  .command('originate', 'originate something')
  .parse();
