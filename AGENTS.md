# AGENTS.md

## Project Overview

- **Rails 8.1.1** (Ruby 3.4.5) — Mainline network inventory (branches, devices, subnets, IPs, ops boards)
- **Database:** PostgreSQL (primary) + SQLite3 (SolidQueue/SolidCache/SolidCable in dev)
- **Frontend:** Hotwire (Turbo + Stimulus), Importmap-rails, Tailwind CSS v4 (via tailwindcss-rails, class-based dark mode), Propshaft
- **Auth:** Session-based via signed cookies (authentication-zero gem), `Current` object pattern
- **Search/Pagination:** Ransack + Pagy
- **Auditing:** PaperTrail
- **Full-text search:** PgSearch (`multisearchable`)
- **No package.json** — JS dependencies are vendored in `vendor/` and pinned via `config/importmap.rb`

## Build / Lint / Test Commands

```bash
# Setup (first time or after pulling)
bin/setup

# Run full CI pipeline locally
bin/ci

# Start dev server (web + jobs + worker via Foreman/overmind)
bin/dev

# Lint Ruby
bin/rubocop

# Security audits
bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error
bin/bundler-audit
bin/importmap audit

# Run all tests
bin/rails test

# Run system tests (Selenium + headless Chrome)
bin/rails test:system

# Run a single test file
bin/rails test test/models/subnet_test.rb

# Run a single test method (by line number)
bin/rails test test/models/subnet_test.rb:15

# Run a specific test by name
bin/rails test test/models/subnet_test.rb -n test_should_be_valid

# Run a controller test
bin/rails test test/controllers/devices_controller_test.rb

# Run test with seed re-plant
RAILS_ENV=test bin/rails db:seed:replant
```

## Testing Conventions

- **Framework:** Minitest (not RSpec) with `ActiveSupport::TestCase` for models, `ActionDispatch::IntegrationTest` for controllers, `ActionDispatch::SystemTestCase` for system tests
- **Fixtures:** `fixtures :all` in test_helper.rb; reference fixtures with `users(:lazaro_nixon)`
- **Authentication helper** in test_helper.rb: `sign_in_as(user)` posts to sign_in_url and returns the user
- **Test naming:** `test "should <description>"` style; use `should` / `should not` phrasing
- **Assertions:** `assert_response :success`, `assert_redirected_to`, `assert_equal expected, actual`, `assert_difference "Model.count"`, `assert_enqueued_email_with`, `assert_no_enqueued_emails`
- **URL helpers:** Use `_url` (not `_path`) in tests consistently
- **Time travel:** `travel 3.days`, `travel 30.minutes` for time-sensitive tests
- **Setup:** `setup do ... end` block at top of class (not `before`)
- Tests run in parallel with `parallelize(workers: :number_of_processors)`
- System tests use Selenium with headless Chrome, screen size `[1400, 1400]`

## Code Style

### Ruby / Rails

- **Linter:** RuboCop via `rubocop-rails-omakase` (Rails omakase style). Config at `.rubocop.yml`.
- **Indentation:** 2 spaces. Private methods indented +2 spaces after `private` keyword.
- **Quoting:** Double quotes preferred (Rails convention). Single quotes for symbols/keys.
- **Trailing commas:** Not used.
- **Method visibility:** `private` separates public API from internal/callback methods.

### Models

- Inherit from `ApplicationRecord` (declares `primary_abstract_class`)
- **Associations:** Always declare explicit `dependent:` option. Use `optional: true` for nullable `belongs_to` relationships.
- **Validations:** Inline `validates` for simple rules; custom `validate :method_name` for complex logic. Validate methods use guard clause early returns, then `errors.add(:field, "message")`.
- **Enums:** Rails 7+ hash syntax: `enum :name, { key: int_value, ... }`. Values in snake_case.
- **Ransack:** Expose `self.ransackable_attributes(auth_object = nil)` returning `%w[ ... ]` and `self.ransackable_associations(auth_object = nil)` returning `%w[ ... ]`.
- **Callbacks:** Symbol references (`before_save :normalize_foo`). After-update callbacks use `if:` with `*_previously_changed?` for conditional execution.
- **Normalization:** Rails 7.1+ `normalizes :field, with: -> { _1.strip.downcase }`.
- **Performance:** Use `insert_all` for bulk inserts, `update_all` / `update_columns` to skip callbacks when appropriate. Eager-load associations in controllers.
- **Delegation:** `delegate :method, to: :association` (without prefix unless needed: `prefix: true`).

### Controllers

- Inherit from `ApplicationController`.
- **Method order:** `before_action` declarations → public CRUD actions (index, show, new, edit, create, update, destroy) → custom actions → `private` → `set_<resource>` → `<resource>_params`.
- **Auth:** `before_action :authenticate`; `require_admin`, `require_sudo` as additional guards. Redirect with flash alert on failure: `redirect_to root_path, alert: "message."`
- **Search/pagination:** `records = Model.order(:field)` → `@search = records.ransack(params[:q])` → `@pagy, @records = pagy(@search.result)`.
- **ETag loading:** Always use `.includes(...)` in index/show to avoid N+1 queries.
- **Response:** `respond_to` with `format.html` and `format.turbo_stream`. Success: redirect/render with `notice:`. Failure: `render :action, status: :unprocessable_entity`. Flash messages end with a period.
- **Turbo Streams:** Prepend (create), replace (update), remove (destroy). Use `helpers.dom_id(@record, :suffix)` for DOM targeting. Always update `shared/flash` partial.
- **Strong params:** `params.require(:model).permit(:field1, :field2, array_ids: [])`.

### Views

- **Partials:** `_<model>.html.erb`, `_<model>_card.html.erb`, `shared/_flash.html.erb`
- **Layout:** Single `application.html.erb` with conditional branching (`is_auth_page`, `is_dashboard_view`, `is_public_page`) rather than separate layout files.
- **Hotwire:** `turbo_frame_tag` for modals, Stimulus `data-controller` and `data-action` attributes on elements.
- **CSS:** Tailwind CSS v4 utilities + component classes defined in `app/assets/stylesheets/application.tailwind.css` (`.btn`, `.input`, `.card`, `.badge`, `.table`, `.dialog`, `.sheet`, `.popover`, `.menu`, `.flash`, `.switch`, `.accordion`, `.message`, `.sidebar-link`). Icons via `icon(name, classes)` helper backed by `shared/_icon_sprite`.
- **Dark mode:** class-based (`.dark` on `<html>`, default dark). Every color utility needs its `dark:` variant. Sidebar stays dark always. Accent is orange-500, used sparingly for primary actions/links only — no purple, no gradients.
- **Responsive:** mobile-first; tables get a `hidden md:block` wrapper + `md:hidden` card list; grids collapse to 1 col; FABs (`fixed bottom-24 md:hidden`) for primary create actions; bottom tab bar for mobile nav.

### JavaScript (Stimulus)

- Files in `app/javascript/controllers/<name>_controller.js`.
- Auto-discovered via `eagerLoadControllersFrom("controllers", application)`.
- `export default class extends Controller { ... }` (anonymous class).
- **Targets:** `static targets = ["name"]`; referenced as `this.nameTarget`.
- **Values:** `static values = { name: { type: String, default: "..." } }`.
- **Private methods:** Use native JS private fields (`#methodName`, `#property`, `get #property()`).
- **Constants:** Module-level `ALL_CAPS` for configuration values.
- **External libs:** `@rails/request.js` loaded from ESM.sh CDN for Fetch API.
- **Lifecycle:** `connect()` and `disconnect()` hooks.

### Migrations

- Use `bin/rails generate migration` for new migrations.
- Schema version managed via `db/schema.rb` (not `structure.sql`).

## Key Architectural Patterns

- **Services:** Service objects live in `app/services/` (e.g., `NetworkReconService`). Eager-loaded via `config.eager_load_paths`.
- **Concerns:** Not currently in use (directories are empty — add concerns there if extracting shared logic).
- **Current object:** Request-scoped state stored on `Current` (session, user, ip_address, user_agent).
- **Background jobs:** SolidQueue with recurring schedule defined in `config/recurring.yml`. Job classes in `app/jobs/`.
- **Mission Control:** Job dashboard available at `/jobs` for admin users.

## Environment Variables / Credentials

- Secrets via `config/credentials.yml.enc` + `config/master.key` (git-ignored).
- Kamal deployment secrets in `.kamal/secrets`.

## Git / CI

- GitHub Actions in `.github/workflows/ci.yml`: scan_ruby, scan_js, lint, test, system-test.
- Dependabot configured for weekly bundler + github-actions updates.

## Common Pitfalls

- Do NOT introduce `package.json` or Node.js-based build tools — the project uses Importmap for JavaScript.
- Do NOT `cd` in shell commands — use the `workdir` parameter instead.
- Avoid `update_columns` unless you specifically need to skip callbacks and validations.
- Use `.to_sentence` for rendering ActiveRecord error messages to users.
- IP address CIDR columns use PostgreSQL `INET` type with `&&` overlap operator for subnet validation.
