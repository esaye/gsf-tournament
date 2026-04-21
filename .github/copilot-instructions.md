# Copilot instructions for this repository

This file orients Copilot sessions to the repository layout, common commands, and project-specific conventions so suggestions and code completions remain relevant.

---

## Build / test / lint commands
- Frontend (webpack) — at repository root (package.json):
  - Build production bundle: `npm run build` or `yarn build`
  - Build development bundle: `npm run build:dev`
  - Local dev server: `npm run serve`
  - Watch mode: `npm run watch`
  - DB / Drizzle helpers (Netlify dev wrappers):
    - Generate: `npm run db:generate` (drizzle-kit)
    - Migrate: `npm run db:migrate` (runs via `netlify dev:exec`)
    - Studio: `npm run db:studio`

- Python packaging (Collins Word Study App): CI uses PyInstaller (see .github/workflows/build.yml). There is no root `test` or `lint` npm script detected.

- Tests: a `tests/` package exists but contains only an __init__.py. No automated test runner or `test` script detected in package.json or pyproject.toml.


## High-level architecture
- Mono-repo of small projects and scripts. Two primary surfaces:
  1. A webpack-based frontend project (root) that bundles a web app created with create-webpack-app. Uses HTML Webpack Plugin, Bootstrap and Vizzu. Drizzle (drizzle-kit / drizzle-orm) is present for DB migrations and tooling.
  2. A Python desktop application (Collins Word Study App) packaged with PyInstaller. CI builds platform-specific single-file executables and bundles required data files (see .github/workflows/build.yml).

- Many standalone scripts live at the repository root (Python utilities, small apps, data files). Treat subfolders as independent subprojects unless a top-level package.json/pyproject.toml indicates otherwise.

- CI:
  - .github/workflows/build.yml: builds cross-platform Python executables (PyInstaller), archives artifacts, and creates releases on tagged pushes.
  - .github/workflows/safety_scan.yml: example job that runs the Safety CLI (pyupio/safety-action) using an API key from secrets.

## Key conventions and patterns
- PyInstaller packaging:
  - `launcher.py` (or specified entry) is used as the packaging entry point in CI; data files are explicitly added with `--add-data`. When adding resources, update CI `--add-data` lines in `.github/workflows/build.yml`.
  - Artifact naming follows `Collins-Word-Study-App-<platform>` and is archived per-platform.

- Database/migrations:
  - Drizzle is used; commands are executed through Netlify dev wrappers (`netlify dev:exec drizzle-kit ...`). Use those npm scripts when running migrations or studio locally to match CI behavior.

- Multiple-language workspace:
  - Files for different runtimes (Python, Node) coexist at repo root. When making changes, scope modifications to the subproject you're targeting (e.g., modify package.json scripts only for the webpack app; update pyproject/setup.py for Python packages).

- CI triggers:
  - The build workflow is tag-triggered (`v*`) and via manual dispatch. Releasing binaries is tied to creating annotated tags.

## Existing AI / assistant configs
- There is a `.claude` directory and `.claude.json` state present in the home folder of the repository owner (not repository-level docs). No repo-level CLAUDE.md, AGENTS.md, .cursorrules, .windsurfrules, AIDER_* or .clinerules were found in the repository root. If you add project-scoped assistant rules, include them in the repo root so Copilot can incorporate them.

---

If you want Copilot to prefer a certain language or directory when suggesting code (for example, treat `launcher.py` as primary for packaging changes), add a short repo-level instruction file here or update this file accordingly.

Project preference: Python-first (as requested)
- Primary focus: Python packaging and the Collins Word Study App. Treat `launcher.py` and `collins_word_study_app.py` as the canonical entrypoints for packaging and release changes. CI builds use PyInstaller and explicitly adds data files; mirror CI `--add-data` flags when changing resources.
- Local Python build: activate the repo `venv` (or another virtualenv), install deps (`pip install -r requirements.txt`), then run PyInstaller as in CI:
  - Example: `pyinstaller --onefile --windowed --name "Collins-Word-Study-App" launcher.py` (add `--add-data` entries matching CI).
- Packaging / metadata: respect `pyproject.toml` and any existing setup scripts when modifying packaging or dependencies.
- Virtual environments: prefer `venv` activation before installs; avoid committing secrets to CI configs.
- Tests: repository currently lacks an automated Python test runner (tests/ is empty). When adding tests use pytest and add a `test` entry to either `package.json` (for JS) or project tooling in pyproject.toml.
- Scope edits: when suggesting changes, keep them scoped to the subproject (Python vs Node/webpack) unless an explicit cross-cutting change is required.

Smooth workflow (practical commands and checks)
- Recommended virtualenv and install (Python-first):
  - python -m venv .venv
  - source .venv/bin/activate  # macOS/Linux
  - .\\.venv\\Scripts\\activate  # Windows PowerShell/CMD (adjust as needed)
  - pip install --upgrade pip
  - if present: pip install -r requirements.txt
  - alternative (pyproject/pdm): use pdm or pip editable install when appropriate.

- Reproduce CI packaging locally (copy of .github/workflows/build.yml add-data list):
  pyinstaller --onefile --windowed --name "Collins-Word-Study-App" \
    --add-data "collins_word_study_app.py:." \
    --add-data "collins_scrabble_2024.txt:." \
    --add-data "collins_word_study.db:." \
    --add-data "enhanced_collins_word_study.db:." \
    launcher.py

- Run a single pytest test (when tests are added):
  - By path: pytest tests/test_file.py::test_name
  - By pattern: pytest -k "pattern"

- Node/webpack quick setup (if working on frontend parts):
  - npm install
  - npm run build (production)
  - npm run build:dev (development)
  - npm run serve (dev server)

- Releases and CI:
  - Create an annotated tag like v1.2.3 and push to trigger the build/release workflow in .github/workflows/build.yml.
  - When adding or removing files used by PyInstaller, update the `--add-data` lines in .github/workflows/build.yml to keep CI and local builds consistent.

- CI secrets and scanning:
  - Add SAFETY_API_KEY to repository secrets to enable the safety_scan workflow.

- Small housekeeping checks for every change that affects packaging or releases:
  - Ensure required data files are included in PyInstaller `--add-data` and in source control.
  - Update version/tag before creating a release tag.
  - Run a local packaging step on the target OS (or in a matching container) where possible to catch platform-specific issues early.


Developer helper scripts included: scripts/dev-setup.sh and scripts/dev-setup.ps1
- Purpose: create .venv, install Python deps, optionally run `npm install` and a local PyInstaller packaging step.
- Example usage (POSIX):
  - ./scripts/dev-setup.sh            # create .venv and install python deps
  - ./scripts/dev-setup.sh --node     # also runs npm install if package.json exists
  - ./scripts/dev-setup.sh --pack     # run local PyInstaller packaging (uses CI --add-data list)
- Example usage (PowerShell):
  - .\scripts\dev-setup.ps1         # create .venv and install python deps on Windows
  - .\scripts\dev-setup.ps1 -Node   # also runs npm install if package.json exists
  - .\scripts\dev-setup.ps1 -Pack   # run local PyInstaller packaging (uses CI --add-data list)

After running: activate the venv with `source .venv/bin/activate` (POSIX) or `. .\\.venv\\Scripts\\Activate.ps1` (PowerShell).

Copilot should prefer invoking these scripts when suggesting environment/setup steps for contributors.

TSH: automation and focused tests
- TSH includes automation helpers and a focused test suite:
  - `TSH/automate_workflow.py` — runs pairing generation, watches a results directory, processes CSVs with `update_scores.py`, and can run a deploy step.
  - `TSH/WORKFLOW.md` — documents the automated flow and CSV format.
  - `TSH/tests/test_database.py` — minimal pytest to validate DB init and basic operations. CI runs pytest targeting the TSH folder; prefer adding more unit tests there.

When making suggestions that touch tournament workflows, prefer using `automate_workflow.py` or the documented steps in `TSH/WORKFLOW.md` to ensure operational consistency.
