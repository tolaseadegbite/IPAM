# API Reference

A read-only JSON API (v1) for scripts and integrations: subnets, IP addresses, and devices. Perfect for nightly checks, external dashboards, and auditor snapshots. Anything that changes data still goes through the web UI.

## Authentication

Create a token on your **Account** page (API tokens card). Tokens authenticate with a Bearer header and are shown **once** at creation — copy it immediately. Revoke any time from the same card; revocation is instant.

```bash
curl -H "Authorization: Bearer YOUR_TOKEN" http://localhost:3000/api/v1/subnets
```

Missing, bogus, or expired tokens get `401` with `{ "error": { "code": "unauthorized", "message": "Valid Bearer token required." } }`. Only the digest is stored — Mainline itself can't recover a lost token, so generate a fresh one.

## Endpoints

All responses are JSON. Collections paginate with a `meta` envelope (`page`, `pages`, `count`, `limit`); every object carries its `id`.

- `GET /api/v1/subnets` — id, name, network_address, gateway, vlan_id
- `GET /api/v1/subnets/:id` — plus `total_ips` and `used_ips` (active + reserved)
- `GET /api/v1/ip_addresses` — id, address, status, reachability_status, last_seen_at, subnet_id, device_id
- `GET /api/v1/ip_addresses/:id` — plus notes
- `GET /api/v1/devices` — id, name, device_type, status, critical, department_id, employee_id
- `GET /api/v1/devices/:id` — plus mac_address and embedded `ip_addresses`

## Filtering addresses

The address list accepts Ransack filters under `q`:

```bash
# Rogues only
curl -G -H "Authorization: Bearer YOUR_TOKEN" http://localhost:3000/api/v1/ip_addresses \
  --data-urlencode "q[rogue_only]=true"

# Down addresses on one subnet
curl -G -H "Authorization: Bearer YOUR_TOKEN" http://localhost:3000/api/v1/ip_addresses \
  --data-urlencode "q[subnet_id_eq]=3" --data-urlencode "q[reachability_status_eq]=down"
```

Filterable fields: `rogue_only`, `status_eq`, `reachability_status_eq`, `subnet_id_eq`, `device_id_eq`. Unknown filters are ignored.

## Example: nightly rogue digest

`script/rogue_digest` (in the repo) prints every rogue IP as Markdown — pipe it to mail from cron:

```bash
MAINLINE_HOST=http://localhost:3000 MAINLINE_API_TOKEN=YOUR_TOKEN \
  script/rogue_digest | mail -s "Nightly rogue digest" noc@example.com
```
