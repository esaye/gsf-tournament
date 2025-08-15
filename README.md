# gsf-tournament

Gambia Scrabble Federation

# 🚀 Welcome to your new awesome project!

This project has been created using **create-webpack-app**, you can now run

```bash
npm run build
```

or

```bash
yarn build
```

to bundle your application

# collins-word-study-app

[![Dev setup checks](https://github.com/esaye/gsf-tournament/actions/workflows/dev-setup-checks.yml/badge.svg)](https://github.com/esaye/gsf-tournament/actions/workflows/dev-setup-checks.yml)
[![Build releases](https://github.com/esaye/gsf-tournament/actions/workflows/build.yml/badge.svg)](https://github.com/esaye/gsf-tournament/actions/workflows/build.yml)

## Developer setup (quick)
- POSIX (Linux/macOS): ./scripts/dev-setup.sh --node
- Windows (PowerShell): .\scripts\dev-setup.ps1 -Node

See DEVELOPER_SETUP.md and .github/copilot-instructions.md for full setup, packaging, and CI guidance.

## Quick troubleshooting
- PyInstaller missing files: ensure the files listed in the CI `--add-data` flags exist at the repo root (`collins_word_study_app.py`, `collins_scrabble_2024.txt`, `collins_word_study.db`, `enhanced_collins_word_study.db`, `launcher.py`).
- CI failures on frontend: run `npm ci` locally and verify `npm run build:dev` passes before pushing.
- If the dev-setup script fails on CI due to network or registry issues, re-run the job (transient failures are common when installing packages).
