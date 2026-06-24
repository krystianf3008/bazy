#!/bin/bash
set -e

FILE=/backups/diff/$(date +%Y%m%d_%H%M%S)_ppv_db.dump
mkdir -p /backups/diff

echo "[$(date)] Rozpoczynam backup różnicowy (pg_dump) -> $FILE"
PGPASSWORD=SuperSecretPassword! pg_dump -h 172.20.0.2 -U postgres -F custom -f "$FILE" ppv_db
echo "[$(date)] Backup różnicowy zakończony: $FILE"

# Retencja: zachowaj ostatnie 7 dumpów (1 tydzień)
ls -t /backups/diff/*.dump 2>/dev/null | tail -n +8 | xargs -r rm -f
