# Subnets

Subnets are CIDR blocks under management: name, network address (e.g. `192.168.1.0/24`), gateway, and optional VLAN.

## Creating a subnet

Subnets → New. Rules enforced at creation:

- Must be a valid CIDR, `/22` or smaller (larger ranges are refused — a `/16` would flood the database with host rows).
- The gateway must sit inside the range and may not be the network or broadcast address.
- Ranges may not overlap an existing subnet.

On creation the app **auto-populates every usable host IP** as `available`, reserving the gateway row. Deleting a subnet requires an admin.

## The pool grid

A subnet's page shows utilization plus the full IP pool: green `available`, blue-ish `active`, amber `reserved`, red `blacklisted`. Filter by assigned/free, search by address, click any cell to edit that IP. The grid pages to keep large subnets fast.

## Good practice

- Name subnets by role (`Servers`, `Staff`, `Printers`) and set the VLAN to match the switch config.
- Keep the gateway row reserved — that's how the app knows where the router lives.
