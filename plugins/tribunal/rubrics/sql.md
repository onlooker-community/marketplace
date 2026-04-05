# SQL Rubric

Evaluate the submitted SQL on the following criteria.

## Criteria

**1. Correctness (35%)**
Does the query or migration produce the correct result? Are joins, filters, and aggregations logically sound?

**2. Safety (25%)**
Is the SQL safe to run in production? For migrations: is it reversible? Does it avoid locking issues on large tables? Are destructive operations guarded?

**3. Idempotency (20%)**
Can the SQL be run multiple times safely? Does it use `IF NOT EXISTS`,
`ON CONFLICT`, or equivalent guards?

**4. Performance (10%)**
Are indexes used appropriately? Are there obvious full-table scans that
could be avoided?

**5. Conventions (10%)**
Does the SQL follow standard conventions for the target database
(PostgreSQL, MySQL, etc.)? Are names snake_case and descriptive?

## Scoring

0.9-1.0: Safe to run in production
0.8–0.89: Minor issues, verify before running
0.6–0.79: Needs fixes before production use
0.4–0.59: Significant safety or correctness issues
0.0–0.39: Do not run

Flag any potentially destructive operations explicitly, regardless of score.
