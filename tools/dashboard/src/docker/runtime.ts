import { $ } from 'bun';

let cachedRuntime: string | null = null;

export async function detectRuntime(): Promise<string> {
  if (cachedRuntime) return cachedRuntime;

  for (const candidate of ['docker', 'podman', 'nerdctl']) {
    try {
      await $`which ${candidate}`.quiet();
      cachedRuntime = candidate;
      return candidate;
    } catch {
      /* empty */
    }
  }

  throw new Error(
    'No container runtime found. Install one of: docker, podman, or nerdctl.',
  );
}
