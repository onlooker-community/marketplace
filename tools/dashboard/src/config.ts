import { homedir } from "node:os";
import { join } from "node:path";

export const CONTAINER_NAME = "onlooker-grafana";
export const GRAFANA_PORT = Number(process.env.ONLOOKER_GRAFANA_PORT ?? 3456);
export const API_PORT = Number(process.env.ONLOOKER_API_PORT ?? 3457);
export const GRAFANA_IMAGE = "grafana/grafana-oss:latest";

const home = homedir();
export const EVENTS_LOG = join(home, ".claude/logs/onlooker-events.jsonl");
export const COSTS_LOG = join(home, ".claude/onlooker/metrics/costs.jsonl");
export const HOOK_HEALTH_LOG_DIR = join(home, ".claude");
export const PID_FILE = join(home, ".claude/onlooker/dashboard.pid");
export const GRAFANA_URL = `http://localhost:${GRAFANA_PORT}`;

// Resolve provisioning directory relative to this package
const srcDir = new URL(".", import.meta.url).pathname;
export const PROVISIONING_DIR = join(srcDir, "provisioning");
