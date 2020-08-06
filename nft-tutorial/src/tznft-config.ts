import { Command } from 'commander';
import * as networkConf from './config-network';

const cli = new Command();

const cfg = cli.command('config');

//prettier-ignore
cfg
  .command('init')
  .description('creates tznft.config file')
  .action(networkConf.initUserConfig);

//prettier-ignore
cfg
  .command('show-network')
  .description('shows currently selected active network')
  .action(networkConf.showActiveNetwork)

//prettier-ignore
cfg
  .command('set-network')
  .arguments('<network>')
  .description('selected network to originate contracts')
  .action(networkConf.setNetwork)

//prettier-ignore
cfg
  .command('show-all')
  .action(networkConf.showConfig);

cfg.parse();
