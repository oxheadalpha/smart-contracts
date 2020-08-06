import { Command } from 'commander';

const cfg = new Command();

//prettier-ignore
cfg
  .command('config').alias('cfg')
  .arguments('<foo> [bar]')
  .parse();
