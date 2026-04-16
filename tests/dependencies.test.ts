import { describe, expect, test } from 'bun:test';

/**
 * Verifies that external tools required by hook scripts are available
 * in the current environment. These are the tools that would need to
 * be present on a user's machine for the plugins to work.
 */

async function commandExists(cmd: string): Promise<boolean> {
  try {
    const proc = Bun.spawn(['which', cmd], {
      stdout: 'pipe',
      stderr: 'pipe',
    });
    const exitCode = await proc.exited;
    return exitCode === 0;
  } catch {
    return false;
  }
}

describe('required external dependencies', () => {
  // jq is used by virtually every hook script
  test('jq is installed', async () => {
    expect(await commandExists('jq')).toBe(true);
  });

  // bash is the shell for all hook scripts
  test('bash is installed', async () => {
    expect(await commandExists('bash')).toBe(true);
  });

  // awk is used for cost calculations in ledger and NCD in cues
  test('awk is installed', async () => {
    expect(await commandExists('awk')).toBe(true);
  });
});

describe('optional but recommended dependencies', () => {
  // gzip is used by cues for semantic matching (NCD algorithm)
  test('gzip is available (used by cues semantic matching)', async () => {
    expect(await commandExists('gzip')).toBe(true);
  });
});
