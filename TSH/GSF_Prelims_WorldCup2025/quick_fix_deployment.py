#!/usr/bin/env python3
"""
Quick Fix: Deploy GSF Tournament Files to scrabble.ebrimasaye.com/tournament
"""

import subprocess
import os
from pathlib import Path


def quick_deploy():
    """Quick deployment to fix the backup URL"""

    print(
        "🚀 QUICK FIX: Deploying tournament files to scrabble.ebrimasaye.com/tournament"
    )
    print("=" * 70)

    # Check if HTML files exist
    html_dir = "/home/ebrimasaye/TSH/GSF_Prelims_WorldCup2025/html"
    if not os.path.exists(html_dir):
        print(f"❌ HTML directory not found: {html_dir}")
        return False

    # List available files
    html_files = list(Path(html_dir).glob("*.html"))
    print(f"📁 Found {len(html_files)} HTML files to deploy:")
    for file in html_files:
        print(f"   • {file.name}")

    # Try rsync deployment
    try:
        print("\n🔄 Attempting rsync deployment...")

        rsync_command = [
            "rsync",
            "-avz",
            "--delete",
            f"{html_dir}/",
            "ebrimasaye@scrabble.ebrimasaye.com:htdocs/tournament/",
        ]

        print(f"Running: {' '.join(rsync_command)}")

        subprocess.run(
            rsync_command, capture_output=True, text=True, timeout=30
        )

        if result.returncode == 0:
            print("✅ Rsync deployment successful!")
            print(result.stdout)
            return True
        else:
            print(f"❌ Rsync failed: {result.stderr}")
            print("Trying alternative methods...")

    except subprocess.TimeoutExpired:
        print("⏱️ Rsync timed out - trying alternative methods...")
    except Exception as e:
        print(f"❌ Rsync error: {e}")

    # Try SCP as alternative
    try:
        print("\n🔄 Attempting SCP deployment...")

        # Create a tar file first
        tar_command = [
            "tar",
            "-czf",
            "/tmp/tournament_files.tar.gz",
            "-C",
            html_dir,
            ".",
        ]

        print("Creating archive...")
        subprocess.run(tar_command, capture_output=True, text=True)

        if result.returncode == 0:
            # Upload the tar file
            scp_command = [
                "scp",
                "/tmp/tournament_files.tar.gz",
                "ebrimasaye@scrabble.ebrimasaye.com:/",
            ]

            print("Uploading archive...")
            subprocess.run(
                scp_command, capture_output=True, text=True, timeout=30
            )

            if result.returncode == 0:
                print("✅ SCP upload successful!")
                print("📝 Next steps:")
                print(
                    "   1. SSH to your server: ssh ebrimasaye@scrabble.ebrimasaye.com"
                )
                print(
                    "   2. Extract files: cd htdocs && mkdir -p tournament && cd tournament"
                )
                print("   3. Extract archive: tar -xzf ~/tournament_files.tar.gz")
                print("   4. Clean up: rm ~/tournament_files.tar.gz")
                return True
            else:
                print(f"❌ SCP failed: {result.stderr}")

    except Exception as e:
        print(f"❌ SCP error: {e}")

    # Manual instructions as fallback
    print("\n📋 MANUAL DEPLOYMENT INSTRUCTIONS:")
    print("Since automatic deployment failed, here's how to fix it manually:")
    print()
    print("1. Download files from server:")
    print(f"   scp -r {html_dir}/* your-local-machine:/path/to/download/")
    print()
    print("2. Upload to web server via FTP/SFTP:")
    print("   - Connect to scrabble.ebrimasaye.com via FTP/SFTP")
    print("   - Navigate to htdocs/tournament/ directory")
    print("   - Upload all files from html/ directory")
    print()
    print("3. Alternative - use web hosting control panel:")
    print("   - Log into your hosting control panel")
    print("   - Use File Manager to upload files to htdocs/tournament/")
    print()
    print("4. Test the URL: https://scrabble.ebrimasaye.com/tournament")

    return False


def test_deployment():
    """Test if the deployment worked"""
    print("\n🧪 Testing deployment...")

    try:
        import urllib.request

        test_url = "https://scrabble.ebrimasaye.com/tournament"
        print(f"Testing: {test_url}")

        response = urllib.request.urlopen(test_url, timeout=10)

        if response.getcode() == 200:
            print("✅ Tournament website is now accessible!")
            print(f"🌐 Live at: {test_url}")
            return True
        else:
            print(f"❌ Still getting error code: {response.getcode()}")
            return False

    except Exception as e:
        print(f"❌ Test failed: {e}")
        return False


if __name__ == "__main__":
    success = quick_deploy()

    if success:
        # Wait a moment for propagation
        import time

        print("\n⏳ Waiting 5 seconds for propagation...")
        time.sleep(5)
        test_deployment()

    print("\n" + "=" * 70)
    print("🎯 NEXT STEPS:")
    print("1. Ensure tournament files are uploaded to htdocs/tournament/")
    print("2. Check file permissions (should be readable by web server)")
    print("3. Verify web server configuration allows access to /tournament")
    print("4. Test URL: https://scrabble.ebrimasaye.com/tournament")
