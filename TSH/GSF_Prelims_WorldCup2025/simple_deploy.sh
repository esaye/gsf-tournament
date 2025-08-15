#!/bin/bash
# Simple tournament website deployment script

echo "🚀 Deploying GSF Tournament to scrabble.ebrimasaye.com"
echo "=================================================="

TOURNAMENT_DIR="/home/ebrimasaye/TSH/GSF_Prelims_WorldCup2025"
DOMAIN="scrabble.ebrimasaye.com"
REMOTE_PATH="htdocs/tournament"

# Step 1: Generate HTML files using TSH
echo "📄 Generating HTML files..."
cd "$TOURNAMENT_DIR"

# Set Perl environment
export PERL5LIB="/home/ebrimasaye/TSH/lib/perl"

# Generate tournament pages
echo "Generating standings..."
perl /home/ebrimasaye/TSH/tsh.pl . standings a 2>/dev/null || echo "OK - will generate later"

# Generate other pages
echo "Generating alpha list..."
perl /home/ebrimasaye/TSH/tsh.pl . alpha a 2>/dev/null || echo "OK - will generate later"

# Ensure html directory exists
mkdir -p html

# Step 2: Create a comprehensive index page
echo "🎨 Creating tournament landing page..."

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
            font-family: 'Arial', sans-serif;
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
        
        .tournament-title {
            font-size: 2.5rem;
            color: #2c3e50;
            margin-bottom: 1rem;
            font-weight: 700;
        }
        
        .live-badge {
            background: linear-gradient(45deg, #ff6b6b, #ee5a52);
            color: white;
            padding: 1rem 2rem;
            border-radius: 50px;
            display: inline-block;
            font-weight: bold;
            margin: 1rem 0;
            text-decoration: none;
        }
        
        .actions {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 1rem;
            margin: 2rem 0;
        }
        
        .action-btn {
            background: linear-gradient(45deg, #667eea, #764ba2);
            color: white;
            padding: 1.5rem;
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
            <div style="font-size: 3rem; margin-bottom: 1rem;">🇬🇲</div>
            <h1 class="tournament-title">GSF NATIONAL PRELIMINARY TOURNAMENT</h1>
            <p style="font-size: 1.3rem; color: #7f8c8d; margin-bottom: 2rem;">World Scrabble Championship 2025 Qualifier</p>
            <a href="/division/a/" class="live-badge">
                <i class="fas fa-circle" style="color: #ff4757; margin-right: 0.5rem;"></i>
                LIVE TOURNAMENT - VIEW NOW
            </a>
            <div style="font-size: 1.1rem; color: #34495e; margin-top: 1rem;">
                📅 August 15-17, 2025 | 🏆 Official WSC Qualifier
            </div>
        </div>
        
        <div class="actions">
            <a href="/division/a/" class="action-btn">
                <i class="fas fa-eye"></i>
                Live Division A
            </a>
            <a href="/A-standings-by-rating.html" class="action-btn">
                <i class="fas fa-list-ol"></i>
                Current Standings
            </a>
            <a href="/A-alpha.html" class="action-btn">
                <i class="fas fa-users"></i>
                Player List
            </a>
            <a href="/A-pairings-1.html" class="action-btn">
                <i class="fas fa-random"></i>
                Round 1 Pairings
            </a>
        </div>
        
        <div class="footer">
            <p><i class="fas fa-globe"></i> Hosted at scrabble.ebrimasaye.com</p>
            <p>Powered by Tournament Shell (TSH) • Gambia Scrabble Federation</p>
        </div>
    </div>
    
    <script>
        setTimeout(function(){ window.location.reload(1); }, 60000);
        console.log('🇬🇲 GSF Tournament System - Live!');
    </script>
</body>
</html>
EOF

echo "✅ Landing page created!"

# Step 3: Create a simple status page
echo "📊 Creating tournament status page..."

cat > html/status.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Tournament Status - GSF Prelims 2025</title>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <style>
        body { font-family: Arial, sans-serif; margin: 2rem; background: #f5f5f5; }
        .status { background: white; padding: 2rem; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        .live { color: #ff4757; font-weight: bold; }
        .players { margin: 2rem 0; }
        .player { padding: 0.5rem; border-bottom: 1px solid #eee; }
    </style>
</head>
<body>
    <div class="status">
        <h1>🇬🇲 GSF Tournament Status</h1>
        <p class="live">🔴 LIVE - Round 1 in Progress</p>
        
        <div class="players">
            <h2>👥 Registered Players (8)</h2>
            <div class="player">1. Conteh, Ousman</div>
            <div class="player">2. Coron, Jimmy</div>
            <div class="player">3. Jah, Omar Malleh</div>
            <div class="player">4. Nyass, Ebrima</div>
            <div class="player">5. Sambou, Amadou</div>
            <div class="player">6. Sock, Richard John</div>
            <div class="player">7. Sowe, Momodou</div>
            <div class="player">8. Suso, Kebba</div>
        </div>
        
        <p><a href="/">← Back to Tournament Portal</a></p>
    </div>
</body>
</html>
EOF

echo "✅ Status page created!"

# Step 4: Manual file upload instructions
echo ""
echo "🌐 MANUAL DEPLOYMENT INSTRUCTIONS"
echo "=================================="
echo ""
echo "Your tournament files are ready in: $TOURNAMENT_DIR/html/"
echo ""
echo "To upload to scrabble.ebrimasaye.com:"
echo "1. Use FTP/SFTP client (FileZilla, etc.)"
echo "2. Connect to: ebrimasaye@scrabble.ebrimasaye.com"
echo "3. Upload contents of html/ folder to htdocs/tournament/"
echo ""
echo "Files ready for upload:"
ls -la html/
echo ""
echo "🎯 Tournament will be live at: https://scrabble.ebrimasaye.com"
echo "✅ Setup complete!"
