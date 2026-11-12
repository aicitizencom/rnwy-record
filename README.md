# RNWY record

The dated public record kept by [RNWY](https://rnwy.com): what each listed MCP server said when it was checked, one file per day.

This repository publishes. It does not measure. The checks run once a day at about 05:00 UTC elsewhere; a workflow here copies the day's file, tests it against its manifest, commits it, and signs it.

## What is here

```
daily/YYYY/MM/YYYY-MM-DD.csv.gz   one line per check made that UTC day
daily/YYYY/MM/YYYY-MM-DD.json     manifest: row count, SHA-256 of the file, counts by reply
```

Columns of the daily file:

| Column | Meaning |
|---|---|
| `listing_id` | RNWY's id for the listing |
| `source` | the directory the listing came from (`registry` is the official MCP Registry; `smithery` is Smithery) |
| `name` | the listing's name in that directory |
| `checked_at` | when the check ran (UTC) |
| `answered` | `true` when any HTTP reply came back within 6 seconds |
| `status_code` | the HTTP reply code; empty when nothing came back |
| `no_reply` | `timeout` or `no_reply` when nothing came back; empty otherwise |
| `response_ms` | time to the reply, in milliseconds |

## What this record can and cannot show

- The check is one plain HTTP GET to the address the listing gives. `answered` means something replied. It does not mean the server works, and it does not mean a tool call would succeed. The reply code is published so the reader can draw the line elsewhere.
- Many addresses sit behind a shared hosting gateway. For those, the reply may come from the gateway.
- A server that does not answer gets a second, slower try before "no answer" is written (since 2026-11-12).
- Server addresses are not published, because some carry keys. Raw error text is not published, because it can contain the address.
- Days before this repository began, known gaps, and days when the checker itself was at fault are listed in the continuity ledger: https://rnwy.com/record
- A day is published once. If a later export of the same day differs, the workflow refuses it and fails in public view; nothing is replaced.

## Checking a file

Each file's SHA-256 is in its manifest:

```
sha256sum daily/2026/11/2026-11-12.csv.gz
```

Each file is also signed when it is committed. The signature is a GitHub artifact attestation, recorded in a public transparency log that RNWY does not control. With the GitHub CLI:

```
gh attestation verify daily/2026/11/2026-11-12.csv.gz --repo aicitizencom/rnwy-record
```

A signature shows that this file existed in this form when this repository's workflow ran. It does not show that the measurement was right.

## Corrections

An error in the record can be reported by opening an issue here or writing to contact@rnwy.com. Raw rows are not edited; corrections are added to the ledger with their date.

## License

To be stated with the first monthly snapshot (December 1, 2026).
