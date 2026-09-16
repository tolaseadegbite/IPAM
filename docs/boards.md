# Boards & Tasks

Boards are kanban workspaces for network operations: lists (columns) of task cards. A new board starts with **To Do**, **In Progress**, and **Done**.

## Lists

Add, rename, delete, and reorder columns. Cards live in exactly one list with a position — drag cards between lists or use the move action.

## Cards

A card has a title, description/notes, priority (`low`, `medium`, `high`), assignees, and an optional link to **one device or IP address**. Creating a card from a device, IP, or attention-queue row pre-links it (`Issue with X`).

- **Assignments**: add users to a card so ownership is visible.
- **Reference lookup**: when linking, search assets by name or address (capped result list).
- **Activity**: every meaningful change (create, move, priority, edits) is logged on a timeline; pure position shuffles stay quiet.

## Network Triage board

Severe scanner findings auto-file cards here: security/outage events become high priority, drift becomes medium, and duplicates are suppressed while a card is still open (finished `Done` cards don't block re-filing). This is also where admins get notified from.

## Tips

- Your high-priority open `To Do` items surface on the dashboard attention queue.
- Delete lists and cards freely — history for the linked asset keeps the audit trail.
