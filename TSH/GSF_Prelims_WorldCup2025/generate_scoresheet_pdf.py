#!/usr/bin/env python3
"""
GSF Preliminaries Scoresheet PDF Generator
Converts the HTML scoresheet to PDF for printing
"""

import subprocess
from pathlib import Path


def generate_scoresheet_pdf():
    """Generate PDF scoresheet from HTML"""
    current_dir = Path(__file__).parent
    html_file = current_dir / "scoresheet_gsf_prelims.html"
    pdf_file = current_dir / "GSF_Preliminaries_Scoresheet.pdf"

    if not html_file.exists():
        print(f"❌ HTML file not found: {html_file}")
        return False

    print("🏆 Generating GSF Preliminaries Scoresheet PDF...")

    # Try different methods to generate PDF
    methods = [
        # Method 1: wkhtmltopdf (best quality)
        [
            "wkhtmltopdf",
            "--page-size",
            "A4",
            "--margin-top",
            "0.5in",
            "--margin-bottom",
            "0.5in",
            "--margin-left",
            "0.5in",
            "--margin-right",
            "0.5in",
            "--print-media-type",
            str(html_file),
            str(pdf_file),
        ],
        # Method 2: chromium headless
        [
            "chromium-browser",
            "--headless",
            "--disable-gpu",
            "--print-to-pdf=" + str(pdf_file),
            "--print-to-pdf-no-header",
            str(html_file),
        ],
        # Method 3: chrome headless
        [
            "google-chrome",
            "--headless",
            "--disable-gpu",
            "--print-to-pdf=" + str(pdf_file),
            "--print-to-pdf-no-header",
            str(html_file),
        ],
    ]

    for method in methods:
        try:
            print(f"📄 Trying: {method[0]}...")
            result = subprocess.run(method, capture_output=True, text=True, timeout=30)

            if result.returncode == 0 and pdf_file.exists():
                print(f"✅ PDF generated successfully: {pdf_file}")
                print(f"📊 File size: {pdf_file.stat().st_size / 1024:.1f} KB")
                return True
            else:
                print(f"❌ {method[0]} failed: {result.stderr}")

        except (subprocess.TimeoutExpired, FileNotFoundError) as e:
            print(f"❌ {method[0]} not available or failed: {e}")
            continue

    # Fallback: Open HTML in browser for manual printing
    print("\n🌐 Alternative: Open HTML in browser for manual printing")
    print(f"📂 File: {html_file.absolute()}")
    print("💡 Instructions:")
    print("   1. Open the HTML file in your browser")
    print("   2. Press Ctrl+P (or Cmd+P on Mac)")
    print("   3. Choose 'Save as PDF' as destination")
    print("   4. Set margins to 0.5 inches")
    print("   5. Save as 'GSF_Preliminaries_Scoresheet.pdf'")

    return False


def print_usage_instructions():
    """Print instructions for using the scoresheet"""
    print("\n" + "=" * 60)
    print("🏆 GSF PRELIMINARIES SCORESHEET - USAGE INSTRUCTIONS")
    print("=" * 60)
    print("📋 BEFORE EACH GAME:")
    print("   • Fill in Date, Round, Game number, Table number")
    print("   • Enter player names, ratings, and IDs")
    print("   • Record start time")
    print()
    print("⏱️  DURING THE GAME:")
    print("   • Note the first player")
    print("   • Track challenges (W/L format)")
    print("   • Count bingos for each player")
    print("   • Record high word scores")
    print()
    print("🏁 AFTER THE GAME:")
    print("   • Enter final scores")
    print("   • Record end time and duration")
    print("   • Note any overtime penalties")
    print("   • Get signatures from both players and TD")
    print()
    print("📝 TIPS:")
    print("   • Print multiple copies before the tournament")
    print("   • Use ballpoint pen for clear signatures")
    print("   • Keep completed sheets for tournament records")
    print("   • Scan/photo completed sheets for backup")
    print()
    print("🎯 TOURNAMENT INFO:")
    print("   • Event: GSF Preliminaries for World Championships 2025")
    print("   • Format: Round Robin (8 players, 15 rounds)")
    print("   • Official GSF tournament documentation")
    print("=" * 60)


if __name__ == "__main__":
    success = generate_scoresheet_pdf()
    print_usage_instructions()

    if success:
        print("\n✅ Ready to print! PDF generated successfully.")
    else:
        print("\n📱 Use browser method to create PDF for printing.")
