import { afterEach, beforeEach, describe, expect, test } from 'bun:test';
import { mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';

const ROOT = resolve(import.meta.dirname, '..');

/** Run a bash snippet that sources a utility script and calls a function. */
async function runBash(script: string, env?: Record<string, string>) {
  const proc = Bun.spawn(['bash', '-c', script], {
    stdout: 'pipe',
    stderr: 'pipe',
    env: { ...process.env, ...env },
  });
  const [stdout, stderr] = await Promise.all([
    new Response(proc.stdout).text(),
    new Response(proc.stderr).text(),
  ]);
  const exitCode = await proc.exited;
  return { stdout: stdout.trim(), stderr: stderr.trim(), exitCode };
}

// ---------------------------------------------------------------------------
// Ledger cost calculation
// ---------------------------------------------------------------------------

describe('ledger: cost calculation', () => {
  const LEDGER_UTILS = join(ROOT, 'plugins/ledger/hooks/ledger-utils.sh');

  function costScript(
    model: string,
    input: number,
    output: number,
    cacheRead = 0,
    cacheCreate = 0,
  ) {
    return `
      set -euo pipefail
      export CLAUDE_PLUGIN_ROOT="${join(ROOT, 'plugins/ledger')}"
      source "${LEDGER_UTILS}"
      ledger_compute_cost "${model}" ${input} ${output} ${cacheRead} ${cacheCreate}
    `;
  }

  test('sonnet pricing: 1M input + 1M output', async () => {
    const { stdout, exitCode } = await runBash(
      costScript('claude-sonnet-4-5', 1000000, 1000000),
    );
    expect(exitCode).toBe(0);
    // IN: 1M * $3/M = $3, OUT: 1M * $15/M = $15 → $18
    expect(Number.parseFloat(stdout)).toBeCloseTo(18.0, 2);
  });

  test('opus 4.1 pricing: 100k input + 50k output', async () => {
    const { stdout, exitCode } = await runBash(
      costScript('claude-opus-4-1', 100000, 50000),
    );
    expect(exitCode).toBe(0);
    // IN: 100k * $15/M = $1.50, OUT: 50k * $75/M = $3.75 → $5.25
    expect(Number.parseFloat(stdout)).toBeCloseTo(5.25, 2);
  });

  test('haiku 3.5 pricing with cache', async () => {
    const { stdout, exitCode } = await runBash(
      costScript('claude-haiku-3.5', 500000, 100000, 200000, 50000),
    );
    expect(exitCode).toBe(0);
    // IN: 500k * $0.80/M = $0.40
    // OUT: 100k * $4.00/M = $0.40
    // CACHE_READ: 200k * $0.08/M = $0.016
    // CACHE_CREATE: 50k * $1.00/M = $0.05
    expect(Number.parseFloat(stdout)).toBeCloseTo(0.866, 3);
  });

  test('zero tokens returns zero cost', async () => {
    const { stdout, exitCode } = await runBash(
      costScript('claude-sonnet-4-5', 0, 0, 0, 0),
    );
    expect(exitCode).toBe(0);
    expect(Number.parseFloat(stdout)).toBe(0);
  });

  test('unknown model falls back to sonnet pricing', async () => {
    const { stdout: sonnet } = await runBash(
      costScript('claude-sonnet-4-5', 1000000, 0),
    );
    const { stdout: unknown } = await runBash(
      costScript('some-unknown-model', 1000000, 0),
    );
    expect(Number.parseFloat(unknown)).toBe(Number.parseFloat(sonnet));
  });
});

// ---------------------------------------------------------------------------
// Ledger budget check
// ---------------------------------------------------------------------------

describe('ledger: budget check', () => {
  let tmpDir: string;

  beforeEach(async () => {
    tmpDir = await mkdtemp(join(tmpdir(), 'ledger-test-'));
  });

  afterEach(async () => {
    await rm(tmpDir, { recursive: true, force: true });
  });

  async function budgetScript(
    currentCost: string,
    budgetCost: string,
    warningPct = '80',
    reservePct = '12',
  ) {
    // Write config.json into the temp dir so CLAUDE_PLUGIN_ROOT/config.json resolves
    const config = {
      enabled: true,
      storage_path: `${tmpDir}/ledger`,
      budgets: {
        session_cost_usd: budgetCost,
        warning_threshold_pct: warningPct,
      },
      reserve_buffer_pct: reservePct,
    };
    await Bun.write(join(tmpDir, 'config.json'), JSON.stringify(config));

    return `
      set -euo pipefail
      export CLAUDE_PLUGIN_ROOT="${tmpDir}"
      export CLAUDE_HOME="${tmpDir}"
      source "${join(ROOT, 'plugins/ledger/hooks/ledger-utils.sh')}"
      ledger_check_budget "${currentCost}"
    `;
  }

  test('returns ok when under budget', async () => {
    const { stdout, exitCode } = await runBash(
      await budgetScript('0.50', '5.00'),
    );
    expect(exitCode).toBe(0);
    expect(stdout).toBe('ok');
  });

  test('returns ok when no budget set', async () => {
    const { stdout, exitCode } = await runBash(
      await budgetScript('100.00', '0'),
    );
    expect(exitCode).toBe(0);
    expect(stdout).toBe('ok');
  });

  test('returns warning when past threshold', async () => {
    const { stdout, exitCode } = await runBash(
      await budgetScript('4.20', '5.00', '80', '12'),
    );
    expect(exitCode).toBe(0);
    expect(stdout).toStartWith('warning:');
  });

  test('returns exceeded when past effective limit', async () => {
    const { stdout, exitCode } = await runBash(
      await budgetScript('4.50', '5.00', '80', '12'),
    );
    expect(exitCode).toBe(0);
    // effective limit = 5.00 * (1 - 12/100) = 4.40
    expect(stdout).toStartWith('exceeded:');
  });
});

// ---------------------------------------------------------------------------
// Onlooker validate-path utilities
// ---------------------------------------------------------------------------

describe('onlooker: validate-path utilities', () => {
  let tmpDir: string;
  const VALIDATE_PATH = join(ROOT, 'plugins/onlooker/hooks/validate-path.sh');

  beforeEach(async () => {
    tmpDir = await mkdtemp(join(tmpdir(), 'onlooker-test-'));
  });

  afterEach(async () => {
    await rm(tmpDir, { recursive: true, force: true });
  });

  function vpScript(body: string) {
    return `
      set -euo pipefail
      export CLAUDE_PLUGIN_ROOT="${tmpDir}"
      export CLAUDE_HOME="${tmpDir}"
      source "${VALIDATE_PATH}"
      ${body}
    `;
  }

  test('validate_file_exists returns 0 for existing file', async () => {
    await Bun.write(join(tmpDir, 'test.txt'), 'hello');
    const { exitCode } = await runBash(
      vpScript(`validate_file_exists "${tmpDir}/test.txt"`),
    );
    expect(exitCode).toBe(0);
  });

  test('validate_file_exists returns 1 for missing file', async () => {
    const { exitCode } = await runBash(
      vpScript(`validate_file_exists "${tmpDir}/nope.txt"`),
    );
    expect(exitCode).toBe(1);
  });

  test('ensure_dir_exists creates directory', async () => {
    const dir = join(tmpDir, 'sub', 'dir');
    const { exitCode } = await runBash(
      vpScript(`ensure_dir_exists "${dir}" && test -d "${dir}" && echo "ok"`),
    );
    expect(exitCode).toBe(0);
  });

  test('ensure_file_exists creates file and parent dirs', async () => {
    const file = join(tmpDir, 'a', 'b', 'c.txt');
    const { stdout, exitCode } = await runBash(
      vpScript(
        `ensure_file_exists "${file}" && test -f "${file}" && echo "ok"`,
      ),
    );
    expect(exitCode).toBe(0);
    expect(stdout).toBe('ok');
  });

  test('safe_append creates file and appends data', async () => {
    const file = join(tmpDir, 'append.txt');
    const { exitCode } = await runBash(
      vpScript(`
        safe_append "${file}" "line1"
        safe_append "${file}" "line2"
        cat "${file}"
      `),
    );
    expect(exitCode).toBe(0);
  });

  test('validate_dir_exists returns 1 for empty string', async () => {
    const { exitCode } = await runBash(vpScript('validate_dir_exists ""'));
    expect(exitCode).toBe(1);
  });
});

// ---------------------------------------------------------------------------
// Ledger path expansion
// ---------------------------------------------------------------------------

describe('ledger: path expansion', () => {
  const LEDGER_UTILS = join(ROOT, 'plugins/ledger/hooks/ledger-utils.sh');

  test('_expand_path expands ~ to $HOME', async () => {
    const { stdout, exitCode } = await runBash(`
      set -euo pipefail
      export CLAUDE_PLUGIN_ROOT="${join(ROOT, 'plugins/ledger')}"
      source "${LEDGER_UTILS}"
      _expand_path "~/foo/bar"
    `);
    expect(exitCode).toBe(0);
    expect(stdout).toBe(`${process.env.HOME}/foo/bar`);
  });

  test('_expand_path leaves absolute paths unchanged', async () => {
    const { stdout, exitCode } = await runBash(`
      set -euo pipefail
      export CLAUDE_PLUGIN_ROOT="${join(ROOT, 'plugins/ledger')}"
      source "${LEDGER_UTILS}"
      _expand_path "/absolute/path"
    `);
    expect(exitCode).toBe(0);
    expect(stdout).toBe('/absolute/path');
  });
});
