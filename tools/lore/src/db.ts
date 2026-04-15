import { Database } from "bun:sqlite";
import { dirname } from "node:path";
import { mkdirSync } from "node:fs";

export function openLoreDb(dbPath: string): Database {
	mkdirSync(dirname(dbPath), { recursive: true });
	const db = new Database(dbPath);
	db.exec("PRAGMA journal_mode = WAL;");
	db.exec("PRAGMA foreign_keys = ON;");
	initSchema(db);
	return db;
}

function initSchema(db: Database): void {
	db.exec(`
    CREATE TABLE IF NOT EXISTS meta (
      key TEXT PRIMARY KEY,
      value TEXT NOT NULL
    );
    CREATE TABLE IF NOT EXISTS knowledge_objects (
      id TEXT PRIMARY KEY,
      cwd TEXT NOT NULL,
      canonical_key TEXT NOT NULL,
      body TEXT NOT NULL,
      metadata_json TEXT NOT NULL DEFAULT '{}',
      epistemic_class TEXT NOT NULL,
      confidence TEXT,
      priority TEXT,
      sessions_unresolved INTEGER NOT NULL DEFAULT 0,
      first_seen_at TEXT NOT NULL,
      last_seen_at TEXT NOT NULL,
      base_score REAL NOT NULL,
      UNIQUE(cwd, canonical_key)
    );
    CREATE INDEX IF NOT EXISTS idx_ko_cwd ON knowledge_objects(cwd);
    CREATE INDEX IF NOT EXISTS idx_ko_class ON knowledge_objects(epistemic_class);
    CREATE INDEX IF NOT EXISTS idx_ko_last_seen ON knowledge_objects(last_seen_at);
    CREATE TABLE IF NOT EXISTS edges (
      id TEXT PRIMARY KEY,
      from_id TEXT NOT NULL,
      to_id TEXT NOT NULL,
      kind TEXT NOT NULL,
      weight REAL NOT NULL,
      source TEXT NOT NULL,
      created_at TEXT NOT NULL,
      FOREIGN KEY (from_id) REFERENCES knowledge_objects(id) ON DELETE CASCADE,
      FOREIGN KEY (to_id) REFERENCES knowledge_objects(id) ON DELETE CASCADE
    );
    CREATE INDEX IF NOT EXISTS idx_edges_to ON edges(to_id);
    CREATE INDEX IF NOT EXISTS idx_edges_from ON edges(from_id);
    CREATE UNIQUE INDEX IF NOT EXISTS idx_edges_unique_triple ON edges(from_id, to_id, kind);
  `);
	const row = db
		.query("SELECT value FROM meta WHERE key = 'schema_version'")
		.get() as { value: string } | undefined;
	if (!row) {
		db.run("INSERT INTO meta (key, value) VALUES ('schema_version', '1')");
	}
}

export function mergeMetadata(
	existing: string,
	incoming: Record<string, unknown>,
): string {
	let base: Record<string, unknown> = {};
	try {
		base = JSON.parse(existing) as Record<string, unknown>;
	} catch {
		base = {};
	}
	const merged = { ...base, ...incoming };
	return JSON.stringify(merged);
}
