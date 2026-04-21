#!/usr/bin/env python3
"""
Display Tournament URLs for Sharing
Shows the exact URLs players can use to access the tournament
"""

import socket
import subprocess


def get_local_ip():
    """Get the local IP address"""
    try:
        # Try to get the IP used to reach the internet
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        local_ip = s.getsockname()[0]
        s.close()
        return local_ip
    except:
        try:
            # Fallback method
            hostname = socket.gethostname()
            local_ip = socket.gethostbyname(hostname)
            if local_ip.startswith("127."):
                # Try another method
                result = subprocess.run(
                    ["hostname", "-I"], capture_output=True, text=True
                )
                local_ip = result.stdout.strip().split()[0]
            return local_ip
        except:
            return "192.168.1.100"  # Fallback IP


def main():
    local_ip = get_local_ip()

    print("🇬🇲 GSF NATIONAL PRELIMINARY TOURNAMENT")
    print("🌐 TOURNAMENT ACCESS URLS")
    print("=" * 50)
    print()

    print("📋 FOR TOURNAMENT DIRECTOR:")
    print("   Local access: http://localhost:8090")
    print("   Or use:       http://127.0.0.1:8090")
    print()

    print("📱 FOR PLAYERS & SPECTATORS:")
    print(f"   Share this URL: http://{local_ip}:8090")
    print()

    print("📝 INSTRUCTIONS FOR PLAYERS:")
    print("   1. Connect to the same WiFi network")
    print("   2. Open web browser on phone/tablet/computer")
    print(f"   3. Go to: http://{local_ip}:8090")
    print("   4. Bookmark for easy access during tournament")
    print()

    print("🔧 TECHNICAL INFO:")
    print(f"   Server IP: {local_ip}")
    print("   Port: 8090")
    print("   Protocol: HTTP")
    print()

    print("📞 IF PLAYERS CAN'T ACCESS:")
    print("   1. Make sure they're on the same network")
    print("   2. Check firewall settings")
    print("   3. Try these alternative IPs:")

    # Show all network interfaces
    try:
        result = subprocess.run(["hostname", "-I"], capture_output=True, text=True)
        all_ips = result.stdout.strip().split()
        for i, ip in enumerate(all_ips[:3]):  # Show first 3 IPs
            if ip != local_ip:
                print(f"      Alternative {i + 1}: http://{ip}:8090")
    except:
        pass

    print()
    print("✅ Ready to start your tournament!")
    print("🏆 Good luck to all 8 elite players!")


if __name__ == "__main__":
    main()
