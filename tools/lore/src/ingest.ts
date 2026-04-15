import type { Database } from 'bun:sqlite';
import { canonicalKey, randomId } from './hash';
import { mergeMetadata } from './db';
import { confidenceToBase } from './scoring';
import type { EpistemicClass } from './types';
import { isEpistemicClass } from './types';

function resolveCwd(raw: string): string {
  return raw.trim();
}

function nowIso(): string {
  return new Date().toISOString().replace(/\.\d{3}Z$/, 'Z');
}

export type UpsertInput = {
  cwd: string;
  body: string;
  epistemic_class: EpistemicClass;
  confidence?: string | null;
  priority?: string | null;
  sessions_unresolved?: number;
  metadata: Record<string, unknown>;
};

export function upsertKnowledgeObject(
  db: Database,
  input: UpsertInput,
): string {
  const cwd = resolveCwd(input.cwd);
  const ckey = canonicalKey(cwd, input.epistemic_class, input.body);
  const ts = nowIso();
  const base = confidenceToBase(
    input.confidence,
    input.priority,
    input.epistemic_class,
  );
  const sur = Math.max(0, input.sessions_unresolved ?? 0);
  const meta = JSON.stringify(input.metadata);

  const existing = db
    .query(
      'SELECT id, metadata_json, sessions_unresolved, first_seen_at FROM knowledge_objects WHERE cwd = ? AND canonical_key = ?',
    )
    .get(cwd, ckey) as
    | {
        id: string;
        metadata_json: string;
        sessions_unresolved: number;
        first_seen_at: string;
      }
    | undefined;

  if (existing) {
    const mergedMeta = mergeMetadata(existing.metadata_json, input.metadata);
    const maxSur = Math.max(existing.sessions_unresolved, sur);
    db.run(
      `UPDATE knowledge_objects SET
        last_seen_at = ?,
        body = ?,
        confidence = COALESCE(?, confidence),
        priority = COALESCE(?, priority),
        sessions_unresolved = ?,
        base_score = ?,
        metadata_json = ?
      WHERE id = ?`,
      ts,
      input.body,
      input.confidence ?? null,
      input.priority ?? null,
      maxSur,
      base,
      mergedMeta,
      existing.id,
    );
    return existing.id;
  }

  const id = randomId();
  db.run(
    `INSERT INTO knowledge_objects (
        id, cwd, canonical_key, body, metadata_json, epistemic_class,
        confidence, priority, sessions_unresolved, first_seen_at, last_seen_at, base_score
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
    id,
    cwd,
    ckey,
    input.body,
    meta,
    input.epistemic_class,
    input.confidence ?? null,
    input.priority ?? null,
    sur,
    ts,
    ts,
    base,
  );
  return id;
}

export function ingestArchivistSession(
  db: Database,
  session: Record<string, unknown>,
): number {
  const cwd = String(session.cwd ?? '').trim();
  if (!cwd) {
    return 0;
  }
  const sessionId = String(session.session_id ?? '');
  const ts = String(session.timestamp ?? '');
  let count = 0;
  const baseMeta = {
    source_plugin: 'archivist',
    session_id: sessionId,
    session_timestamp: ts,
  };

  const decisions = (session.decisions as unknown[]) ?? [];
  for (const d of decisions) {
    const o = d as Record<string, string>;
    const rule = o.rule ?? '';
    const rationale = o.rationale ?? '';
    if (!rule && !rationale) {
      continue;
    }
    const body = [rule, rationale].filter(Boolean).join(' — ');
    const ec = parseClass(o.epistemic_class, 'DECISION');
    upsertKnowledgeObject(db, {
      cwd,
      body,
      epistemic_class: ec,
      confidence: o.confidence,
      priority: null,
      sessions_unresolved: 0,
      metadata: { ...baseMeta, kind: 'decision' },
    });
    count++;
  }

  const deadEnds = (session.dead_ends as unknown[]) ?? [];
  for (const d of deadEnds) {
    const o = d as Record<string, string>;
    const approach = o.approach ?? '';
    const why = o.why_failed ?? '';
    if (!approach && !why) {
      continue;
    }
    const body = [approach, why].filter(Boolean).join(' — ');
    upsertKnowledgeObject(db, {
      cwd,
      body,
      epistemic_class: 'DEAD_END',
      confidence: null,
      priority: null,
      metadata: { ...baseMeta, kind: 'dead_end' },
    });
    count++;
  }

  const questions = (session.open_questions as unknown[]) ?? [];
  for (const d of questions) {
    const o = d as Record<string, string | number>;
    const q = o.question ?? '';
    const ctx = o.context ?? '';
    if (!q && !ctx) {
      continue;
    }
    const body = [q, ctx].filter(Boolean).join(' — ');
    const sur = Number(o.sessions_unresolved ?? 0);
    upsertKnowledgeObject(db, {
      cwd,
      body,
      epistemic_class: 'QUESTION',
      confidence: null,
      priority: typeof o.priority === 'string' ? o.priority : null,
      sessions_unresolved: Number.isFinite(sur) ? sur : 0,
      metadata: { ...baseMeta, kind: 'open_question' },
    });
    count++;
  }

  return count;
}

function parseClass(
  raw: string | undefined,
  fallback: EpistemicClass,
): EpistemicClass {
  if (raw && isEpistemicClass(raw)) {
    return raw;
  }
  return fallback;
}

export function ingestScribeSession(
  db: Database,
  payload: Record<string, unknown>,
): number {
  const cwd = String(payload.cwd ?? '').trim();
  const sessionId = String(payload.session_id ?? '');
  if (!cwd) {
    return 0;
  }
  const captures = (payload.captures as unknown[]) ?? [];
  let count = 0;
  const baseMeta = {
    source_plugin: 'scribe',
    session_id: sessionId,
  };

  for (const c of captures) {
    const o = c as Record<string, string | null>;
    const decision = o.decision?.trim();
    if (!decision) {
      continue;
    }
    const intent = o.intent?.trim() ?? '';
    const trade = o.tradeoffs?.trim() ?? '';
    const file = o.file?.trim() ?? '';
    const body = [decision, trade, intent, file ? `@${file}` : '']
      .filter(Boolean)
      .join(' — ');
    upsertKnowledgeObject(db, {
      cwd,
      body,
      epistemic_class: 'DECISION',
      confidence: 'medium',
      priority: null,
      metadata: {
        ...baseMeta,
        kind: 'scribe_decision',
        file,
      },
    });
    count++;
  }
  return count;
}

export function addEdge(
  db: Database,
  fromId: string,
  toId: string,
  kind: string,
  weight: number,
  source: string,
): string {
  const id = randomId();
  const ts = nowIso();
  const res = db.run(
    `INSERT OR IGNORE INTO edges (id, from_id, to_id, kind, weight, source, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)`,
    id,
    fromId,
    toId,
    kind,
    weight,
    source,
    ts,
  );
  if (res.changes === 0) {
    const row = db
      .query(
        'SELECT id FROM edges WHERE from_id = ? AND to_id = ? AND kind = ?',
      )
      .get(fromId, toId, kind) as { id: string } | undefined;
    return row?.id ?? id;
  }
  return id;
}

export function ingestCartographerContradictions(
  db: Database,
  audit: Record<string, unknown>,
  cfgWeight: number,
): number {
  const cwd = String(audit.cwd ?? '').trim();
  if (!cwd) {
    return 0;
  }
  const issues = (audit.issues as unknown[]) ?? [];
  const auditId = String(audit.audit_id ?? '');
  let n = 0;
  for (const issue of issues) {
    const o = issue as Record<string, unknown>;
    const cat = String(o.category ?? '');
    if (cat !== 'contradiction' && cat !== 'hierarchy_conflict') {
      continue;
    }
    const desc = String(o.description ?? '');
    const evidence = String(o.evidence ?? '');
    const files = (o.files as string[]) ?? [];
    if (!desc && !evidence) {
      continue;
    }
    const bodyA =
      files[0] != null
        ? `${desc} (${files[0]})`
        : `${desc} (instruction conflict A)`;
    const bodyB =
      files[1] != null
        ? `${desc} (${files[1]})`
        : `${evidence || desc} (instruction conflict B)`;
    const meta = {
      source_plugin: 'cartographer',
      audit_id: auditId,
      issue_id: String(o.id ?? ''),
      category: cat,
    };
    const idA = upsertKnowledgeObject(db, {
      cwd,
      body: bodyA.slice(0, 12_000),
      epistemic_class: 'HYPOTHESIS',
      confidence: 'low',
      metadata: { ...meta, side: 'a' },
    });
    const idB = upsertKnowledgeObject(db, {
      cwd,
      body: bodyB.slice(0, 12_000),
      epistemic_class: 'HYPOTHESIS',
      confidence: 'low',
      metadata: { ...meta, side: 'b' },
    });
    addEdge(db, idA, idB, 'CONTRADICTS', cfgWeight, 'cartographer');
    n++;
  }
  return n;
}
