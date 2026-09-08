#!/usr/bin/env sh
set -eu

: "${DB_USERNAME:?missing DB_USERNAME}"
: "${DB_PASSWORD:?missing DB_PASSWORD}"
: "${LOVESPACE_BACKUP_PASSWORD:?missing LOVESPACE_BACKUP_PASSWORD}"
: "${S3_BUCKET:?missing S3_BUCKET}"

stamp="$(date -u +%Y%m%dT%H%M%SZ)"
work_dir="$(mktemp -d)"
plain_file="$work_dir/lovespace-$stamp.sql.gz"
encrypted_file="$plain_file.enc"
trap 'rm -rf "$work_dir"' EXIT

docker compose -f compose.prod.yml exec -T mysql \
  mysqldump -u"$DB_USERNAME" -p"$DB_PASSWORD" --single-transaction --routines --events lovespace \
  | gzip -9 > "$plain_file"

openssl enc -aes-256-cbc -pbkdf2 -salt \
  -pass env:LOVESPACE_BACKUP_PASSWORD -in "$plain_file" -out "$encrypted_file"

ossutil cp "$encrypted_file" "oss://$S3_BUCKET/backups/daily/$(basename "$encrypted_file")"
if [ "$(date -u +%u)" = "7" ]; then
  ossutil cp "$encrypted_file" "oss://$S3_BUCKET/backups/weekly/$(basename "$encrypted_file")"
fi

# Configure OSS lifecycle rules for backups/daily (7 days) and backups/weekly
# (28 days). Retention is enforced by OSS even when this host is unavailable.
