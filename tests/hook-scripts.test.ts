import { describe, expect, test } from 'bun:test';
import { readdir, stat } from 'node:fs/promises';
import { join, resolve } from 'node:path';

const ROOT = resolve(import.meta.dirname, '..');
const PLUGINS_DIR = join(ROOT, 'plugins');

/** Collect all .sh files under a directory recursively. */
async function collectShellScripts(dir: string): Promise<string[]> {
  const results: string[] = [];

  async function walk(d: string) {
    let entries: string[];
    try {
      entries = await readdir(d);
    } catch {
      return;
    }
    for (const entry of entries) {
      const full = join(d, entry);
      const s = await stat(full);
      if (s.isDirectory()) {
        await walk(full);
      } else if (entry.endsWith('.sh')) {
        results.push(full);
      }
    }
  }

  await walk(dir);
  return results;
}

/** Read and parse a JSON file. */
async function readJson(path: string): Promise<unknown> {
  try {
    return await Bun.file(path).json();
  } catch {
    return null;
  }
}

// ---------------------------------------------------------------------------
// Collect all shell scripts across all plugins
// ---------------------------------------------------------------------------

const pluginDirs = await readdir(PLUGINS_DIR);
const allScripts: string[] = [];

for (const name of pluginDirs) {
  const scripts = await collectShellScripts(join(PLUGINS_DIR, name));
  allScripts.push(...scripts);
}

// ---------------------------------------------------------------------------
// 1. Shell script syntax validation (bash -n)
// ---------------------------------------------------------------------------

describe('shell script syntax', () => {
  for (const script of allScripts) {
    const rel = script.replace(`${ROOT}/`, '');

    test(`${rel} has valid bash syntax`, async () => {
      const proc = Bun.spawn(['bash', '-n', script], {
        stdout: 'pipe',
        stderr: 'pipe',
      });
      const exitCode = await proc.exited;
      if (exitCode !== 0) {
        const stderr = await new Response(proc.stderr).text();
        expect(exitCode).toBe(0); // will fail with message context
        console.error(`  syntax error: ${stderr.trim()}`);
      }
      expect(exitCode).toBe(0);
    });
  }
});

// ---------------------------------------------------------------------------
// 2. Shell scripts are executable
// ---------------------------------------------------------------------------

describe('shell script permissions', () => {
  for (const script of allScripts) {
    const rel = script.replace(`${ROOT}/`, '');

    test(`${rel} is executable`, async () => {
      const s = await stat(script);
      // Check owner execute bit (0o100)
      const isExecutable = (s.mode & 0o111) !== 0;
      expect(isExecutable).toBe(true);
    });
  }
});

// ---------------------------------------------------------------------------
// 3. Shell scripts have a shebang
// ---------------------------------------------------------------------------

describe('shell script shebang', () => {
  for (const script of allScripts) {
    const rel = script.replace(`${ROOT}/`, '');

    test(`${rel} starts with a shebang`, async () => {
      const content = await Bun.file(script).text();
      expect(content.startsWith('#!')).toBe(true);
    });
  }
});

// ---------------------------------------------------------------------------
// 4. hooks.json command scripts exist on disk
// ---------------------------------------------------------------------------

interface HookEntry {
  type: string;
  command?: string;
  agentPath?: string;
}

interface HookGroup {
  matcher?: string;
  hooks: HookEntry[];
}

/** Extract all command script paths from a hooks.json structure. */
function extractCommandPaths(
  hooks: Record<string, HookGroup[]>,
  pluginDir: string,
): { path: string; raw: string }[] {
  const results: { path: string; raw: string }[] = [];

  for (const groups of Object.values(hooks)) {
    for (const group of groups) {
      for (const hook of group.hooks) {
        if (hook.type === 'command' && hook.command) {
          // Extract the script path from the command string.
          // Commands look like: "$CLAUDE_PLUGIN_ROOT"/hooks/foo.sh
          // or: bash "${CLAUDE_PLUGIN_ROOT}/scripts/foo.sh" --args
          const cmd = hook.command;

          // Replace $CLAUDE_PLUGIN_ROOT and ${CLAUDE_PLUGIN_ROOT} with plugin dir
          const expanded = cmd
            .replace(/"\$CLAUDE_PLUGIN_ROOT"/g, pluginDir)
            .replace(/\$\{CLAUDE_PLUGIN_ROOT\}/g, pluginDir)
            .replace(/"\$\{CLAUDE_PLUGIN_ROOT\}"/g, pluginDir)
            .replace(/\$CLAUDE_PLUGIN_ROOT/g, pluginDir);

          // Extract the script path (first token after optional 'bash')
          const tokens = expanded.split(/\s+/);
          let scriptPath = tokens[0];
          if (scriptPath === 'bash' && tokens[1]) {
            scriptPath = tokens[1];
          }

          // Clean up quotes
          scriptPath = scriptPath.replace(/^["']|["']$/g, '');

          // Only check .sh files (skip inline commands)
          if (scriptPath.endsWith('.sh')) {
            results.push({ path: scriptPath, raw: cmd });
          }
        }

        if (hook.type === 'agent' && hook.agentPath) {
          const resolved = resolve(pluginDir, hook.agentPath);
          results.push({ path: resolved, raw: hook.agentPath });
        }
      }
    }
  }

  return results;
}

describe('hooks.json references resolve', () => {
  for (const pluginName of pluginDirs) {
    const pluginDir = join(PLUGINS_DIR, pluginName);
    const hooksPath = join(pluginDir, 'hooks', 'hooks.json');

    describe(pluginName, () => {
      test('all command scripts and agent paths exist', async () => {
        const hj = (await readJson(hooksPath)) as Record<string, unknown>;
        if (!hj?.hooks) return;

        const refs = extractCommandPaths(
          hj.hooks as Record<string, HookGroup[]>,
          pluginDir,
        );

        for (const ref of refs) {
          try {
            await stat(ref.path);
          } catch {
            expect(ref.path).toBe(`EXISTS (referenced by: ${ref.raw})`);
          }
        }
      });
    });
  }
});
