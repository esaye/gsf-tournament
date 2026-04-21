# GSF Prelims WorldCup 2025 - Tournament Setup Complete! 🎯

## Current Status ✅
Your tournament is now fully set up and ready for this weekend!

- **Tournament Name**: GSF National Preliminary Tournament for World Scrabble Championship 2025
- **Dates**: August 15-17, 2025
- **Players**: 8 registered players from Gambia
- **Format**: Swiss system, up to 30 rounds
- **Database**: SQLite database with all player information
- **Web Interface**: Running on port 8088
- **Domain**: Ready for deployment to scrabble.ebrimasaye.com

## ✅ What's Already Done

### 1. Database Setup
- SQLite database created at `/home/ebrimasaye/TSH/tournaments.db`
- Tournament #7 created with all 8 players
- Player ratings set to 1800 (Gambian team standard)

### 2. Tournament Files
- Configuration file: `config.tsh` - properly configured
- Player data file: `a.t` - clean and ready for new tournament
- Photo directory: `html/pix/u/` - ready for player photos
- Backup system in place

### 3. TSH Server
- **Status**: Running on port 8088 ✅
- **Access**: http://localhost:8088
- **Division A**: All 8 players visible and ready

### 4. Management Tools Created
- `tournament_manager.py` - Complete tournament management
- `test_web_interface.py` - Web interface testing
- `run_tsh.sh` - TSH environment wrapper

## 🚀 How to Use for Your Tournament

### Starting the Tournament
1. **Access the Web Interface**:
   ```bash
   # Open in browser
   http://localhost:8088
   ```

2. **Navigate to Division A**:
   - Click on "Division A" in the web interface
   - You'll see all 8 players listed

3. **Generate First Round Pairings**:
   - In the web interface, look for "Pair" or "Generate Round 1"
   - Click to create the first round pairings

### Managing the Tournament
```bash
# Check tournament status
cd /home/ebrimasaye/TSH/GSF_Prelims_WorldCup2025
python3 tournament_manager.py status

# List all players
python3 tournament_manager.py players

# Create tournament backup
python3 tournament_manager.py backup

# Test web interface
python3 test_web_interface.py
```

### Adding Player Photos
1. Place photos in: `html/pix/u/`
2. Use naming convention:
   - `conteh_ousman.jpg`
   - `sock_richard_john.jpg`
   - `suso_kebba.jpg`
   - etc. (see README_PHOTOS.md)

## 🌐 Deploying to scrabble.ebrimasaye.com

Your config already includes SFTP settings:
```
config sftp_host = 'sftp.ebrimasaye.com'
config sftp_username = 'ebrimasaye'
config sftp_path = 'htdocs/tournament'
```

To upload tournament data to your website, use the TSH upload command through the web interface.

## 📊 Tournament Day Workflow

### Round Management
1. **Generate Pairings**: Use web interface to pair each round
2. **Enter Scores**: Click on game cells to enter results
3. **View Standings**: Real-time standings update automatically
4. **Print Reports**: Generate standings and pairing sheets

### Score Entry
- Click on individual games in the division grid
- Enter scores for both players
- Results update standings immediately
- Export/print updated standings

## 🛠 Troubleshooting

### If TSH Server Stops
```bash
cd /home/ebrimasaye/TSH/GSF_Prelims_WorldCup2025
# Check if running
netstat -tlnp | grep 8088

# Restart if needed
nohup bash -c 'PERL5LIB=/home/ebrimasaye/TSH/lib/perl perl /home/ebrimasaye/TSH/tsh.pl .' > tsh_server.log 2>&1 &
```

### View Server Logs
```bash
tail -f /home/ebrimasaye/TSH/GSF_Prelims_WorldCup2025/tsh_server.log
```

### Database Issues
```bash
# View tournament data
sqlite3 /home/ebrimasaye/TSH/tournaments.db "SELECT * FROM tournaments WHERE id = 7;"

# View players
sqlite3 /home/ebrimasaye/TSH/tournaments.db "SELECT * FROM players WHERE tournament_id = 7;"
```

## 📁 Important Files

```
GSF_Prelims_WorldCup2025/
├── config.tsh              # Main tournament configuration
├── a.t                     # Player data file
├── tournament_manager.py   # Management scripts
├── test_web_interface.py   # Testing tools
├── run_tsh.sh             # TSH wrapper
├── tsh_server.log         # Server logs
├── html/                  # Web files
│   └── pix/u/            # Player photos directory
└── TOURNAMENT_SETUP_GUIDE.md # This guide
```

## 🎯 Ready for Tournament!

Your tournament system is completely set up and tested. The web interface is running, all players are registered, and you're ready to:

1. Generate Round 1 pairings
2. Enter scores as games complete
3. Track standings in real-time
4. Generate reports for players and officials
5. Upload live results to your website

**Access your tournament at**: http://localhost:8088

Good luck with your tournament this weekend! 🏆

## Support
If you need to make changes or encounter issues, all the tools are in place:
- Database management via SQLite commands
- Web interface for all tournament operations  
- Backup and restore capabilities
- Real-time monitoring and logging
