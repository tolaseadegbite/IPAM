# Welcome to Mainline

Mainline is your network inventory and operations center: every branch, device, subnet, and IP address in one place, watched by automated scans and assisted by NAT, the built-in network assistant.

## Signing in

Open the app and sign in with your **username** and password. If your credentials are wrong you'll get a hint showing the username you tried — check for typos and try again. Locked out? Use the **Forgot your password?** link on the sign-in page.

## The layout in 2 minutes

- **Sidebar** (left): Dashboard, Operations (kanban boards), Inventory (Subnets, IP Addresses, Devices), Organization (Branches, Departments, Employees), Security shortcuts (Rogue Devices, Critical Devices), NAT Assistant, System (Users, History), and Docs (this guide). Your theme and account controls live at the bottom.
- **Header** (top): global search, the notifications bell, a light/dark toggle, and page-specific action buttons.
- **Dashboard** (home): network health at a glance — status, KPIs, event trends, subnet health, and the Needs Attention queue.
- **Mobile**: on small screens you get a bottom tab bar plus floating action buttons for creating records.

## Key concepts

- **Status vs reachability**: an IP's *status* (available, active, reserved, blacklisted) is its administrative state — what it's assigned for. Its *reachability* (unknown, up, down) is what the scanner last observed. They change independently.
- **Rogue device**: an IP that answers ping but has no inventory record. Unknown hardware on your network — investigate it.
- **Ghost asset**: an assigned IP that hasn't been seen in over 30 days. Usually safe to reclaim.
- **Drift**: a known device showing up on a different IP than recorded. Often DHCP or a move — sometimes hostile.
- **Scan**: every few minutes the scanner sweeps all inventoried subnets and updates reachability, raising events on anything interesting.

## Where to go next

- [Dashboard](/dashboard) — learn to read the NOC overview
- [IP Addresses](/ip_addresses) — rogue and ghost workflows
- [NAT Assistant](/chats) — ask questions in plain English
- [FAQ & Troubleshooting](/docs/faq) — stuck? start here
