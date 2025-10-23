-- Install PostgreSQL extensions for the workshop

-- pg_stat_statements: Track query performance
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

-- pg_trgm: Trigram matching for GIN text search
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- btree_gin: GIN indexes for B-tree comparable types
CREATE EXTENSION IF NOT EXISTS btree_gin;

\echo 'Extensions installed successfully!'
