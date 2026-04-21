import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import tsh_tournament_manager as manager_module

def test_draw_scores_do_not_count_as_wins(tmp_path):
    db_file = str(tmp_path / "test_draw.db")
    db = manager_module.TournamentDatabase(db_path=db_file)
    mgr = manager_module.TournamentManager()
    mgr.db = db

    t_id = mgr.create_tournament("Draw Test")
    p1 = mgr.add_player(t_id, "A")
    p2 = mgr.add_player(t_id, "B")

    pairings = mgr.generate_round_pairings(t_id, 1)
    assert len(pairings) >= 1
    game_id = pairings[0][2]

    mgr.update_game_score(game_id, 50, 50)

    ranks = db.execute_query("SELECT wins, total_score FROM rankings WHERE tournament_id = ?", (t_id,))
    total_wins = sum(r[0] for r in ranks)
    total_score = sum(r[1] for r in ranks)

    assert total_wins == 0
    assert total_score == 100
