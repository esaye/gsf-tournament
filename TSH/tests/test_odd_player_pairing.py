import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import tsh_tournament_manager as manager_module


def test_odd_player_pairing(tmp_path):
    db_file = str(tmp_path / "test_odd.db")
    db = manager_module.TournamentDatabase(db_path=db_file)
    mgr = manager_module.TournamentManager()
    mgr.db = db

    t_id = mgr.create_tournament("Odd Players")
    mgr.add_player(t_id, "P1")
    mgr.add_player(t_id, "P2")
    mgr.add_player(t_id, "P3")

    pairings = mgr.generate_round_pairings(t_id, 1)
    # With 3 players, expect at least one pairing and one bye (None)
    assert any(p[1] is None for p in pairings)
