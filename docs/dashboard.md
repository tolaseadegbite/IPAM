# Dashboard

The dashboard (`/`) is the NOC overview: current network health, capacity, recent events, and the action queue. Everything on it updates live as scans complete — no refresh needed.

## Hero status strip

- **Operational / Degraded**: `Degraded` means a critical device is offline or there were severe (outage/security) events in the last 24 hours. The reasons list underneath spells out why.
- **Hosts up**: reachable IPs out of total inventoried, with a reachability ring.
- **Capacity**: share of IPs that are active or reserved.
- **Scan freshness**: when the last sweep finished and how long it took. A `(stale)` badge means no completed scan in 24 hours — check [Scanning](/docs/scanning).
- **Scan Now**: starts an immediate sweep of all subnets. The button locks to `Scanning…` while the sweep runs.

## KPI cards

- **Reachability**: percent of hosts responding.
- **Rogue devices**: unidentified responders — links to the filtered IP list.
- **Reclaimable**: ghost assets (assigned, unseen 30+ days).
- **Priority tasks**: high-priority open cards — links to boards.

## Trend chart

Stacked bars of network events per Info, Drift, Outage, and Security series. Switch ranges with the **1H / 24H / 7D / 14D** pills: 1H uses 5-minute buckets, 24H hourly buckets, 7D/14D daily. Your choice persists across live updates. Short ranges are often empty on a stable network — events only fire on state changes, so flat zeros mean quiet, not broken.

## Subnet health

Top 5 subnets by utilization with used/total bars (red over 90%, amber over 70%). `+ N more` links to the full [Subnets](/subnets) list.

## Needs attention

The ranked action queue (max 8, critical first): severe events, offline critical devices, rogue IPs, ghosts, and high-priority tasks. Each row links to the relevant record, and ghosts offer one-click **Reclaim** (frees the IP and dismisses the row). Hover a truncated row to read the full text. Empty queue shows `All clear`.

## Composition, watchlist, log

- **Composition**: device-type breakdown and IP allocation doughnut.
- **Critical watchlist**: every critical-flagged device with live status dot — red pulsing means offline.
- **Network log**: the 10 most recent events with kind, message, device, and IP.
