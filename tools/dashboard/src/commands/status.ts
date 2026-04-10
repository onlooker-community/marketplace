import { existsSync, readFileSync, statSync } from "node:fs";
import { isRunning } from "../docker/container";
import {
	CONTAINER_NAME,
	GRAFANA_PORT,
	API_PORT,
	GRAFANA_URL,
	EVENTS_LOG,
	COSTS_LOG,
	PID_FILE,
} from "../config";

function fileSize(path: string): string {
	if (!existsSync(path)) return "not found";
	const bytes = statSync(path).size;
	if (bytes < 1024) return `${bytes} B`;
	if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
	return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
}

function lineCount(path: string): number {
	if (!existsSync(path)) return 0;
	const content = readFileSync(path, "utf-8");
	return content.split("\n").filter((l) => l.trim().length > 0).length;
}

export async function status(): Promise<void> {
	const grafanaUp = await isRunning(CONTAINER_NAME);

	let apiUp = false;
	if (existsSync(PID_FILE)) {
		const pid = Number(readFileSync(PID_FILE, "utf-8").trim());
		if (pid > 0) {
			try {
				process.kill(pid, 0);
				apiUp = true;
			} catch {
				apiUp = false;
			}
		}
	}

	console.log("Onlooker Dashboard Status");
	console.log("=".repeat(40));
	console.log(
		`  Grafana:      ${grafanaUp ? `running on port ${GRAFANA_PORT}` : "stopped"}`,
	);
	console.log(
		`  API server:   ${apiUp ? `running on port ${API_PORT}` : "stopped"}`,
	);
	if (grafanaUp) {
		console.log(`  URL:          ${GRAFANA_URL}`);
	}
	console.log();
	console.log("Data Files");
	console.log("-".repeat(40));
	console.log(
		`  Events log:   ${fileSize(EVENTS_LOG)} (${lineCount(EVENTS_LOG)} entries)`,
	);
	console.log(
		`  Costs log:    ${fileSize(COSTS_LOG)} (${lineCount(COSTS_LOG)} entries)`,
	);

	if (!grafanaUp && !apiUp) {
		console.log("\nRun `onlooker-dashboard up` to start the dashboard.");
	}
}
