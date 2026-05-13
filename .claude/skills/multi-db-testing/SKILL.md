---
name: multi-db-testing
description: "MySQL vs PostgreSQL gotchas, environment-specific test patterns, connection management"
---

# Multi-DB Testing Skill

## PURPOSE
Panduan untuk environment-matrix-runner dan qa-tester dalam menjalankan tests di multiple database engines.

## MYSQL vs POSTGRESQL GOTCHAS

### Data Types
| MySQL | PostgreSQL | Gotcha |
|-------|-----------|--------|
| `TINYINT(1)` | `BOOLEAN` | MySQL returns 0/1, PgSQL returns true/false |
| `AUTO_INCREMENT` | `SERIAL` | Different syntax in raw SQL |
| `DATETIME` | `TIMESTAMP` | PgSQL has timezone-aware timestamps |
| `TEXT` | `TEXT` | MySQL has 65KB limit, PgSQL unlimited |
| `ENUM('a','b')` | Custom TYPE | PgSQL needs CREATE TYPE first |
| `JSON` | `JSONB` | PgSQL JSONB is binary, faster queries |

### Query Differences
| Feature | MySQL | PostgreSQL |
|---------|-------|-----------|
| String concat | `CONCAT(a, b)` | `a \|\| b` |
| LIMIT offset | `LIMIT 10, 5` | `LIMIT 10 OFFSET 5` |
| Case sensitivity | Case-insensitive default | Case-sensitive default |
| UPSERT | `ON DUPLICATE KEY UPDATE` | `ON CONFLICT DO UPDATE` |
| Group BY | Lenient (non-strict) | Strict (all non-agg columns) |
| Boolean | `WHERE col = 1` | `WHERE col = true` |

### ORM Considerations
- **Laravel Eloquent**: Mostly DB-agnostic, watch for raw queries
- **Prisma**: Different provider in schema.prisma
- **SQLAlchemy**: Dialect-specific, test both

## CONNECTION STRING PATTERNS

### Docker MySQL
```
DB_ENGINE=mysql
DB_HOST=db  # docker service name
DB_PORT=3306
DB_NAME=project_db
DB_USER=root
DB_PASSWORD=rootpass
DATABASE_URL=mysql://root:rootpass@db:3306/project_db
```

### Docker PostgreSQL
```
DB_ENGINE=pgsql
DB_HOST=db-pgsql  # docker service name
DB_PORT=5432
DB_NAME=project_db
DB_USER=postgres
DB_PASSWORD=rootpass
DATABASE_URL=postgresql://postgres:rootpass@db-pgsql:5432/project_db
```

## ENVIRONMENT-SPECIFIC TEST PATTERNS

### Test Isolation
1. **MySQL**: `START TRANSACTION` → test → `ROLLBACK`
2. **PostgreSQL**: Same, but watch for DDL in transactions (auto-commits in MySQL)

### Migration Testing
1. Run `migrate:fresh` per environment
2. Verify all migrations pass on both engines
3. Common failure: MySQL-specific syntax in migrations

### Seeder Testing
1. Run seeders per environment
2. Watch for: auto-increment reset differences, boolean seeding

## SWITCHING ENVIRONMENTS

### Docker Compose Override
```yaml
# docker-compose.pgsql.yml
services:
  db-pgsql:
    image: postgres:15
    environment:
      POSTGRES_DB: project_db
      POSTGRES_PASSWORD: rootpass
    ports:
      - "5432:5432"
```

### Runtime Switch
```bash
# MySQL (default)
docker compose exec -T php php artisan test

# PostgreSQL
DB_ENGINE=pgsql DB_HOST=db-pgsql DB_PORT=5432 docker compose exec -T php php artisan test
```
