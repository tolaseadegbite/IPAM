# NAT Assistant

NAT is the AI network assistant: ask questions in plain English, and it reads live inventory, runs lookups, and makes careful changes — explaining as it goes.

## Starting a chat

NAT Assistant → New chat. Pick a model first (the default is pre-selected), then type. Chats stream live, keep full history, support attachments, and can be deleted any time. The list paginates with infinite scroll.

Useful prompts:

- `How many rogue devices are on the network right now?`
- `Find me 5 free IPs on the Staff subnet`
- `What changed on srv-dc-02 in the last week?`
- `Register the laptop with MAC 02:00:00:00:00:0A for Adaeze in IT`

## Attachments

Attach images (e.g. photos of handwritten IP books — NAT reads them visually), CSV and Excel sheets, and PDFs. It will never guess ambiguous handwriting like `1` vs `7` — it asks you to confirm first.

## What NAT can do

- **Lookups**: IPs, subnets, devices (including by MAC), employees, branches, departments, free-IP hunts (truly free: unassigned, never-seen, unreserved), device IP history, network stats, recent activity, device breakdowns.
- **Changes**: assign/unassign IPs, create/update devices and employees, bulk-create devices from a list, delete devices (frees their IPs) or employees (only when deviceless).

## Safety rules it follows

- **Confirms before destructive acts**: unassigning and deleting always ask first.
- **Refuses bad writes**: assigned or blacklisted IPs can't be double-assigned.
- **Minimal edits**: updates touch only the fields you asked about.
- **Bulk creates summarize first**: multi-device jobs show a plan, ask for confirmation, then report per-row success/failure.
- **Auto-creates missing org records** when provisioning (branch/department/employee) rather than failing.

## Models

The Models page catalogs available chat models; admins can **Refresh** to re-sync the catalog with the provider.
