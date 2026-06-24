#!/bin/bash
set -e

ARCHIVE=/archive
DEST=/backups/logs
mkdir -p "$DEST"

OUTFILE="$DEST/$(date +%Y%m%d_%H%M%S)_wal.tar.gz"

echo "[$(date)] Rozpoczynam backup logów WAL -> $OUTFILE"

# Archiwizuj tylko segmenty WAL (24-znakowe nazwy hex), pomijaj .history i .backup
WAL_FILES=$(find "$ARCHIVE" -maxdepth 1 -regextype posix-extended \
  -regex '.*/[0-9A-F]{24}$' 2>/dev/null)

if [ -z "$WAL_FILES" ]; then
  echo "[$(date)] Brak plików WAL do zarchiwizowania."
  exit 0
fi

echo "$WAL_FILES" | tar -czf "$OUTFILE" -T -
echo "[$(date)] Backup logów WAL zakończony: $OUTFILE"

# Retencja: zachowaj ostatnie 7 archiwów WAL
ls -t "$DEST"/*.tar.gz 2>/dev/null | tail -n +8 | xargs -r rm -f
