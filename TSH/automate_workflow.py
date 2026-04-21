#!/usr/bin/env python3
"""TSH automation: generate pairings, watch for results CSVs, update scores, and optionally deploy.

Usage:
  python3 automate_workflow.py --once                 # run generate_next_round then process any CSVs found
  python3 automate_workflow.py --watch-dir results --timeout 3600  # watch for up to 1 hour for results
  python3 automate_workflow.py --deploy                # run deploy script after processing

Notes:
- Script runs from the TSH directory and invokes existing TSH scripts.
- It is intentionally conservative (doesn't assume specific CSV formats beyond update_scores.py expectations).
"""

import argparse
import subprocess
import time
import shutil
from pathlib import Path

HERE = Path(__file__).parent
DEFAULT_RESULTS_DIR = HERE / "results"
PROCESSED_DIR = HERE / "processed_results"


def run_cmd(cmd, cwd=HERE):
    print("[automate] Running:", " ".join(cmd))
    res = subprocess.run(cmd, cwd=cwd)
    return res.returncode


def ensure_dirs(results_dir):
    results_dir.mkdir(parents=True, exist_ok=True)
    PROCESSED_DIR.mkdir(parents=True, exist_ok=True)


def process_csv_file(path: Path, update_script: Path):
    print(f"[automate] Processing results file: {path}")
    rc = run_cmd(["python3", str(update_script), str(path.name)], cwd=path.parent)
    if rc == 0:
        dest = PROCESSED_DIR / path.name
        shutil.move(str(path), str(dest))
        print(f"[automate] Moved processed file to {dest}")
    else:
        print(f"[automate] update_scores script returned {rc} for {path}")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--watch-dir",
        default=str(DEFAULT_RESULTS_DIR),
        help="Directory to watch for result CSVs",
    )
    parser.add_argument(
        "--timeout",
        type=int,
        default=300,
        help="Seconds to wait for results (0 = no wait)",
    )
    parser.add_argument(
        "--poll-interval", type=int, default=15, help="Seconds between polls"
    )
    parser.add_argument(
        "--once",
        action="store_true",
        help="Run once (generate pairings + process any existing CSVs) and exit",
    )
    parser.add_argument(
        "--deploy",
        action="store_true",
        help="Run deploy script (deploy_tournament_online.py or deploy_to_web.sh) after processing",
    )

    args = parser.parse_args()

    results_dir = Path(args.watch_dir).resolve()
    ensure_dirs(results_dir)

    # Step 1: generate next round pairings
    gen_script = HERE / "generate_next_round.py"
    if gen_script.exists():
        print("[automate] Generating next round pairings...")
        rc = run_cmd(["python3", str(gen_script)])
        if rc != 0:
            print("[automate] Pairings generation failed (rc=", rc, ")")
    else:
        print(
            "[automate] generate_next_round.py not found; skipping pairings generation"
        )

    # Step 2: process any CSV files in results_dir
    update_script = HERE / "update_scores.py"
    if not update_script.exists():
        print("[automate] update_scores.py not found; cannot process results")
        return

    def scan_and_process():
        files = sorted(results_dir.glob("*.csv"))
        if not files:
            return 0
        for f in files:
            process_csv_file(f, update_script)
        return len(files)

    processed_count = scan_and_process()

    if args.once:
        print(f"[automate] Completed run: processed {processed_count} files")
        if args.deploy:
            deploy()
        return

    # Otherwise watch until timeout (if > 0)
    start = time.time()
    timeout = args.timeout
    print(f"[automate] Watching {results_dir} for CSVs (timeout={timeout}s)")
    while True:
        found = scan_and_process()
        if found > 0:
            print(f"[automate] Processed {found} files. Continuing to watch...")
        if timeout > 0 and (time.time() - start) > timeout:
            print("[automate] Timeout reached. Exiting watch loop.")
            break
        time.sleep(args.poll_interval)

    if args.deploy:
        deploy()


def deploy():
    # Simple deploy: prefer Python deploy script, fallback to shell script
    py_deploy = HERE / "deploy_tournament_online.py"
    sh_deploy = HERE / "deploy_to_web.sh"
    if py_deploy.exists():
        print("[automate] Running Python deploy script")
        run_cmd(["python3", str(py_deploy)])
    elif sh_deploy.exists():
        print("[automate] Running shell deploy script")
        run_cmd(["bash", str(sh_deploy)])
    else:
        print("[automate] No deploy script found; skipping deploy")


if __name__ == "__main__":
    main()
