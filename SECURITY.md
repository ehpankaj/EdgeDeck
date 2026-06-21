# Security Policy

EdgeDeck is an EdgeTX Lua widget that runs locally on a radio SD card. It does
not use network services and does not transmit data by itself.

## Sensitive Data

Runtime files can contain private flight data:

- `sessions.log` may contain flight history.
- `gps_last.txt` may contain the last saved coordinate.

Do not attach real logs or coordinates to public issues unless they have been
reviewed and sanitized.

## Reporting

For security-sensitive reports, avoid posting public coordinates, model details,
or private flight logs. Open a minimal GitHub issue with sanitized reproduction
steps, or contact the maintainer.
