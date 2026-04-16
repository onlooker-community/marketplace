# Documentation

Structured documentation for the Onlooker ecosystem.

## By Audience

| You want to... | Start here |
| --- | --- |
| Understand why decisions were made | [Architecture Decision Records](./architecture/README.md) |
| Update or create a plugin | [Plugins](./PLUGINS.md) |
| Fix something broken | [Troubleshooting](./TROUBLESHOOTING.md) |
| Understand the system | [Onlooker Ecosystem Overview](./OVERVIEW.md) |

## Directory Structure

```text
docs/
├── architecture/           # ADRs - "why did we do it this way?"
│   ├── 0001-*.md          # Documentation layer architecture
│   ├── 0002-*.md          # Tradeoff gate pattern
│   └── 0003-*.md          # Principle surfacing architecture
├── research/              # PDFs of peer reviewed research that informs that system
│   ├── PDF_TITLE.pdf      
│   └── README.md          # Index of PDF research
├── DEVELOPMENT.md         # Development workflow for working in this repo
├── PLUGINS.md             # High-level plugins information
├── OVERVIEW.md            # High-level overview of the ecosystem
└── TROUBLESHOOTING.md     # Common issues and solutions
```