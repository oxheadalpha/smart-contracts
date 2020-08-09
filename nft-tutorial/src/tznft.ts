#!/usr/bin/env node
import { program } from 'commander';
import * as networkConf from './config-network';
import * as aliasConf from './config-aliases';
import * as bootstrap from './bootstrap';

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
  .action((options) => networkConf.showActiveNetwork(options.all)).passCommandToAction(false);

//prettier-ignore
program
  .command('set-network')
  .alias('setn')
  .arguments('<network>')
  .description('selected network to originate contracts')
  .action(networkConf.setNetwork);

//aliases

//prettier-ignore
program
    .command('show-alias')
    .alias('showa')
    .arguments('[alias]')
    .action(aliasConf.showAlias).passCommandToAction(false);

//prettier-ignore
program
  .command('add-alias')
  .alias('adda')
  .description('adds new alias to the configuration')
  .arguments('<alias> <key_or_address>')
  .action(aliasConf.addAlias).passCommandToAction(false);

//prettier-ignore
program
  .command('remove-alias')
  .alias('rma')
  .description('removes alias from the configuration')
  .arguments('<alias>')
  .action(aliasConf.removeAlias).passCommandToAction(false);

//prettier-ignore
program
  .command('config-show-all')
  .description('shows whole raw config')
  .action(networkConf.showConfig);

//working with network

//prettier-ignore
program
  .command('start')
  .alias('s')
  .description('starts and initializes network provider')
  .action(bootstrap.start)

program
  .command('kill')
  .alias('k')
  .description('kills running network provider')
  .action(bootstrap.kill);

program.parse();
