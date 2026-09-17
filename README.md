# pgvector-patroni-oci

OCI image build for PostgreSQL with pgvector and Patroni.

The image is based on the pgvector PostgreSQL image and adds an isolated
Patroni runtime environment with pinned Python dependencies.

## Current build

| Component | Version |
| --- | --- |
| PostgreSQL | 18 |
| pgvector | 0.8.6 |
| Patroni | 4.1.5 |
| Debian | trixie |

## Repository layout

Generated build contexts are stored by PostgreSQL version and distribution:

```text
18/
└── trixie/
    ├── Dockerfile
    ├── requirements.in
    └── requirements.lock
