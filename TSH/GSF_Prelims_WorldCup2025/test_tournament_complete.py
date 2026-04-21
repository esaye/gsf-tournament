#!/usr/bin/env python3
"""
Complete Tournament System Test
Tests all components to verify the tournament is ready
"""

import requests
import sqlite3
import subprocess
import os


def test_tsh_server():
    """Test TSH server connectivity"""
    try:
        response = requests.get("http://localhost:8088", timeout=5)
        if response.status_code == 200:
            print("✅ TSH server running on port 8088")
            return True
        else:
            print(f"❌ TSH server error: {response.status_code}")
            return False
    except requests.exceptions.RequestException as e:
        print(f"❌ TSH server not accessible: {e}")
        return False


def test_database():
    """Test database connectivity and data"""
    try:
        db_path = "/home/ebrimasaye/TSH/tournaments.db"
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()

        # Check tournament
        cursor.execute("SELECT name, status FROM tournaments WHERE id = 7")
        tournament = cursor.fetchone()
        if tournament:
            print(f"✅ Tournament database: {tournament[0]} ({tournament[1]})")
        else:
            print("❌ Tournament not found in database")
            return False

        # Check players
        cursor.execute("SELECT COUNT(*) FROM players WHERE tournament_id = 7")
        player_count = cursor.fetchone()[0]
        print(f"✅ Players in database: {player_count}")

        conn.close()
        return True

    except Exception as e:
        print(f"❌ Database error: {e}")
        return False


def test_division_page():
    """Test division page accessibility"""
    try:
        response = requests.get("http://localhost:8088/division/a/", timeout=5)
        if response.status_code == 200:
            content = response.text
            players = [
                "Conteh",
                "Sock",
                "Suso",
                "Sambou",
                "Jah",
                "Nyass",
                "Coron",
                "Sowe",
            ]
            found_players = [p for p in players if p in content]
            if len(found_players) >= 6:  # At least 6 players should be visible
                print(
                    f"✅ Division A page accessible with {len(found_players)} players visible"
                )
                return True
            else:
                print(
                    f"⚠️ Division page accessible but only {len(found_players)} players visible"
                )
                return False
        else:
            print(f"❌ Division page error: {response.status_code}")
            return False
    except Exception as e:
        print(f"❌ Division page error: {e}")
        return False


def test_photo_files():
    """Test player photo files"""
    photo_dir = "/home/ebrimasaye/TSH/GSF_Prelims_WorldCup2025/html/pix/u"
    photo_index = "/home/ebrimasaye/TSH/lib/pix/photos.txt"

    # Check if photo directory exists
    if not os.path.exists(photo_dir):
        print("❌ Photo directory not found")
        return False

    # Check photo index file
    if os.path.exists(photo_index):
        print("✅ Photo index file exists")
    else:
        print("⚠️ Photo index file missing")
        return False

    # Count photo files
    photo_files = [
        f for f in os.listdir(photo_dir) if f.endswith(".jpg") or f.endswith(".gif")
    ]
    print(f"✅ Photo files available: {len(photo_files)}")

    return True


def test_pairing_generation():
    """Test pairing generation via tournament manager"""
    try:
        subprocess.run(
            ["python3", "tournament_manager.py", "pair"],
            capture_output=True,
            text=True,
            cwd="/home/ebrimasaye/TSH/GSF_Prelims_WorldCup2025",
        )

        if "Round 1 pairings generated successfully" in result.stdout:
            print("✅ Pairing generation working")
            # Count how many tables were generated
            table_count = result.stdout.count("Table ")
            print(f"✅ Generated {table_count} pairings")
            return True
        else:
            print("❌ Pairing generation failed")
            print(
                result.stdout[:200] + "..."
                if len(result.stdout) > 200
                else result.stdout
            )
            return False

    except Exception as e:
        print(f"❌ Pairing generation error: {e}")
        return False


def main():
    """Run complete system test"""
    print("🎯 COMPLETE TOURNAMENT SYSTEM TEST")
    print("=" * 60)

    tests = [
        ("TSH Server", test_tsh_server),
        ("Database", test_database),
        ("Division Page", test_division_page),
        ("Photo Files", test_photo_files),
        ("Pairing Generation", test_pairing_generation),
    ]

    results = []
    for test_name, test_func in tests:
        print(f"\n📋 Testing {test_name}...")
        try:
            result = test_func()
            results.append((test_name, result))
        except Exception as e:
            print(f"❌ {test_name} test crashed: {e}")
            results.append((test_name, False))

    # Summary
    print("\n" + "=" * 60)
    print("📊 TEST SUMMARY")
    print("=" * 60)

    passed = 0
    total = len(results)

    for test_name, result in results:
        status = "✅ PASS" if result else "❌ FAIL"
        print(f"{test_name:20} {status}")
        if result:
            passed += 1

    print(f"\nResult: {passed}/{total} tests passed")

    if passed == total:
        print("\n🎉 ALL SYSTEMS GO! Tournament is ready for this weekend!")
        print("\n🚀 Ready to use:")
        print("   • Web Interface: http://localhost:8088")
        print("   • Generate pairings: python3 tournament_manager.py pair")
        print("   • Check status: python3 tournament_manager.py status")
        print("   • Full dry run: python3 tournament_manager.py dryrun")
    else:
        print(f"\n⚠️  {total - passed} issues found. Check the failing tests above.")

    return passed == total


if __name__ == "__main__":
    exit(0 if main() else 1)
