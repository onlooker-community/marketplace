import type { EpistemicClass, LoreDecayConfig } from './types';

/** Hours between two ISO timestamps; non-negative. */
export function hoursBetween(isoFrom: string, isoTo: string): number {
  const a = Date.parse(isoFrom);
  const b = Date.parse(isoTo);
  if (Number.isNaN(a) || Number.isNaN(b)) {
    return 0;
  }
  const h = (b - a) / 3_600_000;
  return Math.max(0, h);
}

export function daysBetween(isoFrom: string, isoTo: string): number {
  return hoursBetween(isoFrom, isoTo) / 24;
}

/**
 * Monotone decreasing decay for non-QUESTION classes (staleness since first seen).
 */
export function classDecayFactor(
  epistemicClass: EpistemicClass,
  firstSeenAt: string,
  nowIso: string,
  cfg: LoreDecayConfig,
): number {
  const ageHours = hoursBetween(firstSeenAt, nowIso);
  const lambda = cfg.lambda_per_hour[epistemicClass] ?? 0.0001;
  return Math.exp(-lambda * ageHours);
}

/**
 * QUESTION: keep a mild decay floor so unresolved items do not fade; urgency dominates elsewhere.
 */
export function questionDecayFloor(
  firstSeenAt: string,
  nowIso: string,
  cfg: LoreDecayConfig,
): number {
  const d = classDecayFactor('QUESTION', firstSeenAt, nowIso, cfg);
  return Math.max(cfg.question_min_decay_floor, d);
}

export function questionUrgencyMultiplier(
  sessionsUnresolved: number,
  firstSeenAt: string,
  nowIso: string,
  cfg: LoreDecayConfig,
): number {
  const ageDays = daysBetween(firstSeenAt, nowIso);
  const u =
    cfg.question_urgency_per_unresolved * Math.max(0, sessionsUnresolved);
  const d = cfg.question_urgency_per_day * ageDays;
  return 1 + u + d;
}

/**
 * Incident CONTRADICTS edges use negative weights; target is `to_id`.
 * factor = clamp(floor, 1 + sum(weights)).
 */
export function contradictionFactor(
  sumWeightsOnTarget: number,
  cfg: LoreDecayConfig,
): number {
  return Math.max(cfg.contradiction_score_floor, 1 + sumWeightsOnTarget);
}

export function confidenceToBase(
  confidence: string | null | undefined,
  priority: string | null | undefined,
  epistemicClass: EpistemicClass,
): number {
  if (epistemicClass === 'QUESTION') {
    const p = (priority ?? 'medium').toLowerCase();
    if (p === 'high') {
      return 0.85;
    }
    if (p === 'low') {
      return 0.45;
    }
    return 0.65;
  }
  const c = (confidence ?? 'medium').toLowerCase();
  if (c === 'high') {
    return 1;
  }
  if (c === 'low') {
    return 0.4;
  }
  return 0.7;
}

export function effectiveScore(
  row: {
    epistemic_class: EpistemicClass;
    first_seen_at: string;
    last_seen_at: string;
    base_score: number;
    sessions_unresolved: number;
  },
  nowIso: string,
  sumContradictionWeights: number,
  cfg: LoreDecayConfig,
): number {
  const base = row.base_score;
  if (row.epistemic_class === 'QUESTION') {
    const decayF = questionDecayFloor(row.first_seen_at, nowIso, cfg);
    const urg = questionUrgencyMultiplier(
      row.sessions_unresolved,
      row.first_seen_at,
      nowIso,
      cfg,
    );
    const c = contradictionFactor(sumContradictionWeights, cfg);
    return base * decayF * urg * c;
  }
  const decay = classDecayFactor(
    row.epistemic_class,
    row.first_seen_at,
    nowIso,
    cfg,
  );
  const c = contradictionFactor(sumContradictionWeights, cfg);
  return base * decay * c;
}
