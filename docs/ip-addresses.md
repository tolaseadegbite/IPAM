# IP Addresses

IPs are auto-created when a subnet is added — you never create or delete them by hand. You assign, release, reserve, and investigate them.

## Lifecycle vs reachability

Two independent axes:

- **Status** (administrative): `available` → `active` (assigned to a device) → back to `available` on release. `reserved` holds an address out of the pool (e.g. gateways). `blacklisted` quarantines one — blacklisted IPs cannot be assigned.
- **Reachability** (observed): `unknown`, `up`, `down` — last reported by the scanner.

Assigning a device flips the IP to `active`; unassigning returns it to `available`. The app enforces this consistency for you.

## Rogue devices

An IP that answers ping with **no device assigned** is rogue: unknown hardware on your network. Find them from the dashboard card or the sidebar **Rogue Devices** shortcut, then either **Register** (edit the IP and attach the real device) or investigate. The scanner flags newly-seen rogues as security events.

## Ghost assets

An **assigned** IP unseen for 30+ days is a ghost — usually decommissioned gear nobody recorded. The dashboard lists them with one-click **Reclaim**, which releases the device and frees the address.

## IP pages

Show the online/offline badge, assignment, subnet, linked task history, and the audit trail. Actions: **Edit IP** (status, device, notes) and **Investigate IP** (opens a task pre-linked to the address).
