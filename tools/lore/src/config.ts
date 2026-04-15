import { homedir } from 'node:os';
import { join } from 'node:path';
import type { EpistemicClass, LoreConfig, LoreDecayConfig } from './types';

const DEFAULT_DECAY: LoreDecayConfig = {
  lambda_per_hour: {
    DECISION: 0.000_08,
    HYPOTHESIS: 0.000_35,
    FACT: 0.000_05,
    QUESTION: 0.000_01,
    DEAD_END: 0.000_2,
  },
  question_urgency_per_unresolved: 0.35,
  question_urgency_per_day: 0.04,
  question_min_decay_floor: 0.88,
  contradiction_default_weight: -0.6,
  contradiction_score_floor: 0.1,
};

function expandPath(p: string): string {
  if (p.startsWith('~/')) {
    return join(homedir(), p.slice(2));
  }
  return p;
}

export function defaultDbPath(): string {
  return expandPath('~/.claude/lore/lore.sqlite');
}

export function defaultConfigPath(): string {
  return expandPath('~/.claude/lore/config.json');
}

export function defaultLoreConfig(overrides?: Partial<LoreConfig>): LoreConfig {
  const base: LoreConfig = {
    db_path: defaultDbPath(),
    ...structuredClone(DEFAULT_DECAY),
  };
  if (!overrides) {
    return base;
  }
  const mergedDecay = {
    ...DEFAULT_DECAY,
    ...overrides,
    lambda_per_hour: {
      ...DEFAULT_DECAY.lambda_per_hour,
      ...(overrides.lambda_per_hour ?? {}),
    },
  };
  return { ...base, ...overrides, ...mergedDecay };
}

export async function loadLoreConfig(): Promise<LoreConfig> {
  const path = defaultConfigPath();
  const f = Bun.file(path);
  const defaults = defaultLoreConfig();
  if (!(await f.exists())) {
    return defaults;
  }
  try {
    const raw = await f.json();
    if (raw && typeof raw === 'object') {
      const o = raw as Record<string, unknown>;
      const lambda = o.lambda_per_hour as
        | Partial<Record<EpistemicClass, number>>
        | undefined;
      return defaultLoreConfig({
        db_path:
          typeof o.db_path === 'string' ? expandPath(o.db_path) : undefined,
        lambda_per_hour: lambda
          ? { ...defaults.lambda_per_hour, ...lambda }
          : undefined,
        question_urgency_per_unresolved:
          typeof o.question_urgency_per_unresolved === 'number'
            ? o.question_urgency_per_unresolved
            : undefined,
        question_urgency_per_day:
          typeof o.question_urgency_per_day === 'number'
            ? o.question_urgency_per_day
            : undefined,
        question_min_decay_floor:
          typeof o.question_min_decay_floor === 'number'
            ? o.question_min_decay_floor
            : undefined,
        contradiction_default_weight:
          typeof o.contradiction_default_weight === 'number'
            ? o.contradiction_default_weight
            : undefined,
        contradiction_score_floor:
          typeof o.contradiction_score_floor === 'number'
            ? o.contradiction_score_floor
            : undefined,
      });
    }
  } catch {
    /* use defaults */
  }
  return defaults;
}
