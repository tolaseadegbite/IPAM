# Primary seed file. Production seeds go here (uncommented, working code only).
#
# Demo dataset for UI previews lives in db/seeds/demo.rb and runs only with:
#   SEED_DEMO=1 bin/rails db:seed

load Rails.root.join("db/seeds/demo.rb") if ENV["SEED_DEMO"] == "1"
