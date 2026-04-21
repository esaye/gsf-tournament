# Shim for backward compatibility: import core classes from manager module
from manager import TournamentDatabase, TournamentManager

__all__ = ["TournamentDatabase", "TournamentManager"]
