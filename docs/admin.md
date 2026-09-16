# Administration

Admin-only areas. (Admins are flagged on the user record — ask an existing admin for elevation.)

## Users

System → Users: full CRUD plus search. Notes:

- Leave the password blank when editing to keep it unchanged.
- You cannot delete your own account.
- New users sign in with username + password like everyone else.

## History (audit log)

System → History is the global PaperTrail log, newest first, paginated. Filter by:

- Record type and ID (Branch, Department, Employee, Device, IP, Subnet, User)
- Event: create, update, destroy
- Username (partial match)
- Date range (from/to)

Every record page also carries its own recent audit trail, and cards keep an activity timeline. High-frequency scanner noise (reachability flips, last-seen timestamps) is deliberately excluded so the log stays readable; reachability history lives in network events instead. Old audit rows are pruned automatically (12-month retention).

## Background jobs

`/jobs` hosts the Mission Control dashboard: live queues, scheduled and recurring jobs (including the 5-minute network scan), retries, and failures. Use it to confirm the scheduler is alive and to inspect failed runs.

## Data retention

Finished jobs clear hourly; audit and card activity older than 12 months is pruned nightly. There is no self-service database export — coordinate backups at the infrastructure level.
