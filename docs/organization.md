# Branches, Departments & People

The organization hierarchy is **Branch → Department → Employee**. Devices belong to departments and can be assigned to employees.

## Branches

A branch is a physical site (name, location, contact phone). The branch page shows its whole tree: departments, employees per department, and devices per department.

- **Creating**: Branches → New. Name, location, contact phone.
- **Deleting**: blocked while the branch still has departments — move or delete them first. You'll get a plain-language error otherwise.

## Departments

Departments belong to exactly one branch, and names are unique within that branch.

- Creating a department from a branch page pre-selects the branch.
- Deleting is blocked while employees or devices reference the department.

## Employees

People records: first/last name, department, and status (`active`, `on_leave`, `terminated`). Only active employees appear in assignment dropdowns.

- An employee's page shows their department and assigned devices (with IP addresses).
- Deleting an employee **unassigns** their devices — the devices stay, just ownerless. Nothing is cascade-deleted.

## Tips

- Use the per-page search and filters to narrow long lists.
- Department dropdowns elsewhere in the app (devices, employees) filter by the selected branch automatically.
