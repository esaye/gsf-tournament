#!/usr/bin/env python3
"""
GSF Preliminaries - Dual-Verification Score Entry Server
Remote Tournament Direction: Oslo → Gambia

Features:
- Player authentication with PINs
- Dual-verification score entry
- Real-time notifications
- TSH integration
- Dispute handling
- Live updates to ngrok site
"""

import os
import json
import sqlite3
import time
from datetime import datetime
from flask import Flask, request, jsonify, render_template_string
from flask_cors import CORS
import threading
import subprocess
import requests

app = Flask(__name__)
CORS(app)

# Configuration
DATABASE_FILE = 'gsf_tournament.db'
TSH_HOST = 'http://localhost:8088'
NGROK_URL = 'https://2bfd0006cbcc.ngrok-free.app'

# Player database with PINs
PLAYERS = {
    'conteh': {'name': 'Conteh, Ousman', 'rating': 1850, 'pin': '1001', 'id': 1},
    'sock': {'name': 'Sock, Richard John', 'rating': 1820, 'pin': '1002', 'id': 2},
    'suso': {'name': 'Suso, Kebba', 'rating': 1790, 'pin': '1003', 'id': 3},
    'sambou': {'name': 'Sambou, Amadou', 'rating': 1760, 'pin': '1004', 'id': 4},
    'jah': {'name': 'Jah, Omar Malleh', 'rating': 1740, 'pin': '1005', 'id': 5},
    'nyass': {'name': 'Nyass, Ebrima', 'rating': 1720, 'pin': '1006', 'id': 6},
    'coron': {'name': 'Coron, Jimmy', 'rating': 1700, 'pin': '1007', 'id': 7},
    'sowe': {'name': 'Sowe, Momodou', 'rating': 1680, 'pin': '1008', 'id': 8}
}

def init_database():
    """Initialize SQLite database for tournament management"""
    conn = sqlite3.connect(DATABASE_FILE)
    cursor = conn.cursor()
    
    # Create tables
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS pending_scores (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            round INTEGER NOT NULL,
            player1_id TEXT NOT NULL,
            player2_id TEXT NOT NULL,
            player1_score INTEGER,
            player2_score INTEGER,
            submitted_by TEXT NOT NULL,
            submitted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            verified_by TEXT,
            verified_at TIMESTAMP,
            status TEXT DEFAULT 'pending',
            dispute_reason TEXT
        )
    ''')
    
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS final_results (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            round INTEGER NOT NULL,
            player1_id TEXT NOT NULL,
            player2_id TEXT NOT NULL,
            player1_score INTEGER NOT NULL,
            player2_score INTEGER NOT NULL,
            finalized_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    ''')
    
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS activity_log (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            player_id TEXT,
            action TEXT,
            details TEXT,
            timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    ''')
    
    conn.commit()
    conn.close()
    print("✅ Database initialized")

def log_activity(player_id, action, details):
    """Log player activity for audit trail"""
    conn = sqlite3.connect(DATABASE_FILE)
    cursor = conn.cursor()
    cursor.execute('INSERT INTO activity_log (player_id, action, details) VALUES (?, ?, ?)',
                   (player_id, action, details))
    conn.commit()
    conn.close()

@app.route('/')
def index():
    """Serve the player verification interface"""
    with open('gsf_player_verification_system.html', 'r') as f:
        return f.read()

@app.route('/api/authenticate', methods=['POST'])
def authenticate_player():
    """Authenticate player with PIN"""
    data = request.get_json()
    player_id = data.get('player_id')
    pin = data.get('pin')
    
    if not player_id or not pin:
        return jsonify({'success': False, 'error': 'Missing credentials'})
    
    if player_id in PLAYERS and PLAYERS[player_id]['pin'] == pin:
        log_activity(player_id, 'login', f'Successful authentication')
        
        # Get current game for this player
        current_game = get_current_game(player_id)
        
        return jsonify({
            'success': True,
            'player': PLAYERS[player_id],
            'current_game': current_game
        })
    else:
        log_activity(player_id, 'login_failed', f'Failed authentication attempt')
        return jsonify({'success': False, 'error': 'Invalid credentials'})

@app.route('/api/submit_score', methods=['POST'])
def submit_score():
    """Submit game score for verification"""
    data = request.get_json()
    player_id = data.get('player_id')
    opponent_id = data.get('opponent_id')
    round_num = data.get('round', 1)
    player_score = data.get('player_score')
    opponent_score = data.get('opponent_score')
    
    if not all([player_id, opponent_id, player_score, opponent_score]):
        return jsonify({'success': False, 'error': 'Missing score data'})
    
    # Validate scores
    try:
        player_score = int(player_score)
        opponent_score = int(opponent_score)
        
        if player_score == opponent_score:
            return jsonify({'success': False, 'error': 'Scores cannot be tied'})
        
        if player_score < 0 or opponent_score < 0 or player_score > 999 or opponent_score > 999:
            return jsonify({'success': False, 'error': 'Invalid score range'})
            
    except ValueError:
        return jsonify({'success': False, 'error': 'Invalid score format'})
    
    conn = sqlite3.connect(DATABASE_FILE)
    cursor = conn.cursor()
    
    # Check if there's already a pending score for this game
    cursor.execute('''
        SELECT id, submitted_by FROM pending_scores 
        WHERE round = ? AND 
              ((player1_id = ? AND player2_id = ?) OR (player1_id = ? AND player2_id = ?))
              AND status = 'pending'
    ''', (round_num, player_id, opponent_id, opponent_id, player_id))
    
    existing = cursor.fetchone()
    
    if existing:
        # Someone already submitted - this is verification
        existing_id, submitted_by = existing
        
        if submitted_by == player_id:
            conn.close()
            return jsonify({'success': False, 'error': 'You already submitted this score'})
        
        # This is opponent verification - check if scores match
        cursor.execute('SELECT player1_score, player2_score, player1_id FROM pending_scores WHERE id = ?',
                       (existing_id,))
        result = cursor.fetchone()
        existing_p1_score, existing_p2_score, existing_p1_id = result
        
        # Determine score positions based on who submitted first
        if existing_p1_id == player_id:
            # Current player was player1 in original submission
            scores_match = (player_score == existing_p1_score and opponent_score == existing_p2_score)
        else:
            # Current player was player2 in original submission  
            scores_match = (opponent_score == existing_p1_score and player_score == existing_p2_score)
        
        if scores_match:
            # Scores match - finalize result
            cursor.execute('''
                UPDATE pending_scores 
                SET status = 'verified', verified_by = ?, verified_at = CURRENT_TIMESTAMP
                WHERE id = ?
            ''', (player_id, existing_id))
            
            # Add to final results
            cursor.execute('''
                INSERT INTO final_results (round, player1_id, player2_id, player1_score, player2_score)
                VALUES (?, ?, ?, ?, ?)
            ''', (round_num, existing_p1_id, 
                  opponent_id if existing_p1_id == player_id else player_id,
                  existing_p1_score, existing_p2_score))
            
            conn.commit()
            conn.close()
            
            log_activity(player_id, 'score_verified', 
                        f'Verified R{round_num}: {existing_p1_score}-{existing_p2_score}')
            
            # Update TSH system
            update_tsh_scores(existing_p1_id, opponent_id if existing_p1_id == player_id else player_id,
                             round_num, existing_p1_score, existing_p2_score)
            
            return jsonify({
                'success': True, 
                'status': 'verified',
                'message': 'Scores verified! Result is now final.'
            })
        else:
            # Scores don't match - mark as disputed
            cursor.execute('''
                UPDATE pending_scores 
                SET status = 'disputed'
                WHERE id = ?
            ''', (existing_id,))
            
            conn.commit()
            conn.close()
            
            log_activity(player_id, 'score_disputed', 
                        f'Disputed R{round_num}: submitted {player_score}-{opponent_score}, existing {existing_p1_score}-{existing_p2_score}')
            
            # Notify TD about dispute
            notify_td_dispute(player_id, opponent_id, round_num, 
                             f"{player_score}-{opponent_score}", f"{existing_p1_score}-{existing_p2_score}")
            
            return jsonify({
                'success': True,
                'status': 'disputed', 
                'message': 'Score mismatch detected. Tournament Director has been notified.'
            })
    
    else:
        # First submission - store as pending
        cursor.execute('''
            INSERT INTO pending_scores 
            (round, player1_id, player2_id, player1_score, player2_score, submitted_by)
            VALUES (?, ?, ?, ?, ?, ?)
        ''', (round_num, player_id, opponent_id, player_score, opponent_score, player_id))
        
        conn.commit()
        conn.close()
        
        log_activity(player_id, 'score_submitted', 
                    f'Submitted R{round_num}: {player_score}-{opponent_score}')
        
        # Notify opponent
        notify_opponent(opponent_id, player_id, round_num, f"{player_score}-{opponent_score}")
        
        return jsonify({
            'success': True,
            'status': 'pending',
            'message': 'Score submitted. Waiting for opponent verification.'
        })

@app.route('/api/get_pending', methods=['GET'])
def get_pending_scores():
    """Get pending scores for a player"""
    player_id = request.args.get('player_id')
    
    if not player_id:
        return jsonify({'success': False, 'error': 'Missing player ID'})
    
    conn = sqlite3.connect(DATABASE_FILE)
    cursor = conn.cursor()
    
    # Get scores pending verification by this player
    cursor.execute('''
        SELECT round, player1_id, player2_id, player1_score, player2_score, submitted_by
        FROM pending_scores 
        WHERE ((player1_id = ? OR player2_id = ?) AND submitted_by != ? AND status = 'pending')
    ''', (player_id, player_id, player_id))
    
    pending = cursor.fetchall()
    
    # Get scores submitted by this player awaiting opponent verification
    cursor.execute('''
        SELECT round, player1_id, player2_id, player1_score, player2_score
        FROM pending_scores 
        WHERE submitted_by = ? AND status = 'pending'
    ''', (player_id,))
    
    awaiting = cursor.fetchall()
    
    conn.close()
    
    return jsonify({
        'success': True,
        'pending_verification': [
            {
                'round': p[0],
                'opponent': PLAYERS[p[1] if p[2] == player_id else p[2]]['name'],
                'score': f"{p[3]}-{p[4]}",
                'submitted_by': PLAYERS[p[5]]['name']
            }
            for p in pending
        ],
        'awaiting_opponent': [
            {
                'round': a[0], 
                'opponent': PLAYERS[a[1] if a[2] == player_id else a[2]]['name'],
                'score': f"{a[3]}-{a[4]}"
            }
            for a in awaiting
        ]
    })

def get_current_game(player_id):
    """Get current game/pairing for a player"""
    # Mock implementation - in real version, would query TSH API
    opponent_ids = [p for p in PLAYERS.keys() if p != player_id]
    opponent_id = opponent_ids[0]  # Simplified for demo
    
    return {
        'round': 1,
        'table': 1,
        'opponent': PLAYERS[opponent_id],
        'opponent_id': opponent_id
    }

def update_tsh_scores(player1_id, player2_id, round_num, score1, score2):
    """Update TSH system with verified scores"""
    try:
        # Format score string for TSH
        score_string = f"{score1}-{score2}"
        
        # Get player IDs for TSH
        p1_tsh_id = PLAYERS[player1_id]['id']
        p2_tsh_id = PLAYERS[player2_id]['id']
        
        # TSH API call to set scores
        url = f"{TSH_HOST}/?a=setscores&v={score_string}&d=A&p={p1_tsh_id}&r={round_num}"
        
        response = requests.get(url, timeout=10)
        
        if response.status_code == 200:
            print(f"✅ TSH updated: R{round_num} {player1_id}({score1}) vs {player2_id}({score2})")
            log_activity('system', 'tsh_update', f'Updated TSH: R{round_num} {score_string}')
        else:
            print(f"⚠️ TSH update failed: {response.status_code}")
            
    except Exception as e:
        print(f"❌ TSH update error: {e}")
        log_activity('system', 'tsh_error', f'TSH update failed: {str(e)}')

def notify_opponent(opponent_id, submitter_id, round_num, score):
    """Notify opponent that score needs verification"""
    print(f"📱 NOTIFICATION: {PLAYERS[opponent_id]['name']} - verify R{round_num} score {score} from {PLAYERS[submitter_id]['name']}")
    # In real implementation, send push notification, email, or SMS

def notify_td_dispute(player1_id, player2_id, round_num, score1, score2):
    """Notify Tournament Director about score dispute"""
    print(f"🚨 TD ALERT: Score dispute R{round_num}")
    print(f"   {PLAYERS[player1_id]['name']}: {score1}")
    print(f"   {PLAYERS[player2_id]['name']}: {score2}")
    # In real implementation, send alert to TD in Oslo

@app.route('/api/status')
def system_status():
    """Get system status"""
    conn = sqlite3.connect(DATABASE_FILE)
    cursor = conn.cursor()
    
    cursor.execute('SELECT COUNT(*) FROM pending_scores WHERE status = "pending"')
    pending_count = cursor.fetchone()[0]
    
    cursor.execute('SELECT COUNT(*) FROM final_results')
    final_count = cursor.fetchone()[0]
    
    cursor.execute('SELECT COUNT(*) FROM pending_scores WHERE status = "disputed"')
    disputed_count = cursor.fetchone()[0]
    
    conn.close()
    
    return jsonify({
        'success': True,
        'status': {
            'pending_verifications': pending_count,
            'finalized_results': final_count,
            'disputes': disputed_count,
            'tsh_connected': check_tsh_connection(),
            'timestamp': datetime.now().isoformat()
        }
    })

def check_tsh_connection():
    """Check if TSH is accessible"""
    try:
        response = requests.get(TSH_HOST, timeout=5)
        return response.status_code == 200
    except:
        return False

@app.route('/api/admin/disputes')
def get_disputes():
    """Get all disputed scores (for TD review)"""
    conn = sqlite3.connect(DATABASE_FILE)
    cursor = conn.cursor()
    
    cursor.execute('''
        SELECT round, player1_id, player2_id, player1_score, player2_score, 
               submitted_by, dispute_reason, submitted_at
        FROM pending_scores 
        WHERE status = 'disputed'
        ORDER BY submitted_at DESC
    ''')
    
    disputes = cursor.fetchall()
    conn.close()
    
    return jsonify({
        'success': True,
        'disputes': [
            {
                'round': d[0],
                'player1': PLAYERS[d[1]]['name'],
                'player2': PLAYERS[d[2]]['name'],
                'reported_score': f"{d[3]}-{d[4]}",
                'submitted_by': PLAYERS[d[5]]['name'],
                'reason': d[6] or 'Score mismatch',
                'timestamp': d[7]
            }
            for d in disputes
        ]
    })

def start_background_tasks():
    """Start background monitoring tasks"""
    def monitor_system():
        while True:
            time.sleep(60)  # Check every minute
            # Monitor for stuck pending scores, send reminders, etc.
            print("🔄 System monitoring check...")
    
    monitor_thread = threading.Thread(target=monitor_system, daemon=True)
    monitor_thread.start()

if __name__ == '__main__':
    print("🏆 GSF Dual-Verification Score Entry Server")
    print("🌍 Remote Tournament Direction: Oslo → Gambia")
    print("="*50)
    
    # Initialize database
    init_database()
    
    # Start background tasks
    start_background_tasks()
    
    print(f"🔗 TSH Integration: {TSH_HOST}")
    print(f"🌐 Ngrok URL: {NGROK_URL}")
    print(f"📊 Players: {len(PLAYERS)}")
    print("="*50)
    
    # Start Flask server
    app.run(host='0.0.0.0', port=8091, debug=True)
