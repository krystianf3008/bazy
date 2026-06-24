#!/bin/bash
set -e

DEST=/backups/full/$(date +%Y%m%d_%H%M%S)
mkdir -p "$DEST"

echo "[$(date)] Rozpoczynam pełny backup (pg_basebackup) -> $DEST"
PGPASSWORD=ReplicaPass123! pg_basebackup -h 172.20.0.2 -U repl_user -D "$DEST" -Ft -z -P -w
echo "[$(date)] Pełny backup zakończony: $DEST"

# Retencja: zachowaj ostatnie 4 pełne backupy (~1 miesiąc)
ls -dt /backups/full/*/ 2>/dev/null | tail -n +5 | xargs -r rm -rf
