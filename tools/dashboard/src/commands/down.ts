import { existsSync, readFileSync, unlinkSync } from 'node:fs';
import { isRunning, stop } from '../docker/container';
import { CONTAINER_NAME, PID_FILE } from '../config';

export async function down(): Promise<void> {
  let stopped = false;

  // Stop Grafana container
  if (await isRunning(CONTAINER_NAME)) {
    console.log('Stopping Grafana container...');
    await stop(CONTAINER_NAME);
    stopped = true;
  } else {
    // Try to clean up a stopped container
    await stop(CONTAINER_NAME);
  }

  // Kill API server process if PID file exists
  if (existsSync(PID_FILE)) {
    const pid = Number(readFileSync(PID_FILE, 'utf-8').trim());
    if (pid > 0) {
      try {
        process.kill(pid, 'SIGTERM');
        console.log('Stopped API server.');
        stopped = true;
      } catch {
        // Process already dead
      }
    }
    unlinkSync(PID_FILE);
  }

  if (stopped) {
    console.log('Dashboard stopped.');
  } else {
    console.log('Dashboard is not running.');
  }
}
