#!/usr/bin/env bun

import { openLoreDb } from '../src/db';
import { loadLoreConfig } from '../src/config';
import {
  ingestArchivistSession,
  ingestScribeSession,
  ingestCartographerContradictions,
  addEdge,
} from '../src/ingest';
import { queryRankedForCwd, formatContextBlock } from '../src/query';
const USAGE = `
lore — Onlooker Lore (Knowledge Gravity Engine)

Usage:
  lore ingest --format archivist-session --file <path>
  lore ingest --format scribe-session --file <path>
  lore sync-cartographer --file <audit.json>
  lore query --cwd <path> [--limit N] [--json]
  lore context-for-inject --cwd <path> [--max-words N]
  lore export-for-brief --cwd <path> [--since ISO8601] [--json]
  lore edge add --from <uuid> --to <uuid> [--weight N] [--source NAME]
  lore doctor

Environment:
  LORE_DB_PATH   Override SQLite path (~/.claude/lore/lore.sqlite default)
`.trim();

function argVal(flag: string, argv: string[]): string | undefined {
  const i = argv.indexOf(flag);
  if (i >= 0 && argv[i + 1]) {
    return argv[i + 1];
  }
  return undefined;
}

function hasFlag(flag: string, argv: string[]): boolean {
  return argv.includes(flag);
}

async function main(): Promise<void> {
  const argv = process.argv.slice(2);
  const cmd = argv[0];
  if (!cmd || cmd === '--help' || cmd === '-h') {
    console.log(USAGE);
    process.exit(0);
  }

  const cfg = await loadLoreConfig();
  const dbPath = process.env.LORE_DB_PATH ?? cfg.db_path;
  const db = openLoreDb(dbPath);
  const decay = cfg;

  try {
    switch (cmd) {
      case 'ingest': {
        const format = argVal('--format', argv);
        const file = argVal('--file', argv);
        if (!format || !file) {
          console.error('ingest requires --format and --file');
          process.exit(1);
        }
        const raw = await Bun.file(file).text();
        const json = JSON.parse(raw) as Record<string, unknown>;
        let n = 0;
        if (format === 'archivist-session') {
          n = ingestArchivistSession(db, json);
        } else if (format === 'scribe-session') {
          n = ingestScribeSession(db, json);
        } else {
          console.error(`Unknown format: ${format}`);
          process.exit(1);
        }
        console.log(JSON.stringify({ ingested: n, ok: true }));
        break;
      }
      case 'sync-cartographer': {
        const file = argVal('--file', argv);
        if (!file) {
          console.error('sync-cartographer requires --file');
          process.exit(1);
        }
        const raw = await Bun.file(file).text();
        const audit = JSON.parse(raw) as Record<string, unknown>;
        const n = ingestCartographerContradictions(
          db,
          audit,
          cfg.contradiction_default_weight,
        );
        console.log(JSON.stringify({ contradictions_synced: n, ok: true }));
        break;
      }
      case 'query': {
        const cwd = argVal('--cwd', argv);
        if (!cwd) {
          console.error('query requires --cwd');
          process.exit(1);
        }
        const limit = Number(argVal('--limit', argv) ?? '40');
        const now = new Date().toISOString().replace(/\.\d{3}Z$/, 'Z');
        const rows = queryRankedForCwd(db, cwd, now, decay, limit);
        if (hasFlag('--json', argv)) {
          console.log(JSON.stringify(rows, null, 2));
        } else {
          for (const r of rows) {
            console.log(
              `${r.effective_score.toFixed(3)}\t${r.epistemic_class}\t${r.body.slice(0, 120)}`,
            );
          }
        }
        break;
      }
      case 'context-for-inject': {
        const cwd = argVal('--cwd', argv);
        if (!cwd) {
          console.error('context-for-inject requires --cwd');
          process.exit(1);
        }
        const maxWords = Number(argVal('--max-words', argv) ?? '120');
        const now = new Date().toISOString().replace(/\.\d{3}Z$/, 'Z');
        const rows = queryRankedForCwd(db, cwd, now, decay, 25);
        const block = formatContextBlock(rows, maxWords);
        process.stdout.write(block);
        break;
      }
      case 'export-for-brief': {
        const cwd = argVal('--cwd', argv);
        if (!cwd) {
          console.error('export-for-brief requires --cwd');
          process.exit(1);
        }
        const since = argVal('--since', argv) ?? '1970-01-01T00:00:00Z';
        const now = new Date().toISOString().replace(/\.\d{3}Z$/, 'Z');
        const ranked = queryRankedForCwd(db, cwd, now, decay, 200);
        const sinceMs = Date.parse(since);
        const filtered = ranked.filter(
          (r) => Date.parse(r.last_seen_at) >= sinceMs,
        );
        const questions = filtered.filter(
          (r) => r.epistemic_class === 'QUESTION',
        );
        const contradicted = filtered.filter(
          (r) => r.sum_contradiction_weights < -0.01,
        );
        const staleHypotheses = filtered.filter(
          (r) => r.epistemic_class === 'HYPOTHESIS' && r.effective_score < 0.2,
        );
        const out = {
          cwd,
          since,
          top_questions: questions.slice(0, 15),
          top_contradictions: contradicted.slice(0, 15),
          stale_hypotheses: staleHypotheses.slice(0, 10),
          generated_at: now,
        };
        console.log(JSON.stringify(out, null, 2));
        break;
      }
      case 'edge': {
        if (argv[1] !== 'add') {
          console.error('Use: lore edge add --from ... --to ...');
          process.exit(1);
        }
        const from = argVal('--from', argv);
        const to = argVal('--to', argv);
        if (!from || !to) {
          console.error('edge add requires --from and --to');
          process.exit(1);
        }
        const w = Number(
          argVal('--weight', argv) ?? String(cfg.contradiction_default_weight),
        );
        const source = argVal('--source', argv) ?? 'manual';
        const id = addEdge(db, from, to, 'CONTRADICTS', w, source);
        console.log(JSON.stringify({ edge_id: id, ok: true }));
        break;
      }
      case 'doctor': {
        const ko = db
          .query('SELECT COUNT(*) as c FROM knowledge_objects')
          .get() as { c: number };
        const ed = db.query('SELECT COUNT(*) as c FROM edges').get() as {
          c: number;
        };
        const ver = db
          .query("SELECT value FROM meta WHERE key = 'schema_version'")
          .get() as { value: string } | undefined;
        console.log(
          JSON.stringify(
            {
              db_path: dbPath,
              schema_version: ver?.value ?? '?',
              knowledge_objects: ko.c,
              edges: ed.c,
              config_path: '~/.claude/lore/config.json',
            },
            null,
            2,
          ),
        );
        break;
      }
      default:
        console.error(`Unknown command: ${cmd}\n`);
        console.log(USAGE);
        process.exit(1);
    }
  } finally {
    db.close();
  }
}

await main();
