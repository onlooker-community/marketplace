import { isRunning, streamLogs } from '../docker/container';
import { CONTAINER_NAME } from '../config';

export async function logs(follow: boolean): Promise<void> {
  if (!(await isRunning(CONTAINER_NAME))) {
    console.error(
      'Grafana container is not running. Start it with `onlooker-dashboard up`.',
    );
    process.exit(1);
  }

  await streamLogs(CONTAINER_NAME, follow);
}
