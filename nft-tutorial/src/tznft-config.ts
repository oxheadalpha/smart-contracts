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
  .command('show-network')
  .description('shows currently selected active network')
  .action(conf.showActiveNetwork)

//prettier-ignore
cfg
  .command('set-network')
  .arguments('<network>')
  .description('selected network to originate contracts')
  .action(conf.setNetwork)

//prettier-ignore
cfg
  .command('show-all')
  .action(conf.showConfig);

cfg.parse();
