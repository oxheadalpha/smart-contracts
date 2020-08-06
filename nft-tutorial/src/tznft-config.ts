import { Command } from 'commander';
import * as conf from './config';

const cli = new Command();

const cfg = cli.command('config');

//prettier-ignore
cfg
  .command('init')
  .description('creates tznft.config file')
  .action(conf.initUserConfig);

//prettier-ignore
cfg
  .command('show-all')
  .action(conf.showConfig);

cfg.parse();
