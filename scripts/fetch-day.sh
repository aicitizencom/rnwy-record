#!/usr/bin/env bash
# Copies one day's file from RNWY's public store into this repository, after checking it
# against its manifest. Never replaces a day that is already here.
#
# Usage: scripts/fetch-day.sh 2026-11-12
# Exit 0: the day was added, is already here and unchanged, or is not published yet.
# Exit 1: a file failed its check, or a published day differs from the copy kept here.
# Prints "added <path>" on the last line when a new day was written.
set -euo pipefail

DAY="$1"
if ! [[ "$DAY" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then echo "Not a date: $DAY" >&2; exit 1; fi

BASE="${RECORD_BASE:-https://zgzjdlheaofmmaxbvrzh.supabase.co/storage/v1/object/public/record/daily}"
DIR="daily/${DAY:0:4}/${DAY:5:2}"
CSV="$DIR/$DAY.csv.gz"
MAN="$DIR/$DAY.json"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

code=$(curl -sS -L --max-time 60 -o "$TMP/m.json" -w '%{http_code}' "$BASE/$DAY.json?t=$(date +%s)" || echo 000)
if [ "$code" != "200" ]; then echo "$DAY: no manifest published yet (HTTP $code)."; exit 0; fi

want=$(jq -er '.sha256_csv_gz' "$TMP/m.json")
rows=$(jq -er '.rows' "$TMP/m.json")
if ! [[ "$want" =~ ^[0-9a-f]{64}$ ]]; then echo "$DAY: manifest has no usable fingerprint." >&2; exit 1; fi
if [ "$(jq -r '.day' "$TMP/m.json")" != "$DAY" ]; then echo "$DAY: manifest names a different day." >&2; exit 1; fi

if [ -f "$CSV" ]; then
  have=$(sha256sum "$CSV" | cut -d' ' -f1)
  if [ "$have" = "$want" ]; then echo "$DAY: already here, unchanged."; exit 0; fi
  echo "$DAY: the published file ($want) differs from the copy kept here ($have). Nothing replaced." >&2
  exit 1
fi

curl -sS -L --fail --max-time 300 -o "$TMP/d.csv.gz" "$BASE/$DAY.csv.gz?t=$(date +%s)"
got=$(sha256sum "$TMP/d.csv.gz" | cut -d' ' -f1)
if [ "$got" != "$want" ]; then echo "$DAY: file fingerprint $got does not match manifest $want." >&2; exit 1; fi
lines=$(( $(gzip -dc "$TMP/d.csv.gz" | wc -l) - 1 ))
if [ "$lines" != "$rows" ]; then echo "$DAY: file has $lines rows, manifest says $rows." >&2; exit 1; fi
# Addresses are never part of this record. Refuse a file that carries one.
if gzip -dc "$TMP/d.csv.gz" | grep -qiE 'https?://'; then echo "$DAY: file contains an address. Refused." >&2; exit 1; fi

mkdir -p "$DIR"
cp "$TMP/d.csv.gz" "$CSV"
cp "$TMP/m.json" "$MAN"
echo "$DAY: $rows rows, sha256 $want"
echo "added $CSV"
