#!/usr/bin/env node
import { program } from 'commander';
import * as networkConf from './config-network';

// configuration commands

//prettier-ignore
program
  .command('config-init')
  .alias('ci')
  .description('creates tznft.config file')
  .action(networkConf.initUserConfig);

//prettier-ignore
program
  .command('show-network')
  .alias('shown')
  .description(
    'shows currently selected active network', 
    {'a': 'also shows all available networks'}
  )
  .option('-a --all', 'shows all available configured networks', false)
  .action((options) => networkConf.showActiveNetwork(options.all))
  .passCommandToAction(false)

//prettier-ignore
program
  .command('set-network')
  .alias('setn')
  .arguments('<network>')
  .description('selected network to originate contracts')
  .action(networkConf.setNetwork)

//prettier-ignore
program
  .command('config-show-all')
  .description('shows whole raw config')
  .action(networkConf.showConfig);

program.parse();
