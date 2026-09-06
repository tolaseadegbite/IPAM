# Pagy initializer file (9.3.3)

# Pagy Variables
# See https://ddnexus.github.io/pagy/docs/api/pagy#variables
Pagy::DEFAULT[:limit] = 44

# Cap client-requested page sizes (limit extra) so ?limit= can't ask for the whole table.
Pagy::DEFAULT[:limit_max] = 100

# Limit extra: Allow the client to request a custom limit per page with an optional selector UI
# See https://ddnexus.github.io/pagy/docs/extras/limit
require "pagy/extras/limit"
require "pagy/extras/keyset"
