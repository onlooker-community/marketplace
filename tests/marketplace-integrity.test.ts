import { describe, expect, test } from 'bun:test';
import { readdir, stat } from 'node:fs/promises';
import { join, resolve } from 'node:path';

const ROOT = resolve(import.meta.dirname, '..');
const PLUGINS_DIR = join(ROOT, 'plugins');

/** Read and parse a JSON file, returning null on failure. */
async function readJson(path: string): Promise<unknown> {
  try {
    const file = Bun.file(path);
    return await file.json();
  } catch {
    return null;
  }
}

/** Check whether a path exists. */
async function exists(path: string): Promise<boolean> {
  try {
    await stat(path);
    return true;
  } catch {
    return false;
  }
}

// ---------------------------------------------------------------------------
// Load marketplace.json once
// ---------------------------------------------------------------------------

interface MarketplacePlugin {
  name: string;
  description: string;
  source: string;
}

interface Marketplace {
  name: string;
  metadata: { description: string; version: string };
  plugins: MarketplacePlugin[];
}

const marketplacePath = join(ROOT, '.claude-plugin', 'marketplace.json');
const marketplace = (await readJson(marketplacePath)) as Marketplace;

// ---------------------------------------------------------------------------
// 1. marketplace.json structural tests
// ---------------------------------------------------------------------------

describe('marketplace.json', () => {
  test('exists and is valid JSON', () => {
    expect(marketplace).not.toBeNull();
  });

  test('has required top-level fields', () => {
    expect(marketplace.name).toBe('onlooker-marketplace');
    expect(marketplace.metadata).toBeDefined();
    expect(marketplace.metadata.version).toMatch(/^\d+\.\d+\.\d+$/);
    expect(Array.isArray(marketplace.plugins)).toBe(true);
    expect(marketplace.plugins.length).toBeGreaterThan(0);
  });

  test('every plugin entry has name, description, and source', () => {
    for (const p of marketplace.plugins) {
      expect(p.name).toBeString();
      expect(p.name.length).toBeGreaterThan(0);
      expect(p.description).toBeString();
      expect(p.description.length).toBeGreaterThan(0);
      expect(p.source).toBeString();
      expect(p.source).toStartWith('./plugins/');
    }
  });

  test('no duplicate plugin names', () => {
    const names = marketplace.plugins.map((p) => p.name);
    expect(new Set(names).size).toBe(names.length);
  });

  test('every plugin source directory exists', async () => {
    for (const p of marketplace.plugins) {
      const dir = resolve(ROOT, p.source);
      expect(await exists(dir)).toBe(true);
    }
  });
});

// ---------------------------------------------------------------------------
// 2. Per-plugin structural tests
// ---------------------------------------------------------------------------

const pluginDirs = await readdir(PLUGINS_DIR);

describe('plugin structure', () => {
  for (const pluginName of pluginDirs) {
    const pluginDir = join(PLUGINS_DIR, pluginName);

    describe(pluginName, () => {
      // -- plugin.json --
      test('has a valid plugin.json', async () => {
        const pj = await readJson(
          join(pluginDir, '.claude-plugin', 'plugin.json'),
        );
        expect(pj).not.toBeNull();

        const p = pj as Record<string, unknown>;
        expect(p.name).toBe(pluginName);
        expect(typeof p.version).toBe('string');
        expect(p.version as string).toMatch(/^\d+\.\d+\.\d+$/);
        expect(typeof p.description).toBe('string');
      });

      // -- hooks.json --
      test('has a valid hooks.json', async () => {
        const hooksPath = join(pluginDir, 'hooks', 'hooks.json');
        const hj = await readJson(hooksPath);
        expect(hj).not.toBeNull();

        const h = hj as Record<string, unknown>;
        expect(h.hooks).toBeDefined();
        expect(typeof h.hooks).toBe('object');
      });

      // -- hooks.json references valid lifecycle events --
      test('hooks.json only uses known lifecycle events', async () => {
        const knownEvents = new Set([
          'PreToolUse',
          'PostToolUse',
          'SessionStart',
          'SessionEnd',
          'PreCompact',
          'Stop',
          'SubagentStart',
          'SubagentStop',
          'UserPromptSubmit',
          'InstructionsLoaded',
          'ConfigChange',
        ]);

        const hj = (await readJson(
          join(pluginDir, 'hooks', 'hooks.json'),
        )) as Record<string, unknown>;
        if (!hj?.hooks) return;

        const hooks = hj.hooks as Record<string, unknown>;
        for (const event of Object.keys(hooks)) {
          expect(knownEvents.has(event)).toBe(true);
        }
      });

      // -- referenced agents exist --
      test('plugin.json agent paths resolve to existing files', async () => {
        const pj = (await readJson(
          join(pluginDir, '.claude-plugin', 'plugin.json'),
        )) as Record<string, unknown>;
        if (!pj?.agents) return;

        for (const agentPath of pj.agents as string[]) {
          const resolved = resolve(pluginDir, agentPath);
          expect(await exists(resolved)).toBe(true);
        }
      });

      // -- referenced commands exist --
      test('plugin.json command paths resolve to existing files', async () => {
        const pj = (await readJson(
          join(pluginDir, '.claude-plugin', 'plugin.json'),
        )) as Record<string, unknown>;
        if (!pj?.commands) return;

        for (const cmdPath of pj.commands as string[]) {
          const resolved = resolve(pluginDir, cmdPath);
          expect(await exists(resolved)).toBe(true);
        }
      });

      // -- marketplace.json lists this plugin --
      test('is listed in marketplace.json', () => {
        const entry = marketplace.plugins.find((p) => p.name === pluginName);
        expect(entry).toBeDefined();
      });
    });
  }
});

// ---------------------------------------------------------------------------
// 3. Cross-reference: marketplace lists only existing plugins
// ---------------------------------------------------------------------------

describe('marketplace ↔ plugins cross-reference', () => {
  test('marketplace.json and plugins/ directory are in sync', () => {
    const marketplaceNames = new Set(marketplace.plugins.map((p) => p.name));
    const dirNames = new Set(pluginDirs);

    // Every marketplace entry has a directory
    for (const name of marketplaceNames) {
      expect(dirNames.has(name)).toBe(true);
    }
    // Every directory has a marketplace entry
    for (const name of dirNames) {
      expect(marketplaceNames.has(name)).toBe(true);
    }
  });
});
