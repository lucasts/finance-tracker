# INSTRUCTIONS FOR DEVELOPERS

applyTo: '\*\*'

---

# ENVIRONMENT DETAILS

* **Operating System**: Linux (preferred for dev and prod); code must also run on MacOS/Windows (WSL) if possible.
* **Editor**: Visual Studio Code.
* **Terminal**: VSCode Integrated Terminal (bash/zsh).
* **Browser**: Chrome and Firefox for manual UI tests.
* **Database**: SQLite for development/testing, PostgreSQL for production.

---

# STACK & FRAMEWORKS

* **Backend**: Ruby on Rails 8.x+ (English for all code).
* **Frontend**: ERB views, Tailwind CSS 4, DaisyUI (as the component standard), Stimulus.js for JS interactivity.
* **Frontend**: Yarn to install JS packages.
* **Testing**: RSpec (preferred); always write or update tests when adding or changing features.
* **Jobs/Background Tasks**: Prefer to use Rails ActiveJob depending on context.
* **Authentication**: Devise for user management and security.

---

# BRANDING & UI

* **App Name**: Orzeny.
* **Identity**: Minimalist, modern, clear. Follow Orzeny brand palette:

  * Dark aqua green `#3A6B65`
  * Gold `#F4C542`
  * Cream `#FFFBF4`
* **Typography**: Use Inter as main font (via Tailwind variable/class).
* **UI Labels/Copy**: Always use Brazilian Portuguese for all visible interface text.
* **UI Components**: Always prefer DaisyUI components; use Tailwind only when DaisyUI does not cover a need.
* **Dashboard**: Should be clear, informative, and actionable; show both “cash” and “accrual” (competence) views where possible.

---

# ARCHITECTURE & BEST PRACTICES

* **MVC**: Always use idiomatic Rails conventions.
* **Service Objects**: For business logic outside models/controllers.
* **Background Jobs**: All automations (recurring transactions, installments, imports, etc.) must be via jobs, never in controller actions.
* **Partial Views**: Reuse via partials wherever possible.
* **Double-entry**: Every transaction must have a from\_account and to\_account (no nulls).
* **User Isolation**: All queries and operations must be scoped to current\_user.
* **Data Structure**: All models, migrations, and associations in English.
* **Localization**: Only user-facing text is localized (pt-BR).
* **Validation**: Strict model validations; never skip presence/association checks.

---

# DEVELOPMENT & CODE STYLE

* **Language**: All code, models, migrations, methods, and comments in English.
* **Commits**: Every change should be accompanied by a clear, conventional commit message in English.
* **Linting**: Run RuboCop and fix warnings before commit.
* **Factories**: Always use factory\_bot for test data in specs.
* **No placeholders**: Never return “TODO” or incomplete code; always implement or explain clearly why it cannot be implemented.
* **Interactive Logic**: All UI/UX dynamic features should use Stimulus.js controllers.

---

# SECURITY & DATA

* **Authentication**: Required for all non-public endpoints/views.
* **Authorization**: Never allow users to access or mutate data that does not belong to them.
* **Sensitive Operations**: Ask for confirmation before destructive actions (e.g., deleting data).

---

# WORKFLOW & COLLABORATION

* **Ask first**: When in doubt about a requirement or architectural decision, ask for clarification before implementing.
* **Suggest improvements**: If you see an opportunity to simplify, optimize, or improve code, mention it in the output.

---

# TESTS & RELIABILITY

* **Write tests**: Always create or update specs (unit/integration) for new features, bugs, or refactors.
* **Edge cases**: Ensure coverage of business-critical and boundary scenarios (recurring, installments, multi-account transfers, etc.).
* **Fixtures/Seeds**: Maintain realistic seeds and fixtures for test and demo data.

---

# FINAL NOTES

* You are building a **personal finance assistant** – clarity, simplicity, and trust are more important than “feature bloat.”
* **Never** expose sensitive user data.
* When updating the UI, always use DaisyUI styles unless impossible.

