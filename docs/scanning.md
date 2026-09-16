# Network Scanning

Every few minutes the scanner sweeps all inventoried subnets and updates reachability across the app. Dashboard numbers, the attention queue, and event history all flow from these sweeps.

## How it works

1. The scheduler enqueues one scan job per subnet.
2. Each sweep runs an ARP ping scan (`nmap -sn`) over the subnet's CIDR.
3. Responders flip to `up` with fresh timestamps and discovered MACs; previously-up IPs that go quiet flip to `down`.
4. Interesting findings become [network events](#what-the-scanner-reports): known devices on new IPs (drift), unknown MACs on assigned IPs (takeover), first-seen rogues.
5. The dashboard rebroadcasts live — watch rows and KPIs update without refreshing.

## Requirements

Scanning needs **`nmap` installed with passwordless sudo** on the app server. Without it, sweeps skip loudly in the logs and reachability goes stale (the app refuses to guess — an empty sweep never marks hosts offline).

## Manual scans

**Scan Now** on the dashboard starts an immediate full sweep. The button locks to `Scanning…` until the batch finishes.

## What the scanner reports

- **Drift** (`drift`): a known MAC claimed a different IP. The device follows the MAC; its old IPs are released.
- **Takeover** (`security`): an unknown MAC sits on an IP assigned to a known device. The IP is freed and flagged — treat as hostile until proven otherwise.
- **Rogue sighting** (`security`): a reachable IP with no inventory record.
- **Adoption** (`info`): a device recorded without a MAC inherits the discovered one.
- **Ghost watch** (`outage`/`info`): long-unseen assignments surface for reclaim.

Severe findings also auto-file triage cards (see [Boards & Tasks](/docs/boards)) and notify admins — with flap protection so one flapping asset doesn't spam you.

## Stale data?

If `last scan` shows `(stale)` (no completed sweep in 24h), check that the job worker is running and nmap is installed (see [FAQ](/docs/faq)).
