import { mkdirSync, writeFileSync } from 'node:fs';
import { dirname } from 'node:path';
import { detectRuntime } from '../docker/runtime';
import { isRunning, start } from '../docker/container';
import { startApiServer } from '../server/api';
import {
  CONTAINER_NAME,
  GRAFANA_PORT,
  API_PORT,
  GRAFANA_IMAGE,
  GRAFANA_URL,
  PROVISIONING_DIR,
  PID_FILE,
} from '../config';

export async function up(): Promise<void> {
  // Check if already running
  if (await isRunning(CONTAINER_NAME)) {
    console.log(`Dashboard is already running at ${GRAFANA_URL}`);
    return;
  }

  // Detect container runtime
  const runtime = await detectRuntime();
  console.log(`Using container runtime: ${runtime}`);

  // Start the API server in this process (background)
  console.log(`Starting API server on port ${API_PORT}...`);
  const server = startApiServer();

  // Write PID for the down command
  mkdirSync(dirname(PID_FILE), { recursive: true });
  writeFileSync(PID_FILE, String(process.pid));

  // Start Grafana container
  console.log('Starting Grafana container...');
  try {
    await start({
      name: CONTAINER_NAME,
      image: GRAFANA_IMAGE,
      ports: { [GRAFANA_PORT]: 3000 },
      env: {
        GF_INSTALL_PLUGINS: 'marcusolsson-json-datasource',
        GF_AUTH_ANONYMOUS_ENABLED: 'true',
        GF_AUTH_ANONYMOUS_ORG_ROLE: 'Admin',
        GF_SECURITY_ALLOW_EMBEDDING: 'true',
        GF_LOG_LEVEL: 'warn',
      },
      volumes: {
        [`${PROVISIONING_DIR}/datasources`]:
          '/etc/grafana/provisioning/datasources',
        [`${PROVISIONING_DIR}/dashboards`]:
          '/etc/grafana/provisioning/dashboards',
      },
      extraArgs: ['--add-host=host.docker.internal:host-gateway'],
    });
  } catch (err) {
    server.stop();
    throw err;
  }

  console.log(`
Dashboard is running:
  Grafana:    ${GRAFANA_URL}
  API server: http://localhost:${API_PORT}

Run \`onlooker-dashboard open\` to open in your browser.
Run \`onlooker-dashboard down\` to stop.
`);

  // Keep the process alive for the API server
  process.on('SIGINT', async () => {
    console.log('\nShutting down...');
    server.stop();
    const { stop } = await import('../docker/container');
    await stop(CONTAINER_NAME);
    process.exit(0);
  });

  process.on('SIGTERM', async () => {
    server.stop();
    const { stop } = await import('../docker/container');
    await stop(CONTAINER_NAME);
    process.exit(0);
  });

  // Block forever — the API server runs in this process
  await new Promise(() => {
    /* empty */
  });
}
