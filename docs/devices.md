# Devices

Devices are your inventoried assets: servers, laptops, printers, routers, and more. Each device lives in a department, optionally has an owner, and can hold one or more IP addresses.

## Registering a device

Devices → New. Required fields are name, type, and department. Useful extras:

- **Type**: desktop, all-in-one, laptop, printer, server, tablet, biometrics machine, or router.
- **Status**: `active`, `in_storage`, `in_repair`, `retired`, `lost`. Use the inline status changer on the list for quick flips.
- **Critical**: flags the device for the dashboard watchlist and degraded-status math. Reserve for infrastructure that matters.
- **MAC address**: normalized automatically (lowercase, colon-separated) and must be unique. Leave blank if unknown — the scanner will adopt the discovered MAC later.
- **IP addresses**: linking IPs to a new device marks them active. A device cannot be retired while it still holds IPs — release them first.

## Editing and retiring

- Editing a device lets you swap its IPs: released ones go back to `available`, newly linked ones become `active`, without flooding the audit log.
- **Deleting a device requires an admin** and frees its IPs back to the pool.
- An owner who leaves? Deleting the employee unassigns their devices; the devices themselves are untouched.

## Device pages

Show linked IPs with reachability, related task cards, and the audit trail. From here you can also open an investigation task pre-linked to the device.
