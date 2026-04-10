import { detectRuntime } from "./runtime";

export interface ContainerRunOpts {
	name: string;
	image: string;
	ports: Record<number, number>;
	env: Record<string, string>;
	volumes: Record<string, string>;
	extraArgs?: string[];
}

export async function isRunning(name: string): Promise<boolean> {
	const runtime = await detectRuntime();
	try {
		const proc = Bun.spawnSync([
			runtime,
			"inspect",
			"--format",
			"{{.State.Running}}",
			name,
		]);
		return proc.stdout.toString().trim() === "true";
	} catch {
		return false;
	}
}

export async function containerExists(name: string): Promise<boolean> {
	const runtime = await detectRuntime();
	try {
		const proc = Bun.spawnSync([runtime, "inspect", name]);
		return proc.exitCode === 0;
	} catch {
		return false;
	}
}

export async function start(opts: ContainerRunOpts): Promise<void> {
	const runtime = await detectRuntime();

	// Remove existing stopped container if present
	if (await containerExists(opts.name)) {
		Bun.spawnSync([runtime, "rm", "-f", opts.name]);
	}

	const args: string[] = ["run", "-d", "--name", opts.name];

	for (const [host, container] of Object.entries(opts.ports)) {
		args.push("-p", `${host}:${container}`);
	}

	for (const [key, value] of Object.entries(opts.env)) {
		args.push("-e", `${key}=${value}`);
	}

	for (const [host, container] of Object.entries(opts.volumes)) {
		args.push("-v", `${host}:${container}:ro`);
	}

	if (opts.extraArgs) {
		args.push(...opts.extraArgs);
	}

	args.push(opts.image);

	const proc = Bun.spawnSync([runtime, ...args]);
	if (proc.exitCode !== 0) {
		throw new Error(
			`Failed to start container: ${proc.stderr.toString().trim()}`,
		);
	}
}

export async function stop(name: string): Promise<void> {
	const runtime = await detectRuntime();
	try {
		Bun.spawnSync([runtime, "stop", name]);
	} catch {
		// Container may already be stopped
	}
	try {
		Bun.spawnSync([runtime, "rm", name]);
	} catch {
		// Container may already be removed
	}
}

export async function streamLogs(name: string, follow: boolean): Promise<void> {
	const runtime = await detectRuntime();
	if (follow) {
		const proc = Bun.spawn([runtime, "logs", "-f", name], {
			stdout: "inherit",
			stderr: "inherit",
		});
		await proc.exited;
	} else {
		const proc = Bun.spawnSync([runtime, "logs", "--tail", "100", name]);
		console.log(proc.stdout.toString());
	}
}
