#!/usr/bin/env bun

import { up } from '../src/commands/up';
import { down } from '../src/commands/down';
import { status } from '../src/commands/status';
import { logs } from '../src/commands/logs';
import { open } from '../src/commands/open';

const USAGE = `
onlooker-dashboard — Grafana dashboards for Onlooker telemetry

Usage:
  onlooker-dashboard <command>

Commands:
  up       Start the API server and Grafana container
  down     Stop and remove both processes
  status   Show running state, ports, and data file sizes
  logs     Tail Grafana container logs (--follow for live)
  open     Open the Grafana dashboard in your browser

Environment:
  ONLOOKER_GRAFANA_PORT  Grafana port (default: 3456)
  ONLOOKER_API_PORT      API server port (default: 3457)
`.trim();

const command = process.argv[2];
const args = process.argv.slice(3);

switch (command) {
  case 'up':
    await up();
    break;
  case 'down':
    await down();
    break;
  case 'status':
    await status();
    break;
  case 'logs':
    await logs(args.includes('--follow') || args.includes('-f'));
    break;
  case 'open':
    await open();
    break;
  case '--help':
  case '-h':
  case undefined:
    console.log(USAGE);
    break;
  default:
    console.error(`Unknown command: ${command}\n`);
    console.log(USAGE);
    process.exit(1);
}
