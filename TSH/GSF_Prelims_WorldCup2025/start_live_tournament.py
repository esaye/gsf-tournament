#!/usr/bin/env python3
"""
GSF Prelims Live Tournament Server
A standalone web server for the weekend tournament
"""

import http.server
import socketserver
import os
import webbrowser
import threading
import time


class TournamentHandler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/" or self.path == "/index.html":
            self.path = "/live_tournament.html"

        return http.server.SimpleHTTPRequestHandler.do_GET(self)


def start_server():
    """Start the tournament web server"""
    PORT = 8090
    tournament_dir = "/home/ebrimasaye/TSH/GSF_Prelims_WorldCup2025"

    os.chdir(tournament_dir)

    with socketserver.TCPServer(("", PORT), TournamentHandler) as httpd:
        print("🇬🇲 GSF NATIONAL PRELIMINARY TOURNAMENT - LIVE SERVER")
        print("=" * 60)
        print(f"🌐 Tournament is now LIVE at: http://localhost:{PORT}")
        print(f"📱 Mobile accessible at: http://[your-ip]:{PORT}")
        print("🏆 World Scrabble Championship 2025 Qualifier")
        print("=" * 60)
        print()
        print("📋 SERVER FEATURES:")
        print("   ✅ Live tournament interface")
        print("   ✅ Score entry system")
        print("   ✅ Real-time standings")
        print("   ✅ Round management")
        print("   ✅ Results export")
        print("   ✅ Mobile responsive")
        print()
        print("🎯 TOURNAMENT DIRECTOR INSTRUCTIONS:")
        print("   1. Open browser to the URL above")
        print("   2. Use 'Generate Next Round' to advance rounds")
        print("   3. Enter scores as games complete")
        print("   4. Export results after each round")
        print()
        print(
            "⚠️  Note: This runs independently from your league at scrabble.ebrimasaye.com"
        )
        print("🔄 Press Ctrl+C to stop the server")
        print()

        # Try to open browser automatically
        def open_browser():
            time.sleep(2)
            try:
                webbrowser.open(f"http://localhost:{PORT}")
                print("🚀 Browser opened automatically!")
            except:
                print("📝 Please manually open your browser to the URL above")

        browser_thread = threading.Thread(target=open_browser)
        browser_thread.daemon = True
        browser_thread.start()

        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\n\n🏁 Tournament server stopped!")
            print("📊 Thank you for using the GSF Tournament System")
            print("🇬🇲 Good luck to all players!")


if __name__ == "__main__":
    start_server()
