#!/bin/bash
set -e

crontab /backup/crontab
exec cron -f
