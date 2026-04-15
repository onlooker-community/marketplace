import type { Database } from 'bun:sqlite';
import type { EpistemicClass, KnowledgeRow, LoreDecayConfig } from './types';
import { effectiveScore } from './scoring';

/** cwd query matches rows where row.cwd is same or parent of query cwd (prefix path). */
function cwdMatches(rowCwd: string, queryCwd: string): boolean {
  const rc = rowCwd.replace(/\/$/, '');
  const qc = queryCwd.replace(/\/$/, '');
  return qc === rc || qc.startsWith(`${rc}/`);
}

function loadContradictionSums(
  db: Database,
  ids: string[],
): Map<string, number> {
  const sums = new Map<string, number>();
  for (const id of ids) {
    sums.set(id, 0);
  }
  if (ids.length === 0) {
    return sums;
  }
  const placeholders = ids.map(() => '?').join(',');
  const rows = db
    .query(
      `SELECT to_id as tid, SUM(weight) as w FROM edges WHERE kind = 'CONTRADICTS' AND to_id IN (${placeholders}) GROUP BY to_id`,
    )
    .all(...ids) as { tid: string; w: number }[];
  for (const r of rows) {
    sums.set(r.tid, r.w ?? 0);
  }
  return sums;
}

type RankedRow = KnowledgeRow & {
  effective_score: number;
  sum_contradiction_weights: number;
};

export function queryRankedForCwd(
  db: Database,
  queryCwd: string,
  nowIso: string,
  decayCfg: LoreDecayConfig,
  limit: number,
): RankedRow[] {
  const all = db
    .query(
      `SELECT id, cwd, canonical_key, body, metadata_json, epistemic_class,
        confidence, priority, sessions_unresolved, first_seen_at, last_seen_at, base_score
       FROM knowledge_objects`,
    )
    .all() as KnowledgeRow[];

  const filtered = all.filter((r) => cwdMatches(r.cwd, queryCwd));
  const ids = filtered.map((r) => r.id);
  const sums = loadContradictionSums(db, ids);

  const ranked: RankedRow[] = filtered.map((r) => {
    const sumW = sums.get(r.id) ?? 0;
    const eff = effectiveScore(
      {
        epistemic_class: r.epistemic_class as EpistemicClass,
        first_seen_at: r.first_seen_at,
        last_seen_at: r.last_seen_at,
        base_score: r.base_score,
        sessions_unresolved: r.sessions_unresolved,
      },
      nowIso,
      sumW,
      decayCfg,
    );
    return {
      ...r,
      effective_score: eff,
      sum_contradiction_weights: sumW,
    };
  });
  ranked.sort((a, b) => b.effective_score - a.effective_score);
  return ranked.slice(0, limit);
}

export function formatContextBlock(
  rows: RankedRow[],
  maxWords: number,
): string {
  const lines: string[] = ['Lore (organizational memory):'];
  let words = 3;
  for (const r of rows) {
    if (r.epistemic_class !== 'QUESTION' && r.effective_score < 0.15) {
      continue;
    }
    const line = `- [${r.epistemic_class}] ${r.body.replace(/\s+/g, ' ').trim()}`;
    const add = line.split(/\s+/).length;
    if (words + add > maxWords) {
      break;
    }
    lines.push(line);
    words += add;
  }
  if (lines.length <= 1) {
    return '';
  }
  return lines.join('\n');
}
