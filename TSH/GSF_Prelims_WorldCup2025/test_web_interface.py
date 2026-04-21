#!/usr/bin/env python3
"""
Test script for the TSH web interface
"""

import requests
import sys


def test_tsh_server():
    """Test connection to TSH server"""
    try:
        response = requests.get("http://localhost:8088", timeout=5)
        if response.status_code == 200:
            print("✅ TSH server is accessible at http://localhost:8088")
            print(f"Response length: {len(response.text)} bytes")
            return True
        else:
            print(f"❌ TSH server returned status code: {response.status_code}")
            return False
    except requests.exceptions.RequestException as e:
        print(f"❌ Cannot connect to TSH server: {e}")
        return False


def test_division_page():
    """Test division page access"""
    try:
        response = requests.get("http://localhost:8088/division/a/", timeout=5)
        if response.status_code == 200:
            print("✅ Division A page accessible")
            # Check if players are listed
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
            print(f"   Found players: {', '.join(found_players)}")
            return True
        else:
            print(f"❌ Division page returned status code: {response.status_code}")
            return False
    except requests.exceptions.RequestException as e:
        print(f"❌ Cannot access division page: {e}")
        return False


def test_pair_round():
    """Test pairing generation via web interface"""
    try:
        # Try to access pairing command
        response = requests.get("http://localhost:8088/command/pair/a/1", timeout=10)
        if response.status_code == 200:
            print("✅ Round 1 pairing command executed")
            return True
        else:
            print(f"⚠️ Pairing command returned status code: {response.status_code}")
            return False
    except requests.exceptions.RequestException as e:
        print(f"❌ Cannot execute pairing command: {e}")
        return False


def main():
    print("🌐 Testing TSH Web Interface")
    print("=" * 50)

    success = True

    # Test 1: Server connectivity
    if not test_tsh_server():
        success = False

    # Test 2: Division page
    if not test_division_page():
        success = False

    # Test 3: Pairing generation
    if not test_pair_round():
        success = False

    print("\n" + "=" * 50)
    if success:
        print("✅ All tests passed! Web interface is working.")
        print("\nNext steps:")
        print("1. Open browser to http://localhost:8088")
        print("2. Navigate to Division A")
        print("3. Generate first round pairings")
        print("4. Test score entry")
    else:
        print("⚠️ Some tests failed. Check the issues above.")

    return 0 if success else 1


if __name__ == "__main__":
    sys.exit(main())
