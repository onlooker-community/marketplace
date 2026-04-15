# Changes: {{date}}

_Session: {{session_id_short}} · {{file_count}} files · {{cwd}}_

{{distiller_prose}}

## Files changed

{{#each files}}

- `{{path}}` — {{intent}}
{{/each}}

{{#if decisions}}

## Decisions made

{{#each decisions}}
→ See [{{topic}}](../decisions/{{slug}}.md)
{{/each}}
{{/if}}
