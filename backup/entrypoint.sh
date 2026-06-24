#!/bin/bash
set -e

chmod +x /backup/*.sh
crontab /backup/crontab
exec cron -f
