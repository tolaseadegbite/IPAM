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

## Where MAC addresses come from (ARP locality)

Reachability (up/down) works on every subnet — ping routes everywhere. MAC capture does not: nmap learns MACs from ARP replies, and ARP never crosses a router. Concretely:

- **Subnets local to the app server** (it holds an address there): sweeps return MACs for every live host, adopted automatically into empty device records.
- **Remote subnets**: sweeps report up/down accurately but yield zero MACs. MACs there exist only through manual entry or import — the scanner cannot conjure them.

An "up but MAC-less" device on a remote segment is normal, not a malfunction. A sudden loss of MACs on a *local* segment means privilege broke (`sudo` for nmap) — check the logs, not the flags.

## Multi-homing the scanner

To give the scanner L2 sight into remote segments, hold one static IP per subnet on the server (e.g. via NetworkManager, no gateway needed — presence is all ARP requires):

1. Pick a verified-free, verified-silent address per subnet (last-free avoids DHCP pools).
2. Append it to the wired profile and reapply (flapless).
3. Verify per subnet: gateway ARP state plus an `nmap -sn -PR` probe on known-live hosts expecting `MAC Address:` lines.
4. Leave the addresses in place; scheduled sweeps harvest automatically. Roll back by removing them — the app needs no changes either way.

Caveat: an address only works if the switch port actually carries that segment's frames. If probes stay silent, the fix is trunk/VLAN config on the switch side, not more addresses.

## Automatic stale-link reclaim

Device-linked IPs dark longer than **5 days** are released back to the pool automatically during sweeps (`device_id` cleared, status falls to `available`, one `info` event each). Rows are never deleted; `reserved` rows are never touched; live legs of multi-homed devices are unaffected (the decision is per IP). Manually releasing earlier is always available via the dashboard **Reclaim** action.

## What the scanner reports

- **Drift** (`drift`): a known MAC claimed a different IP. The device follows the MAC; its old IPs are released.
- **Takeover** (`security`): an unknown MAC sits on an IP assigned to a known device. The IP is freed and flagged — treat as hostile until proven otherwise.
- **Rogue sighting** (`security`): a reachable IP with no inventory record.
- **Adoption** (`info`): a device recorded without a MAC inherits the discovered one.
- **Ghost watch** (`outage`/`info`): long-unseen assignments surface for reclaim — and past 5 days dark, sweeps release them automatically (see above).

Severe findings also auto-file triage cards (see [Boards & Tasks](/docs/boards)) and notify admins — with flap protection so one flapping asset doesn't spam you.

## Stale data?

If `last scan` shows `(stale)` (no completed sweep in 24h), check that the job worker is running and nmap is installed (see [FAQ](/docs/faq)).
