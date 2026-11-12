#!/usr/bin/env bash
# Copies one monthly snapshot from RNWY's public store into this repository, after checking
# every file against the manifest. Never replaces a snapshot that is already here.
#
# Usage: scripts/fetch-snapshot.sh 2026-11
# Exit 0: the snapshot was added, is already here and unchanged, or is not published yet.
# Exit 1: a file failed its check, the manifest is a preview or an unfinished month, or the
#         published snapshot differs from the copy kept here.
# Prints "added <path>" for each file written.
set -euo pipefail

MONTH="$1"
if ! [[ "$MONTH" =~ ^[0-9]{4}-[0-9]{2}$ ]]; then echo "Not a month: $MONTH" >&2; exit 1; fi

ROOT="${RECORD_ROOT:-https://zgzjdlheaofmmaxbvrzh.supabase.co/storage/v1/object/public/record}"
DIR="snapshots/$MONTH"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

code=$(curl -sS -L --max-time 60 -o "$TMP/manifest.json" -w '%{http_code}' "$ROOT/$DIR/manifest.json?t=$(date +%s)" || echo 000)
if [ "$code" != "200" ]; then echo "$MONTH: no snapshot published yet (HTTP $code)."; exit 0; fi

if [ "$(jq -r '.snapshot' "$TMP/manifest.json")" != "$MONTH" ]; then echo "$MONTH: manifest names a different month." >&2; exit 1; fi
if [ "$(jq -r '.preview' "$TMP/manifest.json")" != "false" ]; then echo "$MONTH: manifest is a preview. Refused." >&2; exit 1; fi
if [ "$(jq -r '.complete' "$TMP/manifest.json")" != "true" ]; then echo "$MONTH: the month was not over when this was built. Refused." >&2; exit 1; fi

if [ -f "$DIR/manifest.json" ]; then
  if cmp -s "$DIR/manifest.json" "$TMP/manifest.json"; then echo "$MONTH: already here, unchanged."; exit 0; fi
  echo "$MONTH: the published manifest differs from the copy kept here. Nothing replaced." >&2
  exit 1
fi

# Every file the manifest names, checked against its fingerprint.
n=$(jq '.files | length' "$TMP/manifest.json")
if [ "$n" -lt 1 ]; then echo "$MONTH: manifest lists no files." >&2; exit 1; fi
for i in $(seq 0 $((n - 1))); do
  f=$(jq -er ".files[$i].file" "$TMP/manifest.json")
  want=$(jq -er ".files[$i].sha256" "$TMP/manifest.json")
  if ! [[ "$f" =~ ^[a-z0-9.-]+$ ]] || ! [[ "$want" =~ ^[0-9a-f]{64}$ ]]; then echo "$MONTH: bad entry in manifest: $f" >&2; exit 1; fi
  curl -sS -L --fail --max-time 600 -o "$TMP/$f" "$ROOT/$DIR/$f?t=$(date +%s)"
  got=$(sha256sum "$TMP/$f" | cut -d' ' -f1)
  if [ "$got" != "$want" ]; then echo "$MONTH: $f has fingerprint $got, manifest says $want." >&2; exit 1; fi
done

# The record never carries server addresses. Refuse a server table that has such a column.
if [ -f "$TMP/mcp-servers.csv.gz" ] && gzip -dc "$TMP/mcp-servers.csv.gz" | head -1 | tr ',' '\n' | grep -qixE 'endpoint_url|endpoint|url|address'; then
  echo "$MONTH: mcp-servers has an address column. Refused." >&2; exit 1
fi

# The month's daily files must be here too, each matching the fingerprint the manifest gives.
d=$(jq '.daily_files | length' "$TMP/manifest.json")
for i in $(seq 0 $((d - 1))); do
  [ "$d" -gt 0 ] || break
  day=$(jq -er ".daily_files[$i].day" "$TMP/manifest.json")
  want=$(jq -er ".daily_files[$i].sha256" "$TMP/manifest.json")
  scripts/fetch-day.sh "$day"
  local_file="daily/${day:0:4}/${day:5:2}/$day.csv.gz"
  if [ ! -f "$local_file" ]; then echo "$MONTH: daily file for $day is not here." >&2; exit 1; fi
  got=$(sha256sum "$local_file" | cut -d' ' -f1)
  if [ "$got" != "$want" ]; then echo "$MONTH: daily file $day here ($got) differs from the manifest ($want)." >&2; exit 1; fi
done

mkdir -p "$DIR"
for i in $(seq 0 $((n - 1))); do
  f=$(jq -er ".files[$i].file" "$TMP/manifest.json")
  cp "$TMP/$f" "$DIR/$f"
  echo "added $DIR/$f"
done
cp "$TMP/manifest.json" "$DIR/manifest.json"
echo "added $DIR/manifest.json"
echo "$MONTH: snapshot copied, $n files, $d daily files checked."
