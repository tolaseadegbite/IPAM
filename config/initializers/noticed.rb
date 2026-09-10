# Run notification deliveries on the app's base job so queue and
# retry behavior stay consistent with every other background job.
Noticed.parent_class = "ApplicationJob"
