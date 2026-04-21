import sys
from pathlib import Path

# Ensure TSH module files are importable
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import tsh_tournament_manager as manager_module  # noqa: E402


def test_pairings_and_rankings(tmp_path):
    db_file = str(tmp_path / "test_pairings.db")

    # Initialize database at a temp path and manager with that DB
    db = manager_module.TournamentDatabase(db_path=db_file)
    mgr = manager_module.TournamentManager()
    # Inject our test DB
    mgr.db = db

    # Create tournament and players
    t_id = mgr.create_tournament("Unit Test Tourney")
    mgr.add_player(t_id, "Alice")
    mgr.add_player(t_id, "Bob")
    mgr.add_player(t_id, "Carol")
    mgr.add_player(t_id, "Dave")

    # Generate pairings for round 1
    pairings = mgr.generate_round_pairings(t_id, 1)
    assert len(pairings) >= 2

    # Verify game records created
    games = db.execute_query(
        "SELECT id FROM games WHERE tournament_id = ? AND round_number = ?", (t_id, 1)
    )
    assert len(games) >= 1
    game_id = games[0][0]

    # Update a game and check rankings update
    mgr.update_game_score(game_id, 100, 80)

    # Verify rankings reflect a win and total_score updated
    ranks = db.execute_query(
        "SELECT wins, total_score FROM rankings WHERE tournament_id = ?", (t_id,)
    )
    total_wins = sum(r[0] for r in ranks)
    total_score = sum(r[1] for r in ranks)

    assert total_wins >= 1
    assert total_score >= 180
