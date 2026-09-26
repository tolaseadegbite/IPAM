# NAT Assistant

NAT is the AI network assistant: ask questions in plain English, and it reads live inventory, runs lookups, and makes careful changes — explaining as it goes.

## Starting a chat

NAT Assistant → New chat. Pick a model first (the default is pre-selected), then type. Chats stream live, keep full history, support attachments, and can be deleted any time. The list paginates with infinite scroll.

Useful prompts:

- `How many rogue devices are on the network right now?`
- `Find me 5 free IPs on the Staff subnet`
- `What changed on srv-dc-02 in the last week?`
- `Register the laptop with MAC 02:00:00:00:00:0A for Adaeze in IT`

## Plan and Build modes

Every chat opens in **Plan mode**: NAT investigates with read-only tools, presents a numbered plan, and asks for approval — it cannot change anything, by construction. Flip to **Build** (header toggle) to let it execute; flip back anytime. The mode sticks per chat, including across reloads. Rule of thumb: stay in Plan until the plan looks right, then build. You can also pick the starting mode right on the new-chat form.

## Attachments

Attach images (e.g. photos of handwritten IP books — NAT reads them visually), CSV and Excel sheets, and PDFs. It will never guess ambiguous handwriting like `1` vs `7` — it asks you to confirm first.

## What NAT can do

- **Lookups**: IPs (filterable by status, reachability, subnet), subnets (with live reachability counts, not just allocation), devices (including by MAC), employees, branches, departments, free-IP hunts (truly free: unassigned, never-seen, unreserved), live-but-unregistered hosts, device IP history, network stats, recent activity, device breakdowns.
- **Changes**: assign/unassign IPs, create/update devices and employees, bulk-create devices from a list, delete devices (frees their IPs) or employees (only when deviceless), create/update subnets, trigger a live rescan of one subnet.
- **Knows the difference** between allocation (`status`: is the IP assigned?) and liveness (`reachability`: is it answering?) — and will never answer one question with the other's data.

## Safety rules it follows

- **Confirms before destructive acts**: unassigning and deleting always ask first.
- **Collects required fields first**: subnet creation asks for name, CIDR, gateway, VLAN-or-none, and branch-or-no-branch up front — never plans with pieces missing.
- **Refuses bad writes**: assigned or blacklisted IPs can't be double-assigned.
- **Refuses to guess people**: ambiguous names list the matches and ask instead of picking.
- **Minimal edits**: updates touch only the fields you asked about — and ask which fields when you don't say.
- **Bulk creates summarize first**: multi-device jobs show a plan, ask for confirmation, then report per-row success/failure.
- **Scans on request only**: it reports from last-scan data with freshness, and offers rescans as follow-ups rather than firing sweeps unprompted.
- **Auto-creates missing org records** when provisioning (branch/department/employee) rather than failing.

## Models

The Models page catalogs available chat models; admins can **Refresh** to re-sync the catalog with the provider.
