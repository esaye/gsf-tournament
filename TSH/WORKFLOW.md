TSH Automated Workflow

Overview

This document describes the automated workflow for running a tournament round: generate pairings, collect results, update scores, and publish live updates.

Files
- generate_next_round.py — generates pairings and inserts games into tournaments.db
- update_scores.py — reads CSV result files and updates the database
- automate_workflow.py — helper that runs the two above and watches a results directory

Quick automated flow

1. Ensure participants are registered in the tournament (players table).
2. Generate pairings:
   - Run: python3 generate_next_round.py
   - This writes pairings to the DB and creates a round_N_pairings.md file.
3. Collect results from players (CSV format expected by update_scores.py). Place CSVs into TSH/results/.
4. Run: python3 automate_workflow.py --watch-dir results --timeout 3600
   - This will process any existing CSVs and watch the directory for up to an hour.
   - Processed CSVs are moved to TSH/processed_results/.
5. Optionally deploy live updates to the website by adding --deploy. The script will try deploy_tournament_online.py then deploy_to_web.sh.

CSV format notes

- update_scores.py expects a CSV with columns: Player1, Player2, Score1, Score2
- Filenames should be unique per round (e.g., round3_results_01.csv)

Recommendations

- Use the provided dev-setup scripts to create a consistent venv and install dependencies before running automation.
- Validate CSVs locally by running update_scores.py on a copy first.
- Keep the generate_next_round.py TOURNAMENT_ID and update_scores.py TOURNAMENT_ID in sync for multi-tournament setups.

Example

./automate_workflow.py --watch-dir results --timeout 1800 --deploy

This will run pairings generation then watch results for 30 minutes; processed files will be deployed after processing.
