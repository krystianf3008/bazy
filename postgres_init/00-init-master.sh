#!/bin/bash
set -e

echo "Konfiguracja Mastera (Warszawa1)..."

# 1. Utworzenie użytkownika do replikacji
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    CREATE ROLE repl_user WITH REPLICATION PASSWORD 'ReplicaPass123!' LOGIN;
EOSQL

# 2. Bezpieczeństwo: Ograniczenie dostępu (Kryterium 8) i konfiguracja pg_hba.conf
# Wymuszamy szyfrowanie scram-sha-256 i wpuszczamy tylko zdefiniowane adresy IP (HAProxy)
cat > "$PGDATA/pg_hba.conf" <<-EOF
# TYPE  DATABASE        USER            ADDRESS                 METHOD
local   all             postgres                                peer
local   all             all                                     scram-sha-256
# Pozwalamy kontu postgres na dostęp z sieci wew. (potrzebne do monitoringu)
host    all             postgres        172.17.0.0/16           scram-sha-256
# Dostęp dla replikacji
host    replication     repl_user       172.17.0.0/16           scram-sha-256
# Zezwolenie na połączenia TYLKO przez HAProxy WRITE (172.17.0.6) i READ (172.17.0.7)
host    ppv_db          all             172.17.0.6/32           scram-sha-256
host    ppv_db          all             172.17.0.7/32           scram-sha-256
EOF

# 3. Parametry postgresql.conf dla replikacji i wydajności
cat >> "$PGDATA/postgresql.conf" <<-EOF
listen_addresses = '*'
password_encryption = scram-sha-256
wal_level = replica
max_wal_senders = 10
max_replication_slots = 10
wal_keep_size = 128MB
hot_standby = on
# Archiwizacja WAL na wypadek awarii (dla serwera DR)
archive_mode = on
archive_command = 'cp %p /archive/%f'
EOF

# Utworzenie folderu na archiwum WAL
mkdir -p /archive
chown postgres:postgres /archive