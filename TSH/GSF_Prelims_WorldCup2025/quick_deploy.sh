#!/bin/bash
# Quick tournament website generator without TSH dependencies

echo "🚀 Creating GSF Tournament Website Files"
echo "========================================"

TOURNAMENT_DIR="/home/ebrimasaye/TSH/GSF_Prelims_WorldCup2025"
cd "$TOURNAMENT_DIR"

# Create HTML directory
mkdir -p html

echo "🎨 Creating tournament website..."

# Main landing page
cat > html/index.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>GSF National Preliminary Tournament - World Scrabble Championship 2025</title>
    <link href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.0.0/css/all.min.css" rel="stylesheet">
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            color: #333;
        }
        
        .container { max-width: 1200px; margin: 0 auto; padding: 2rem; }
        
        .hero {
            background: white;
            border-radius: 20px;
            padding: 3rem 2rem;
            margin-bottom: 2rem;
            box-shadow: 0 15px 35px rgba(0,0,0,0.1);
            text-align: center;
        }
        
        .flag { font-size: 3rem; margin-bottom: 1rem; }
        
        .tournament-title {
            font-size: 2.5rem;
            color: #2c3e50;
            margin-bottom: 1rem;
            font-weight: 700;
        }
        
        .tournament-subtitle {
            font-size: 1.3rem;
            color: #7f8c8d;
            margin-bottom: 2rem;
        }
        
        .live-badge {
            background: linear-gradient(45deg, #ff6b6b, #ee5a52);
            color: white;
            padding: 1rem 2rem;
            border-radius: 50px;
            display: inline-block;
            font-weight: bold;
            margin: 1rem 0;
            animation: pulse 2s infinite;
            text-decoration: none;
        }
        
        @keyframes pulse {
            0% { transform: scale(1); }
            50% { transform: scale(1.05); }
            100% { transform: scale(1); }
        }
        
        .stats-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
            gap: 2rem;
            margin: 2rem 0;
        }
        
        .stat-card {
            background: white;
            border-radius: 15px;
            padding: 2rem;
            text-align: center;
            box-shadow: 0 10px 30px rgba(0,0,0,0.1);
            transition: transform 0.3s ease;
        }
        
        .stat-card:hover { transform: translateY(-5px); }
        
        .stat-icon {
            font-size: 3rem;
            margin-bottom: 1rem;
            background: linear-gradient(45deg, #667eea, #764ba2);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
        }
        
        .stat-number {
            font-size: 2.5rem;
            font-weight: bold;
            color: #2c3e50;
            margin-bottom: 0.5rem;
        }
        
        .players-section {
            background: white;
            border-radius: 15px;
            padding: 2rem;
            margin: 2rem 0;
            box-shadow: 0 10px 30px rgba(0,0,0,0.1);
        }
        
        .section-title {
            font-size: 1.8rem;
            color: #2c3e50;
            margin-bottom: 2rem;
            text-align: center;
        }
        
        .players-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 1.5rem;
        }
        
        .player-card {
            background: #f8f9fa;
            border-radius: 10px;
            padding: 1.5rem;
            text-align: center;
            border-left: 4px solid #667eea;
        }
        
        .actions {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 1rem;
            margin: 2rem 0;
        }
        
        .action-btn {
            background: linear-gradient(45deg, #667eea, #764ba2);
            color: white;
            padding: 1rem 2rem;
            border-radius: 10px;
            text-decoration: none;
            text-align: center;
            font-weight: bold;
            transition: all 0.3s ease;
            display: flex;
            align-items: center;
            justify-content: center;
            gap: 0.5rem;
        }
        
        .action-btn:hover {
            transform: translateY(-3px);
            box-shadow: 0 5px 20px rgba(102, 126, 234, 0.4);
        }
        
        .footer {
            text-align: center;
            color: white;
            margin-top: 3rem;
            opacity: 0.8;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="hero">
            <div class="flag">🇬🇲</div>
            <h1 class="tournament-title">GSF NATIONAL PRELIMINARY TOURNAMENT</h1>
            <p class="tournament-subtitle">World Scrabble Championship 2025 Qualifier</p>
            <a href="players.html" class="live-badge">
                <i class="fas fa-circle" style="color: #ff4757; margin-right: 0.5rem;"></i>
                LIVE TOURNAMENT - VIEW NOW
            </a>
            <div style="font-size: 1.1rem; color: #34495e; margin-top: 1rem;">
                📅 August 15-17, 2025 | 🏆 Official WSC Qualifier
            </div>
        </div>
        
        <div class="stats-grid">
            <div class="stat-card">
                <div class="stat-icon"><i class="fas fa-users"></i></div>
                <div class="stat-number">8</div>
                <div style="color: #7f8c8d; font-size: 1.1rem;">Elite Players</div>
            </div>
            
            <div class="stat-card">
                <div class="stat-icon"><i class="fas fa-chess-board"></i></div>
                <div class="stat-number">15</div>
                <div style="color: #7f8c8d; font-size: 1.1rem;">Tournament Rounds</div>
            </div>
            
            <div class="stat-card">
                <div class="stat-icon"><i class="fas fa-flag-checkered"></i></div>
                <div class="stat-number">1</div>
                <div style="color: #7f8c8d; font-size: 1.1rem;">Current Round</div>
            </div>
            
            <div class="stat-card">
                <div class="stat-icon"><i class="fas fa-gamepad"></i></div>
                <div class="stat-number">4</div>
                <div style="color: #7f8c8d; font-size: 1.1rem;">Active Games</div>
            </div>
        </div>
        
        <div class="players-section">
            <h2 class="section-title">
                <i class="fas fa-star"></i>
                Tournament Players
                <i class="fas fa-star"></i>
            </h2>
            <div class="players-grid">
                <div class="player-card">
                    <div style="font-weight: bold; color: #2c3e50; font-size: 1.1rem;">Conteh, Ousman</div>
                    <div style="color: #7f8c8d; margin-top: 0.5rem;">Rating: 1800</div>
                </div>
                <div class="player-card">
                    <div style="font-weight: bold; color: #2c3e50; font-size: 1.1rem;">Coron, Jimmy</div>
                    <div style="color: #7f8c8d; margin-top: 0.5rem;">Rating: 1800</div>
                </div>
                <div class="player-card">
                    <div style="font-weight: bold; color: #2c3e50; font-size: 1.1rem;">Jah, Omar Malleh</div>
                    <div style="color: #7f8c8d; margin-top: 0.5rem;">Rating: 1800</div>
                </div>
                <div class="player-card">
                    <div style="font-weight: bold; color: #2c3e50; font-size: 1.1rem;">Nyass, Ebrima</div>
                    <div style="color: #7f8c8d; margin-top: 0.5rem;">Rating: 1800</div>
                </div>
                <div class="player-card">
                    <div style="font-weight: bold; color: #2c3e50; font-size: 1.1rem;">Sambou, Amadou</div>
                    <div style="color: #7f8c8d; margin-top: 0.5rem;">Rating: 1800</div>
                </div>
                <div class="player-card">
                    <div style="font-weight: bold; color: #2c3e50; font-size: 1.1rem;">Sock, Richard John</div>
                    <div style="color: #7f8c8d; margin-top: 0.5rem;">Rating: 1800</div>
                </div>
                <div class="player-card">
                    <div style="font-weight: bold; color: #2c3e50; font-size: 1.1rem;">Sowe, Momodou</div>
                    <div style="color: #7f8c8d; margin-top: 0.5rem;">Rating: 1800</div>
                </div>
                <div class="player-card">
                    <div style="font-weight: bold; color: #2c3e50; font-size: 1.1rem;">Suso, Kebba</div>
                    <div style="color: #7f8c8d; margin-top: 0.5rem;">Rating: 1800</div>
                </div>
            </div>
        </div>
        
        <div class="actions">
            <a href="players.html" class="action-btn">
                <i class="fas fa-eye"></i>
                Live Tournament View
            </a>
            <a href="standings.html" class="action-btn">
                <i class="fas fa-list-ol"></i>
                Current Standings
            </a>
            <a href="pairings.html" class="action-btn">
                <i class="fas fa-random"></i>
                Round 1 Pairings
            </a>
            <a href="about.html" class="action-btn">
                <i class="fas fa-info"></i>
                Tournament Info
            </a>
        </div>
        
        <div class="footer">
            <p><i class="fas fa-globe"></i> Hosted at scrabble.ebrimasaye.com</p>
            <p>Powered by Tournament Shell (TSH) • Gambia Scrabble Federation</p>
        </div>
    </div>
    
    <script>
        setTimeout(function(){ window.location.reload(1); }, 30000);
        console.log('🇬🇲 GSF Tournament System - Live and Ready!');
    </script>
</body>
</html>
EOF

# Players page
cat > html/players.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Players - GSF Tournament 2025</title>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <style>
        body { font-family: Arial, sans-serif; margin: 2rem; background: #f5f5f5; }
        .header { background: linear-gradient(135deg, #1e3c72, #2a5298); color: white; padding: 2rem; border-radius: 15px; text-align: center; margin-bottom: 2rem; }
        .players { background: white; padding: 2rem; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        .player { padding: 1rem; border-bottom: 1px solid #eee; display: flex; justify-content: space-between; align-items: center; }
        .player:hover { background: #f8f9fa; }
        .rank { font-weight: bold; color: #667eea; margin-right: 1rem; }
        .name { font-weight: bold; color: #2c3e50; }
        .rating { color: #7f8c8d; }
    </style>
</head>
<body>
    <div class="header">
        <h1>🇬🇲 GSF Tournament Players</h1>
        <p>World Scrabble Championship 2025 Qualifier</p>
    </div>
    
    <div class="players">
        <h2>👥 Registered Players (8)</h2>
        
        <div class="player">
            <div><span class="rank">1.</span><span class="name">Conteh, Ousman</span></div>
            <div class="rating">Rating: 1800</div>
        </div>
        <div class="player">
            <div><span class="rank">2.</span><span class="name">Coron, Jimmy</span></div>
            <div class="rating">Rating: 1800</div>
        </div>
        <div class="player">
            <div><span class="rank">3.</span><span class="name">Jah, Omar Malleh</span></div>
            <div class="rating">Rating: 1800</div>
        </div>
        <div class="player">
            <div><span class="rank">4.</span><span class="name">Nyass, Ebrima</span></div>
            <div class="rating">Rating: 1800</div>
        </div>
        <div class="player">
            <div><span class="rank">5.</span><span class="name">Sambou, Amadou</span></div>
            <div class="rating">Rating: 1800</div>
        </div>
        <div class="player">
            <div><span class="rank">6.</span><span class="name">Sock, Richard John</span></div>
            <div class="rating">Rating: 1800</div>
        </div>
        <div class="player">
            <div><span class="rank">7.</span><span class="name">Sowe, Momodou</span></div>
            <div class="rating">Rating: 1800</div>
        </div>
        <div class="player">
            <div><span class="rank">8.</span><span class="name">Suso, Kebba</span></div>
            <div class="rating">Rating: 1800</div>
        </div>
    </div>
    
    <p style="text-align: center; margin-top: 2rem;">
        <a href="index.html" style="color: #667eea; text-decoration: none;">← Back to Tournament Portal</a>
    </p>
</body>
</html>
EOF

# Pairings page
cat > html/pairings.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Round 1 Pairings - GSF Tournament 2025</title>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <style>
        body { font-family: Arial, sans-serif; margin: 2rem; background: #f5f5f5; }
        .header { background: linear-gradient(135deg, #1e3c72, #2a5298); color: white; padding: 2rem; border-radius: 15px; text-align: center; margin-bottom: 2rem; }
        .pairings { background: white; padding: 2rem; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        .pairing { padding: 1rem; border-bottom: 1px solid #eee; display: flex; justify-content: space-between; align-items: center; }
        .pairing:hover { background: #f8f9fa; }
        .table { font-weight: bold; color: #667eea; margin-right: 1rem; }
        .vs { color: #ff4757; font-weight: bold; margin: 0 1rem; }
        .player { font-weight: bold; color: #2c3e50; }
    </style>
</head>
<body>
    <div class="header">
        <h1>🎯 Round 1 Pairings</h1>
        <p>GSF National Preliminary Tournament</p>
    </div>
    
    <div class="pairings">
        <h2>📋 Round 1 Pairings - Ready to Generate</h2>
        <p style="color: #7f8c8d; margin-bottom: 2rem;">
            Pairings will be generated via the TSH web interface when the tournament director is ready.
        </p>
        
        <div style="background: #fff3cd; border: 1px solid #ffeaa7; border-radius: 5px; padding: 1rem; margin: 1rem 0;">
            <strong>📢 To Tournament Director:</strong><br>
            1. Open TSH web interface at localhost:8088<br>
            2. Navigate to Division A<br>
            3. Click "Generate Round 1"<br>
            4. Confirm pairings
        </div>
        
        <h3>Expected Pairing Structure (8 players):</h3>
        <div class="pairing">
            <div><span class="table">Table 1:</span> Player 1 <span class="vs">vs</span> Player 8</div>
        </div>
        <div class="pairing">
            <div><span class="table">Table 2:</span> Player 2 <span class="vs">vs</span> Player 7</div>
        </div>
        <div class="pairing">
            <div><span class="table">Table 3:</span> Player 3 <span class="vs">vs</span> Player 6</div>
        </div>
        <div class="pairing">
            <div><span class="table">Table 4:</span> Player 4 <span class="vs">vs</span> Player 5</div>
        </div>
    </div>
    
    <p style="text-align: center; margin-top: 2rem;">
        <a href="index.html" style="color: #667eea; text-decoration: none;">← Back to Tournament Portal</a>
    </p>
</body>
</html>
EOF

# Standings page
cat > html/standings.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Standings - GSF Tournament 2025</title>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <style>
        body { font-family: Arial, sans-serif; margin: 2rem; background: #f5f5f5; }
        .header { background: linear-gradient(135deg, #1e3c72, #2a5298); color: white; padding: 2rem; border-radius: 15px; text-align: center; margin-bottom: 2rem; }
        .standings { background: white; padding: 2rem; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        .player { padding: 1rem; border-bottom: 1px solid #eee; display: flex; justify-content: space-between; align-items: center; }
        .player:hover { background: #f8f9fa; }
        .rank { font-weight: bold; color: #667eea; margin-right: 1rem; width: 3rem; }
        .name { font-weight: bold; color: #2c3e50; flex: 1; }
        .stats { color: #7f8c8d; text-align: right; }
    </style>
</head>
<body>
    <div class="header">
        <h1>🏆 Tournament Standings</h1>
        <p>GSF National Preliminary Tournament</p>
    </div>
    
    <div class="standings">
        <h2>📊 Current Standings - Before Round 1</h2>
        <p style="color: #7f8c8d; margin-bottom: 2rem;">
            Tournament has not started yet. All players are tied at 0-0.
        </p>
        
        <div style="background: #d4edda; border: 1px solid #c3e6cb; border-radius: 5px; padding: 1rem; margin: 1rem 0;">
            <strong>🎯 Tournament Status:</strong> Ready to begin<br>
            <strong>📅 Next:</strong> Round 1 pairings generation
        </div>
        
        <h3>Initial Seeding by Rating:</h3>
        
        <div class="player">
            <div style="display: flex; align-items: center;">
                <span class="rank">1.</span>
                <span class="name">Conteh, Ousman</span>
            </div>
            <div class="stats">0-0 | Rating: 1800</div>
        </div>
        <div class="player">
            <div style="display: flex; align-items: center;">
                <span class="rank">2.</span>
                <span class="name">Coron, Jimmy</span>
            </div>
            <div class="stats">0-0 | Rating: 1800</div>
        </div>
        <div class="player">
            <div style="display: flex; align-items: center;">
                <span class="rank">3.</span>
                <span class="name">Jah, Omar Malleh</span>
            </div>
            <div class="stats">0-0 | Rating: 1800</div>
        </div>
        <div class="player">
            <div style="display: flex; align-items: center;">
                <span class="rank">4.</span>
                <span class="name">Nyass, Ebrima</span>
            </div>
            <div class="stats">0-0 | Rating: 1800</div>
        </div>
        <div class="player">
            <div style="display: flex; align-items: center;">
                <span class="rank">5.</span>
                <span class="name">Sambou, Amadou</span>
            </div>
            <div class="stats">0-0 | Rating: 1800</div>
        </div>
        <div class="player">
            <div style="display: flex; align-items: center;">
                <span class="rank">6.</span>
                <span class="name">Sock, Richard John</span>
            </div>
            <div class="stats">0-0 | Rating: 1800</div>
        </div>
        <div class="player">
            <div style="display: flex; align-items: center;">
                <span class="rank">7.</span>
                <span class="name">Sowe, Momodou</span>
            </div>
            <div class="stats">0-0 | Rating: 1800</div>
        </div>
        <div class="player">
            <div style="display: flex; align-items: center;">
                <span class="rank">8.</span>
                <span class="name">Suso, Kebba</span>
            </div>
            <div class="stats">0-0 | Rating: 1800</div>
        </div>
    </div>
    
    <p style="text-align: center; margin-top: 2rem;">
        <a href="index.html" style="color: #667eea; text-decoration: none;">← Back to Tournament Portal</a>
    </p>
</body>
</html>
EOF

# About page
cat > html/about.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>About - GSF Tournament 2025</title>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <style>
        body { font-family: Arial, sans-serif; margin: 2rem; background: #f5f5f5; }
        .header { background: linear-gradient(135deg, #1e3c72, #2a5298); color: white; padding: 2rem; border-radius: 15px; text-align: center; margin-bottom: 2rem; }
        .content { background: white; padding: 2rem; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        .info-box { background: #f8f9fa; border-left: 4px solid #667eea; padding: 1rem; margin: 1rem 0; }
    </style>
</head>
<body>
    <div class="header">
        <h1>🏆 About the Tournament</h1>
        <p>GSF National Preliminary Tournament</p>
    </div>
    
    <div class="content">
        <h2>🇬🇲 GSF National Preliminary Tournament for World Scrabble Championship 2025</h2>
        
        <div class="info-box">
            <h3>📅 Tournament Details</h3>
            <ul>
                <li><strong>Dates:</strong> August 15-17, 2025</li>
                <li><strong>Format:</strong> Round Robin (15 rounds)</li>
                <li><strong>Players:</strong> 8 elite Gambian players</li>
                <li><strong>Purpose:</strong> World Scrabble Championship 2025 Qualifier</li>
            </ul>
        </div>
        
        <div class="info-box">
            <h3>🎯 Tournament Structure</h3>
            <ul>
                <li><strong>System:</strong> Round Robin with Gibson Groups</li>
                <li><strong>Scoring:</strong> Thai-style points system</li>
                <li><strong>Tiebreakers:</strong> Board stability and rating</li>
                <li><strong>Breaks:</strong> After rounds 1, 8, and 14</li>
            </ul>
        </div>
        
        <div class="info-box">
            <h3>🏆 Prizes & Qualification</h3>
            <ul>
                <li><strong>Top 3 finishers</strong> will be eligible for prizes</li>
                <li><strong>Winner</strong> qualifies for World Scrabble Championship 2025</li>
                <li><strong>Official WSC Qualifier</strong> recognized internationally</li>
            </ul>
        </div>
        
        <div class="info-box">
            <h3>⚙️ Technical Details</h3>
            <ul>
                <li><strong>Tournament Software:</strong> Tournament Shell (TSH) v3.340</li>
                <li><strong>Web Interface:</strong> Real-time updates</li>
                <li><strong>Hosted by:</strong> Gambia Scrabble Federation</li>
                <li><strong>Website:</strong> scrabble.ebrimasaye.com</li>
            </ul>
        </div>
        
        <h3>📞 Contact Information</h3>
        <p>For questions about this tournament, please contact the Gambia Scrabble Federation.</p>
        
        <div style="text-align: center; margin-top: 2rem; padding: 1rem; background: linear-gradient(45deg, #667eea, #764ba2); color: white; border-radius: 10px;">
            <strong>🌍 Good luck to all players representing The Gambia!</strong>
        </div>
    </div>
    
    <p style="text-align: center; margin-top: 2rem;">
        <a href="index.html" style="color: #667eea; text-decoration: none;">← Back to Tournament Portal</a>
    </p>
</body>
</html>
EOF

echo "✅ Tournament website files created!"
echo ""
echo "📁 Files created in html/ directory:"
ls -la html/
echo ""
echo "🌐 DEPLOYMENT READY!"
echo "==================="
echo ""
echo "To deploy to scrabble.ebrimasaye.com:"
echo "1. Use FTP/SFTP client (FileZilla, WinSCP, etc.)"
echo "2. Connect to: ebrimasaye@scrabble.ebrimasaye.com"
echo "3. Upload all files from html/ to htdocs/tournament/"
echo ""
echo "🎯 Your tournament website will be live at:"
echo "   https://scrabble.ebrimasaye.com"
echo ""
echo "✅ Ready for tournament!"
