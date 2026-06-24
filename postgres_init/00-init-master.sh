#!/bin/bash
set -e

echo "Konfiguracja Mastera (Warszawa1)..."

# 1. Utworzenie uzytkownika do replikacji
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" \
  -c "CREATE ROLE repl_user WITH REPLICATION PASSWORD 'ReplicaPass123!' LOGIN;"

# 2. Bezpieczenstwo: pg_hba.conf (bez heredoca - unikamy problemow z CRLF na Windows)
{
  printf '# TYPE  DATABASE        USER            ADDRESS                 METHOD\n'
  printf 'local   all             postgres                                peer\n'
  printf 'local   all             all                                     scram-sha-256\n'
  printf 'host    all             postgres        172.20.0.0/16           scram-sha-256\n'
  printf 'host    replication     repl_user       172.20.0.0/16           scram-sha-256\n'
  printf 'host    ppv_db          all             172.20.0.6/32           scram-sha-256\n'
  printf 'host    ppv_db          all             172.20.0.7/32           scram-sha-256\n'
} > "$PGDATA/pg_hba.conf"

# 3. Parametry postgresql.conf dla replikacji
{
  printf 'listen_addresses = '"'"'*'"'"'\n'
  printf 'password_encryption = scram-sha-256\n'
  printf 'wal_level = replica\n'
  printf 'max_wal_senders = 10\n'
  printf 'max_replication_slots = 10\n'
  printf 'wal_keep_size = 128MB\n'
  printf 'hot_standby = on\n'
  printf 'archive_mode = on\n'
  printf 'archive_command = '"'"'cp %%p /archive/%%f'"'"'\n'
} >> "$PGDATA/postgresql.conf"

# Folder na archiwum WAL
mkdir -p /archive
chown postgres:postgres /archive
