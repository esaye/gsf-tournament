#!/bin/bash

echo "🔍 TESTING BACKUP URL: scrabble.ebrimasaye.com/tournament"
echo "=================================================="
echo

# Test main domain
echo "1. Testing main domain..."
main_status=$(curl -s -o /dev/null -w '%{http_code}' https://scrabble.ebrimasaye.com)
echo "   https://scrabble.ebrimasaye.com → $main_status"

# Test tournament path
echo
echo "2. Testing tournament path..."
tournament_status=$(curl -s -o /dev/null -w '%{http_code}' https://scrabble.ebrimasaye.com/tournament)
echo "   https://scrabble.ebrimasaye.com/tournament → $tournament_status"

# Test with index.html
echo
echo "3. Testing with index.html..."
index_status=$(curl -s -o /dev/null -w '%{http_code}' https://scrabble.ebrimasaye.com/tournament/index.html)
echo "   https://scrabble.ebrimasaye.com/tournament/index.html → $index_status"

# Test individual pages
echo
echo "4. Testing individual pages..."
players_status=$(curl -s -o /dev/null -w '%{http_code}' https://scrabble.ebrimasaye.com/tournament/players.html)
echo "   players.html → $players_status"

pairings_status=$(curl -s -o /dev/null -w '%{http_code}' https://scrabble.ebrimasaye.com/tournament/pairings.html)
echo "   pairings.html → $pairings_status"

standings_status=$(curl -s -o /dev/null -w '%{http_code}' https://scrabble.ebrimasaye.com/tournament/standings.html)
echo "   standings.html → $standings_status"

echo
echo "=================================================="
echo "📊 SUMMARY:"

if [ "$tournament_status" = "200" ]; then
    echo "✅ BACKUP URL IS WORKING!"
    echo "🌐 Tournament accessible at: https://scrabble.ebrimasaye.com/tournament"
elif [ "$tournament_status" = "404" ]; then
    echo "❌ BACKUP URL NOT WORKING (404 - Files not uploaded)"
    echo "🔧 SOLUTION: Upload files to htdocs/tournament/ directory"
    echo "📦 Ready package: tournament_website_package.tar.gz"
else
    echo "⚠️  BACKUP URL STATUS: $tournament_status"
    echo "🔍 May need further investigation"
fi

echo
echo "🎯 NEXT STEPS:"
if [ "$tournament_status" != "200" ]; then
    echo "1. Use hosting control panel to upload files"
    echo "2. Or use FTP/SFTP to upload tournament_website_package.tar.gz"
    echo "3. Extract to htdocs/tournament/ directory"
    echo "4. Set permissions: files 644, directories 755"
    echo "5. Re-run this test"
else
    echo "1. ✅ Backup URL is working correctly!"
    echo "2. 🎉 Tournament website is accessible"
    echo "3. 📱 Test on mobile devices"
    echo "4. 🔄 Set up auto-sync for future updates"
fi

echo
echo "📁 Local files ready at: /home/ebrimasaye/TSH/GSF_Prelims_WorldCup2025/html/"
echo "📦 Upload package: tournament_website_package.tar.gz"
