# FAQ & Troubleshooting

## I can't sign in

Check the username spelling — a failed attempt echoes the username back as a hint. Passwords are case-sensitive. Still stuck? Use **Forgot your password?** (verified addresses only) or ask an admin to reset it.

## Other systems get "Forbidden" on the LAN

The dev server allowlists hosts. The app permits localhost plus the configured local subnets — if a device on a new subnet gets 403, its range needs adding to the host allowlist in `config/environments/development.rb`, plus a server restart. The machine firewall must also allow the app port (`sudo ufw allow 3001/tcp` when ufw is on).

## Scans show stale data

`last scan (stale)` means no sweep completed in 24 hours. Checklist:

1. Is the job worker running? Check `/jobs` — the recurring scan should fire every few minutes.
2. Is `nmap` installed with passwordless sudo on the app server? Without it, sweeps skip loudly and reachability freezes (the app never guesses from an empty sweep).
3. Are the subnets actually reachable from the server (same L2 for ARP discovery)?

## A rogue device I know is fine

Register it: open the IP, attach the real device (create the device first if needed). If the scanner keeps flagging it, confirm the MAC matches — a MAC mismatch on an assigned IP is a takeover alert, not a glitch.

## I reclaimed something by mistake

Re-assign the IP to its device from the IP or device page. Status flips back to active; the audit trail records both moves.

## Charts look empty

Short trend ranges (1H/24H) are usually flat — events only fire on state changes. Flat zeros on a stable network mean quiet, not broken. The 14D view should still show history.

## Glossary

- **Rogue**: reachable IP with no device record. Unknown hardware — investigate.
- **Ghost**: assigned IP unseen 30+ days. Usually safe to reclaim.
- **Drift**: known device on an unexpected IP.
- **Takeover**: unknown MAC on an assigned IP. Treat as hostile until proven otherwise.
- **Reclaim**: release device + free the address in one click.
- **Triage**: auto-filed cards (and admin alerts) from severe scanner findings.
- **Reachability vs status**: observed (up/down) vs administrative (available/active/reserved/blacklisted).
- **NOC**: network operations center — you, reading this.
