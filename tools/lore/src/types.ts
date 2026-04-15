export type EpistemicClass =
  | 'DECISION'
  | 'HYPOTHESIS'
  | 'FACT'
  | 'QUESTION'
  | 'DEAD_END';

const EPISTEMIC_CLASSES: readonly EpistemicClass[] = [
  'DECISION',
  'HYPOTHESIS',
  'FACT',
  'QUESTION',
  'DEAD_END',
] as const;

export function isEpistemicClass(s: string): s is EpistemicClass {
  return (EPISTEMIC_CLASSES as readonly string[]).includes(s);
}

export type LoreDecayConfig = {
  lambda_per_hour: Record<EpistemicClass, number>;
  question_urgency_per_unresolved: number;
  question_urgency_per_day: number;
  question_min_decay_floor: number;
  contradiction_default_weight: number;
  contradiction_score_floor: number;
};

export type LoreConfig = LoreDecayConfig & {
  db_path: string;
};

export type KnowledgeRow = {
  id: string;
  cwd: string;
  canonical_key: string;
  body: string;
  metadata_json: string;
  epistemic_class: EpistemicClass;
  confidence: string | null;
  priority: string | null;
  sessions_unresolved: number;
  first_seen_at: string;
  last_seen_at: string;
  base_score: number;
};
