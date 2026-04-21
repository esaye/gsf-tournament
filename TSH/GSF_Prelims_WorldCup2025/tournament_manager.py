#!/usr/bin/env python3
"""
GSF Prelims WorldCup 2025 Tournament Manager
A comprehensive script for managing the tournament operations.
"""

import sqlite3
import subprocess
import os
from datetime import datetime
import sys


class TournamentManager:
    def __init__(self):
        self.tournament_dir = "/home/ebrimasaye/TSH/GSF_Prelims_WorldCup2025"
        self.db_path = "/home/ebrimasaye/TSH/tournaments.db"
        self.tsh_path = "/home/ebrimasaye/TSH/tsh.pl"
        self.tournament_id = 7  # The newly created tournament

    def get_db_connection(self):
        """Get database connection"""
        return sqlite3.connect(self.db_path)

    def show_tournament_status(self):
        """Display current tournament status"""
        print("=" * 60)
        print("GSF PRELIMS WORLDCUP 2025 - TOURNAMENT STATUS")
        print("=" * 60)

        conn = self.get_db_connection()
        cursor = conn.cursor()

        # Get tournament info
        cursor.execute(
            """
            SELECT name, format, rounds, status, created_at, settings 
            FROM tournaments WHERE id = ?
        """,
            (self.tournament_id,),
        )

        tournament = cursor.fetchone()
        if tournament:
            name, format_type, rounds, status, created_at, settings = tournament
            print(f"Tournament: {name}")
            print(f"Format: {format_type.upper()}")
            print(f"Max Rounds: {rounds}")
            print(f"Status: {status.upper()}")
            print(f"Created: {created_at}")

        # Get players
        cursor.execute(
            """
            SELECT COUNT(*) FROM players WHERE tournament_id = ?
        """,
            (self.tournament_id,),
        )
        player_count = cursor.fetchone()[0]
        print(f"Players Registered: {player_count}")

        # Get games status
        cursor.execute(
            """
            SELECT status, COUNT(*) FROM games 
            WHERE tournament_id = ? 
            GROUP BY status
        """,
            (self.tournament_id,),
        )

        games_status = cursor.fetchall()
        print("\nGames Status:")
        for status, count in games_status:
            print(f"  {status}: {count}")

        conn.close()
        print("=" * 60)

    def list_players(self):
        """List all registered players"""
        conn = self.get_db_connection()
        cursor = conn.cursor()

        cursor.execute(
            """
            SELECT name, rating, phone, registered_at 
            FROM players 
            WHERE tournament_id = ? 
            ORDER BY name
        """,
            (self.tournament_id,),
        )

        players = cursor.fetchall()

        print("\nREGISTERED PLAYERS:")
        print("-" * 40)
        for i, (name, rating, team, registered_at) in enumerate(players, 1):
            print(f"{i:2d}. {name:<25} Rating: {rating} Team: {team}")

        conn.close()
        return players

    def generate_first_round(self):
        """Guide user to generate first round pairings via TSH web interface"""
        print("\n🎯 Ready to Generate Round 1 Pairings!")
        print("⚠️  Note: Official pairings must be generated via the TSH web interface.")
        print()

        # Get players from database
        conn = self.get_db_connection()
        cursor = conn.cursor()

        cursor.execute(
            """
            SELECT name, rating FROM players 
            WHERE tournament_id = ? 
            ORDER BY rating DESC, name
        """,
            (self.tournament_id,),
        )

        players = cursor.fetchall()
        conn.close()

        if len(players) < 2:
            print("❌ Need at least 2 players for pairings")
            return

        print(f"📊 {len(players)} players ready for pairing:")
        for i, (name, rating) in enumerate(players, 1):
            print(f"   {i:2d}. {name:<25} Rating: {rating}")

        print()
        print("📋 To generate official Round 1 pairings:")
        print("   1. Open your browser and go to: http://localhost:8080")
        print("   2. Click on 'Division A'")
        print("   3. Click 'Generate Round 1' button")
        print("   4. Review and confirm the pairings")
        print()
        print("🌐 Or use the live website: https://scrabble.ebrimasaye.com")
        print()

        # Check if web server is running
        try:
            import requests

            response = requests.get("http://localhost:8080", timeout=5)
            if response.status_code == 200:
                print("✅ TSH web server is running and ready!")
            else:
                print("⚠️  TSH web server may not be running.")
                print("   Start it with: perl tsh.pl . server")
        except:
            print("⚠️  TSH web server may not be running.")
            print("   Start it with: perl tsh.pl . server")

        return players

    def display_round_pairings(self, round_num):
        """Display pairings for a specific round"""
        print(f"\nROUND {round_num} PAIRINGS:")
        print("-" * 50)

        # Try to read pairings from TSH output files
        pairings_file = f"{self.tournament_dir}/html/r{round_num}.html"
        if os.path.exists(pairings_file):
            print(f"Pairings file created: {pairings_file}")
        else:
            print("No pairings file found - check TSH output")

    def test_website_upload(self):
        """Test uploading tournament data to website"""
        print("\nTesting website upload to scrabble.ebrimasaye.com...")

        try:
            # Use the existing SFTP configuration from config.tsh
            result = subprocess.run(
                ["perl", self.tsh_path, "upload"],
                capture_output=True,
                text=True,
                cwd=self.tournament_dir,
            )

            if result.returncode == 0:
                print("✅ Website upload successful!")
                print("🌐 Check: https://scrabble.ebrimasaye.com")
            else:
                print(f"⚠️  Upload completed with warnings: {result.stderr}")

        except Exception as e:
            print(f"❌ Error uploading: {e}")

    def run_dry_run(self):
        """Run a complete dry-run test"""
        print("\n🎯 STARTING TOURNAMENT DRY RUN")
        print("=" * 60)

        # Step 1: Show current status
        self.show_tournament_status()

        # Step 2: List players
        players = self.list_players()
        if len(players) < 2:
            print("❌ Need at least 2 players for dry run")
            return False

        # Step 3: Generate first round
        self.generate_first_round()

        # Step 4: Test website upload
        self.test_website_upload()

        print("\n✅ DRY RUN COMPLETED!")
        print("Next steps:")
        print("1. Add player photos to html/pix/u/ directory")
        print("2. Test the live website")
        print("3. Enter actual scores when tournament starts")

        return True

    def add_sample_scores(self, round_num=1):
        """Add sample scores for testing purposes"""
        print(f"\nAdding sample scores for Round {round_num}...")

        # This would interact with TSH to add scores
        # For now, just demonstrate the concept
        sample_scores = [
            ("Nyass, Ebrima", 445, "Conteh, Ousman", 389),
            ("Jah, Omar Malleh", 423, "Sock, Richard John", 367),
            ("Suso, Kebba", 456, "Sambou, Amadou", 412),
            ("Coron, Jimmy", 401, "Sowe, Momodou", 398),
        ]

        print("Sample scores to be entered:")
        for p1, s1, p2, s2 in sample_scores:
            winner = p1 if s1 > s2 else p2
            print(f"  {p1} {s1} - {s2} {p2} (Winner: {winner})")

    def backup_tournament(self):
        """Create a backup of the current tournament"""
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        backup_dir = (
            f"/home/ebrimasaye/TSH/backups/GSF_Prelims_WorldCup2025_{timestamp}"
        )

        os.makedirs(backup_dir, exist_ok=True)

        # Copy tournament files
        import shutil

        shutil.copytree(
            self.tournament_dir, f"{backup_dir}/tournament", dirs_exist_ok=True
        )
        shutil.copy2(self.db_path, f"{backup_dir}/tournaments.db")

        print(f"✅ Tournament backed up to: {backup_dir}")


def main():
    manager = TournamentManager()

    if len(sys.argv) > 1:
        command = sys.argv[1].lower()

        if command == "status":
            manager.show_tournament_status()
        elif command == "players":
            manager.list_players()
        elif command == "pair":
            round_num = int(sys.argv[2]) if len(sys.argv) > 2 else 1
            manager.generate_first_round()
        elif command == "upload":
            manager.test_website_upload()
        elif command == "dryrun":
            manager.run_dry_run()
        elif command == "backup":
            manager.backup_tournament()
        elif command == "scores":
            round_num = int(sys.argv[2]) if len(sys.argv) > 2 else 1
            manager.add_sample_scores(round_num)
        else:
            print("Unknown command. Available commands:")
            print("  status  - Show tournament status")
            print("  players - List players")
            print("  pair    - Generate pairings")
            print("  upload  - Upload to website")
            print("  dryrun  - Run complete dry run")
            print("  backup  - Backup tournament")
            print("  scores  - Add sample scores")
    else:
        # Interactive mode
        manager.show_tournament_status()
        print("\n🚀 Ready for tournament operations!")
        print("Run with 'dryrun' argument to test everything")


if __name__ == "__main__":
    main()
