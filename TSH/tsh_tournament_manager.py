import sqlite3
from typing import List, Tuple, Any


class TournamentDatabase:
    def __init__(self, db_path: str = ":memory:"):
        self.db_path = db_path
        self.conn = sqlite3.connect(self.db_path)
        self.conn.row_factory = sqlite3.Row
        self._ensure_schema()

    def _ensure_schema(self):
        cur = self.conn.cursor()
        cur.execute("""
            CREATE TABLE IF NOT EXISTS tournaments (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT NOT NULL
            )
        """)
        cur.execute("""
            CREATE TABLE IF NOT EXISTS players (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                tournament_id INTEGER,
                name TEXT
            )
        """)
        cur.execute("""
            CREATE TABLE IF NOT EXISTS games (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                tournament_id INTEGER,
                round_number INTEGER,
                player1 INTEGER,
                player2 INTEGER,
                score1 INTEGER DEFAULT 0,
                score2 INTEGER DEFAULT 0
            )
        """)
        cur.execute("""
            CREATE TABLE IF NOT EXISTS rankings (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                tournament_id INTEGER,
                player_id INTEGER,
                wins INTEGER DEFAULT 0,
                total_score INTEGER DEFAULT 0
            )
        """)
        self.conn.commit()

    def execute_query(self, sql: str, params: Tuple = ()) -> List[Tuple[Any, ...]]:
        cur = self.conn.cursor()
        cur.execute(sql, params)
        rows = cur.fetchall()
        return [tuple(r) for r in rows]

    def execute_write(self, sql: str, params: Tuple = ()) -> int:
        cur = self.conn.cursor()
        cur.execute(sql, params)
        self.conn.commit()
        return cur.lastrowid


class TournamentManager:
    def __init__(self, db: TournamentDatabase = None):
        self.db = db or TournamentDatabase()

    def create_tournament(self, name: str) -> int:
        tid = self.db.execute_write(
            "INSERT INTO tournaments (name) VALUES (?)", (name,)
        )
        return tid

    def add_player(self, tournament_id: int, player_name: str) -> int:
        pid = self.db.execute_write(
            "INSERT INTO players (tournament_id, name) VALUES (?, ?)",
            (tournament_id, player_name),
        )
        # Ensure a rankings row exists
        self.db.execute_write(
            "INSERT INTO rankings (tournament_id, player_id, wins, total_score) VALUES (?, ?, 0, 0)",
            (tournament_id, pid),
        )
        return pid

    def generate_round_pairings(self, tournament_id: int, round_number: int):
        # Simple pairing: pair players by id order
        rows = self.db.execute_query(
            "SELECT id FROM players WHERE tournament_id = ? ORDER BY id",
            (tournament_id,),
        )
        ids = [r[0] for r in rows]
        pairings = []
        for i in range(0, len(ids), 2):
            if i + 1 < len(ids):
                p1 = ids[i]
                p2 = ids[i + 1]
            else:
                p1 = ids[i]
                p2 = None
            gid = self.db.execute_write(
                "INSERT INTO games (tournament_id, round_number, player1, player2) VALUES (?, ?, ?, ?)",
                (tournament_id, round_number, p1, p2),
            )
            pairings.append((p1, p2, gid))
        return pairings

    def update_game_score(self, game_id: int, score1: int, score2: int):
        # Update game
        self.db.execute_write(
            "UPDATE games SET score1 = ?, score2 = ? WHERE id = ?",
            (score1, score2, game_id),
        )
        # Fetch game
        rows = self.db.execute_query(
            "SELECT tournament_id, player1, player2 FROM games WHERE id = ?", (game_id,)
        )
        if not rows:
            return
        tournament_id, p1, p2 = rows[0]
        # Update rankings for p1
        if p1 is not None:
            self.db.execute_write(
                "UPDATE rankings SET total_score = total_score + ? WHERE tournament_id = ? AND player_id = ?",
                (score1, tournament_id, p1),
            )
            if p2 is None or score1 > score2:
                self.db.execute_write(
                    "UPDATE rankings SET wins = wins + 1 WHERE tournament_id = ? AND player_id = ?",
                    (tournament_id, p1),
                )
        if p2 is not None:
            self.db.execute_write(
                "UPDATE rankings SET total_score = total_score + ? WHERE tournament_id = ? AND player_id = ?",
                (score2, tournament_id, p2),
            )
            if score2 > score1:
                self.db.execute_write(
                    "UPDATE rankings SET wins = wins + 1 WHERE tournament_id = ? AND player_id = ?",
                    (tournament_id, p2),
                )


# Backwards-compatible top-level API
__all__ = ["TournamentDatabase", "TournamentManager"]
