import { isRunning } from '../docker/container';
import { CONTAINER_NAME, GRAFANA_URL } from '../config';

export async function open(): Promise<void> {
  if (!(await isRunning(CONTAINER_NAME))) {
    console.error(
      'Dashboard is not running. Start it with `onlooker-dashboard up`.',
    );
    process.exit(1);
  }

  const platform = process.platform;
  const cmd =
    platform === 'darwin'
      ? 'open'
      : platform === 'win32'
        ? 'start'
        : 'xdg-open';

  Bun.spawnSync([cmd, GRAFANA_URL]);
  console.log(`Opened ${GRAFANA_URL}`);
}
