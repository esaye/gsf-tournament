#!/usr/bin/perl

# Copyright (C) 2005-2019 John J. Chew, III <poslfit@gmail.com>
# All Rights Reserved

package TSH::Command::PRiZes;

use strict;
use warnings;

use TSH::Division::FindExtremeGames;
use TSH::Log;
use TSH::Utility qw(Debug DebugOn Ordinal);
use TSH::Utility::CSV;
use JavaScript::Serializable;

# DebugOn('SP');

our (@ISA) = qw(TSH::Command);

=pod

=head1 NAME

TSH::Command::PRiZes - implement the C<tsh> PRiZes command

=head1 SYNOPSIS

  my $command = new TSH::Command::PRiZes;
  my $argsp = $command->ArgumentTypes();
  my $helptext = $command->Help();
  my (@names) = $command->Names();
  $command->Run($tournament, @parsed_arguments);
  
=head1 ABSTRACT

TSH::Command::PRiZes is a subclass of TSH::Command.

=cut

=head1 DESCRIPTION

=head2 Prize Order

At the 2018 NASC, I finally got tired of the confusion that ensues
at prize ceremonies as a result of prizes having to be listed in
priority of how they should be awarded: descending order by value,
with ties placing class prizes ahead of place prizes.  I added a
new prize line parameter "order", which should be used like this.

  prize rank 1 A $200 exclusive=A
  prize rank 1 A $100 groupname='Class B' class=B exclusive=A order=2
  prize rank 2 A $100 exclusive=A

When printed, prizes in a block will be sorted first by the value
of their 'order' parameter, then by the order in which they were
defined.  If a prize does not have an 'order' parameter, it is
deemed to have one of value 0.  A block is terminated by a prize
line that does not declare a prize, such as a note, page break or
separator line.

=over 4

=cut

my (@column_classes) = qw(number description value winner);
my %school_bios;

sub DivisionName ($$);
sub initialise ($$$$);
sub LongTaggedName ($);
sub LongTaggedHTMLName ($);
sub new ($);
sub Rounds ($$$);
sub Run ($$@);
sub ShowPrize ($$$$);

=item $string = DivisionName($tournament, $dname);

Return "Division $dname " if the tournament has more than
one division, else the empty string.

=cut

sub DivisionName ($$) {
  my $tourney = shift;
  my $dname = shift;
  if ($tourney->CountDivisions() > 1) {
    my $dp = $tourney->GetDivisionByName($dname);
    return $dp->Label() . ' ' if $dp;
    return "Division $dname ";
    }
  else {
    return '';
    }
  }

sub FindPlayers ($$$$) {
  my $this = shift;
  my $tournament = shift;
  my $dp = shift;
  my $prize = shift;
  my (@players);
  if ($prize->{'memberfile'}) {
    (@players) = $this->LoadPlayersFromFile($tournament, $dp, $prize);
    }
  elsif ($prize->{'members'}) {
    if ($dp) {
      (@players) = grep { defined $_ } 
	map { $dp->Player($_) } @{eval $prize->{'members'}};
      }
    else {
      (@players) = $this->LoadPlayersFromList($tournament, $prize);
      }
    }
  elsif ($dp) {
    @players = $dp->Players();
    }
  else {
    for my $dp1 ($tournament->Divisions()) {
      push(@players, $dp1->Players());
      }
    }
  if (my $class = $prize->{'class'}) {
    my $had_members = scalar(@players);
#   warn "checking $had_members for class $class";
    @players = grep { $_->ClassMatch($class) } @players;
    if ($had_members and !@players) {
      $tournament->TellUser('eclassemp', $dp ? $dp->Name() : '?', $class);
      }
    }
#     die "@$members" if ref($prize->{'members'}) eq 'ARRAY';
  return @players;
  }

=item $parserp->initialise()

Used internally to (re)initialise the object.

=cut

sub initialise ($$$$) {
  my $this = shift;
  my $path = shift;
  my $namesp = shift;
  my $argtypesp = shift;

  $this->{'help'} = <<'EOF';
Use this command to display a prize table.
"PRiZe" lists all prizes and winners as they would be
awarded based on current data.
"PRiZe chart" will list only the prizes to be awarded,
not the winners.
EOF
  $this->{'names'} = [qw(prz prizes)];
  $this->{'argtypes'} = [qw(Text)];
  $this->{'x_row_buffer'} = [];
# print "names=@$namesp argtypes=@$argtypesp\n";

  return $this;
  }

sub LoadPlayersFromFile ($$$$) {
  my $this = shift;
  my $tournament = shift;
  my $dp = shift;
  my $prize = shift;
  my (@players);
  my $config = $tournament->Config();
  my $fn = $config->MakeRootPath($prize->{'memberfile'});
  my $fh = TSH::Utility::OpenFile("<", $fn);
  while (<$fh>) {
    chomp; s/^\s+//; s/\s+$//;
    my $p = $tournament->FindPlayer($_, undef, $dp);
    if (defined $p) {
      push(@players, $p);
      }
    else {
      warn "PRiZES: no such player: $_\n";
      }
    }
  return @players;
  }

sub LoadPlayersFromList ($$$) {
  my $this = shift;
  my $tournament = shift;
  my $prize = shift;
  my (@players);
  for my $member (@{$prize->{'members'}}) {
    if ($member =~ /^([a-zA-Z]+)(\d+)$/) {
      my $dn = $1;
      my $pn = $2;
      my $dp = $tournament->GetDivisionByName($dn);
      if (!$dp) {
	warn "'$dn' is not a valid division name in player '$member'.\n";
	}
      else {
	if (my $p = $dp->Player($pn)) {
	  push(@players, $p);
	  }
	else {
	  warn "'$member' is not a valid player number.\n";
	  }
	}
      }
    else {
      warn "PRiZes: Can't find division name and player number in: $member\n";
      }
    }
  return @players;
  }

sub LongTaggedName ($) {
  my $p = shift;
  my $config = $p->Division()->Tournament()->Config();
  my $name = $p->TaggedName();
  if (my $sbpath = $config->Value('school_bios')) {
    unless (%school_bios) {
      eval 'use NSA::SchoolBios qw(LoadBios)';
      if ($@) {
	$school_bios{'_error'} = 1;
        }
      else {
	my $psp = NSA::SchoolBios::LoadBios($config->MakeRootPath($sbpath));
	for my $p1 (@$psp) {
	  my $sname = $p1->{'school'};
  #	$sname =~ s/#//;
	  $school_bios{$sname} = $p1;
	  }
	}
      }
    my $sname = $p->Name();
    if (my $sp = $school_bios{$sname}) {
      $name .= " $sp->{'player1'}, $sp->{'player2'} ($sp->{'city'}, $sp->{'state'})";
      }
    elsif (!$school_bios{'_error'}) {
      warn "No such school in $sbpath: $sname";
     }
    }
  return $name;
  }

sub LongTaggedHTMLName ($) {
  my $p = shift;
  my $config = $p->Division()->Tournament()->Config();
  my $name = $p->TaggedHTMLName();
  if (my $sbpath = $config->Value('school_bios')) {
    unless (%school_bios) {
      eval 'use NSA::SchoolBios qw(LoadBios)';
      if ($@) {
	$school_bios{'_error'} = 1;
        }
      else {
	my $psp = NSA::SchoolBios::LoadBios($config->MakeRootPath($sbpath));
	for my $p1 (@$psp) {
	  my $sname = $p1->{'school'};
  #	$sname =~ s/#//;
	  $school_bios{$sname} = $p1;
	  }
	}
      }
    my $sname = $p->Name();
    if (my $sp = $school_bios{$sname}) {
      $name .= " $sp->{'player1'}, $sp->{'player2'} ($sp->{'city'}, $sp->{'state'})";
      }
    elsif (!$school_bios{'_error'}) {
      warn "No such school in $sbpath: $sname";
     }
    }
  return $name;
  }

sub new ($) { return TSH::Utility::new(@_); }

sub Rounds ($$$) {
  my $config = shift;
  my $first = shift;
  my $last = shift;
  
  my $max_rounds = $config->Value('max_rounds');
  $first ||= 1;
  $last ||= $max_rounds;

  return '' if $first == 1 and ($last || -1) == $max_rounds;
  return " Round $first" if $first == $last;
  return " Rounds $first-$last";
  }

=item $command->RowBufferAdd($order, $rowCount, $sub);

Add prize data to the row buffer, to be displayed in the 
  correct order (see "Prize Order" above) by RowBufferFlush().

=cut

sub RowBufferAdd($$$) {
  my $this = shift;
  my $order = shift;
  my $rowCount = shift;
  my $sub = shift;
  my $id = $#{$this->{'x_row_buffer'}};
  push(@{$this->{'x_row_buffer'}}, {'order'=>$order, 'id'=>$id, 'rowCount'=>$rowCount, 'closure'=>$sub});
  }

=item $command->RowBufferFlush($logp);

Display prize data that was added to the row buffer by 
RowBufferAdd(), in the order described in "Prize Order" 
above; then clear the buffer.

=cut

sub RowBufferFlush ($$) {
  my $this = shift;
  my $logp = shift;
  for my $row (sort { 
    ($a->{'order'}||0) <=> ($b->{'order'}||0)
      or $a->{'id'} <=> $b->{'id'}
    } @{$this->{'x_row_buffer'}}) {
    $row->{'closure'}();
    $this->PageRowIncrement($logp, $row->{'rowCount'});
    }
  $this->{'x_row_buffer'} = [];
  }

=item $command->Run($tournament, @parsed_args)

Should run the command in the context of the given
tournament with the specified parsed arguments.

=cut

# TODO: split this up into smaller subs for maintainability

sub Run ($$@) { 
  my $this = shift;
  my $tournament = shift;
  my $config = $this->{'x_config'} = $tournament->Config();
  my $prizes = $config->Value('prizes');
  my $chart = shift;

  my $nowinner = $this->{'prz_nowinner'} = ($chart || '') =~ /^chart$/i;
  my $partial = 0;

  if (!defined $config->Value('max_rounds')) {
    $tournament->TellUser('eneed_max_rounds');
    return;
    }

  my $logp = new TSH::Log($tournament, undef, 'prizes', undef);
  TSH::Utility::UpdateFile(
    $config->MakeLibPath("js/tshPrize.js"),
    $config->MakeHTMLPath("tshPrize.js"));
  my $logSlidep = new TSH::Log($tournament, undef, 'prizeslides', undef,
    {
      'body_class' => 'prizeslides',
      'noconsole' => 1,
      'notext' => 1,
      'notitle' => 1,
      'javascript' => ['tshPrize.js'],
    });
  my $banner = $config->Value('prize_banner') // $config->Value('event_name') // 'Prizewinners';
  $logSlidep->Write('', <<"EOF");
<div id=tshPrz class=prizeFrame>
  <div id=tshPrzNumber class=sequence></div>
  <div class=bannerAlign><div class=banner>$banner</div></div>
  <div class=nonBanner>
    <div class=photoAlign>
      <div class=photo><img id=tshPrzPhoto class=winner src="unknown.gif"></div>
    </div>
    <div class=textAlign>
      <div class=text>
	<div id=tshPrzCategory class=category></div>
	<div id=tshPrzName class=winner></div>
	<div id=tshPrzValue class=value></div>
      </div>
    </div>
  </div>
</div>
EOF

  my (@text_titles) = ('#', 'Prize');
  my (@html_titles) = ('#', qw(Description Value));
  unless ($nowinner) {
    $text_titles[-1] .= ', Winner';
    push(@html_titles, 'Winner(s)');
    for my $dp ($tournament->Divisions()) {
      unless ($dp->IsComplete()) {
	$partial = 1;
	}
      }
    $logp->WritePartialWarning(4) if $partial;
    }
  $logp->ColumnClasses(\@column_classes, 'top1');
  $logp->ColumnTitles({'text' => \@text_titles, 'html' => \@html_titles});
  my $break = $config->Value('prizes_page_break') || 1000;
  my $prizeno = 1;
  $this->{'xclude'} = {};
  $this->{'x_page_row'} = 0;
  my (@csv) = (['prize#','division','player','name','prize','value']);
  my (@slides);
  $this->{'csv'} = \@csv;
  $this->{'slides'} = \@slides;
  for my $p0 (0..$#$prizes) {
    my $prize = $prizes->[$p0];
    $this->ShowPrize($tournament, $logp, $prizeno, $prize);
    $prizeno++ unless $prize->{'type'} =~ /^(?:break|note|separator|title)$/;
    }
  $this->RowBufferFlush($logp);
  {
    my $prizes = JavaScript::Serializable::ToJavaScriptAny([ reverse @slides ]);
    $logSlidep->Write('', <<"EOF");
<script type="text/javascript">
prizes = $prizes
</script>
EOF
  }
  $logSlidep->Close();
  $logp->Close(); # closing this one last makes it openable by BrowseLast
  my $fh = TSH::Utility::OpenFile('>', $config->MakeHTMLPath('prizes.csv'));
  print $fh TSH::Utility::CSV::Encode \@csv;
  close $fh;
  return 0;
  }

our %gPrizeData; # global, also used by COMMentary.pm
BEGIN {
  # when 'unit' == 'game',
  #   games are represented as lists: [$score1, $score2, $p1, $p2, $r0, $rat1, $rat2].
  # when 'unit' == 'player', the objects passed to subs are of class TSH::Player
  %gPrizeData = (
    'brlh' => { # best record lower half, as per US NSC
      'initialise' => sub { 
	my $prize = shift;
	my $tournament = shift;
	my $config = $tournament->Config();
	my $dp = $tournament->GetDivisionByName($prize->{'division'});
	my $firstr0 = $prize->{'first'} - 1;
	$dp->ComputeRanks($prize->{'first'}-2);
	my (@players) = 
	  # must have played at least one game today
	  grep { $_->CountScores() > $firstr0 }
	  $dp->Players();
	if ($config->Value('standings_spread_cap')) {
	  @players = TSH::Player::SortByCappedStanding($firstr0-1, @players);
	  }
	else {
	  @players = TSH::Player::SortByStanding($firstr0-1, @players);
	  }
        for my $i (0..@players/2-1) 
	  { $players[$i]->{'xr'} = 0; }
	for my $i (@players/2 .. $#players) {
	  { $players[$i]->{'xr'} = $i+1; }
	  }
        },
      'unit' => 'player',
      'filter' => sub ($$) { 
	my $p = shift;
	my $prize = shift;
	my $firstr0 = $prize->{'first'} - 1;
	my $lastr0 = $prize->{'last'} - 1;
	# must have played at least one game today
	return 0 unless $p->CountScores() > $firstr0; 
	return 0 unless $p->{'xr'};
	$p->{'xw'} = $p->RoundWins($lastr0)-$p->RoundWins($firstr0-1);
	$p->{'xl'} = $p->RoundLosses($lastr0)-$p->RoundLosses($firstr0-1);
	$p->{'xs'} = $p->RoundSpread($lastr0)-$p->RoundSpread($firstr0-1);
	return 1;
	},
      'compare' => sub ($$) { 
	$_[1]->{'xw'} <=> $_[0]->{'xw'}
	|| $_[0]->{'xl'} <=> $_[1]->{'xl'}
	|| $_[1]->{'xs'} <=> $_[0]->{'xs'}
	},
      'prizename' => 'Best Record Lower Half',
      'formatwinner' => sub {
	my $p = shift @_;
	my $prize = shift @_;
	return (
	  sprintf("%s %.1f-%.1f %+d starting %s",
	    LongTaggedName($p), 
	    $p->{'xw'},
	    $p->{'xl'},
	    $p->{'xs'},
	    Ordinal($p->{'xr'})
	    ),
	  sprintf("<span class=winner>%s<span> <span class=record> %.1f-%.1f %+d starting %s</span>",
	    LongTaggedHTMLName($p), 
	    $p->{'xw'},
	    $p->{'xl'},
	    $p->{'xs'},
	    Ordinal($p->{'xr'})
	    )
	  );
        },
      'rankcriterion' => sub ($) { my $p = shift @_; return 
	join(';', @$p{qw(xw xl xs)}) 
        },
      },
    'handicap' => {
      'unit' => 'player',
      'initialise' => sub { 
	my $prize = shift;
	my $tournament = shift;
	my $dp = $tournament->GetDivisionByName($prize->{'division'}) 
	  or $tournament->TellUser('ebaddiv', $prize->{'division'});
	my $r0 = $dp->MostScores() - 1;
	$dp->ComputeRatings($r0);
	for my $p ($dp->Players()) {
	  $p->{'xhc'} = ($p->GetOrSetEtcScalar('handicap') || 0)
	    + 2*$p->RoundWins($p->CountScores()-1);
	  }
        },
      'filter' => sub ($$) { 
	my $p = shift;
	return 0 unless $p->GamesPlayed();
	return 1;
	},
      'compare' => sub ($$) { 
	my $is_capped = $_[0]->Division()->Tournament()->Config()->HasSpreadCaps();
	$_[1]->{'xhc'} <=> $_[0]->{'xhc'} 
	|| $_[1]->Wins() <=> $_[0]->Wins()
	|| $_[0]->Losses() <=> $_[1]->Losses()
	|| (
	  $is_capped
	    ? ($_[1]->CappedSpread() <=> $_[0]->CappedSpread())
	    : ($_[1]->Spread() <=> $_[0]->Spread())
	  )
        },
      'prizename' => 'Handicap Points',
      'formatwinner' => sub {
	my $p = shift @_;
	my $is_capped = $p->Division()->Tournament()->Config()->HasSpreadCaps();
	return (
	  sprintf("%s %d HP %g-%g %+d",
	    LongTaggedName($p),
	    $p->{'xhc'},
	    $p->Wins(),
	    $p->Losses(),
	    $is_capped ? $p->CappedSpread() : $p->Spread()
	    ),
	  sprintf("<span class=winner>%s</span> <span class=record>%d HP %g-%g %+d</span>",
	    LongTaggedHTMLName($p),
	    $p->{'xhc'},
	    $p->Wins(),
	    $p->Losses(),
	    $is_capped ? $p->CappedSpread() : $p->Spread()
	    )
	  );
        },
      'rankcriterion' => sub ($) { 
	my $p = shift @_;
	my $is_capped = $p->Division()->Tournament()->Config()->HasSpreadCaps();
	return join('.', $p->{'xhc'}, $p->Wins(), $p->Losses(), $is_capped ? $p->CappedSpread() : $p->Spread);
	},
      },
    'highloss' => {
      'unit' => 'player',
      'filter' => sub ($$) { 
	my $p = shift;
	my $prize = shift;
	my $firstr0 = $prize->{'first'} - 1;
	my $lastr0 = $prize->{'last'} - 1;
	$p->{'xhl'} = -9999;
	$p->{'xr0'} = undef;
	for my $r0 ($firstr0..$lastr0) {
	  my $ms = $p->Score($r0);
	  my $os = $p->OpponentScore($r0);
	  next unless (defined $ms) && (defined $os) && $ms < $os;
	  if ($p->{'xhl'} < $ms) {
	    $p->{'xhl'} = $ms;
	    $p->{'xr0'} = $r0;
	    }
	  }
	return defined $p->{'xr0'};
	},
      'compare' => sub ($$) { $_[1]->{'xhl'} <=> $_[0]->{'xhl'} },
      'prizename' => 'High Loss',
      'formatwinner' => sub {
	my $p = shift @_;
	my $r0 = $p->{'xr0'};
	return (
	  sprintf("Round %d. %s %d-%d vs. %s",
	    $r0+1,
	    LongTaggedName($p),
	    $p->{'xhl'}, 
	    $p->OpponentScore($r0),
	    LongTaggedName($p->Opponent($r0))
	    ),
	  sprintf("<span class=round>Round %d.</span> <span class=winner>%s</span> <span class=record>%d-%d vs. %s</span>",
	    $r0+1,
	    LongTaggedHTMLName($p),
	    $p->{'xhl'}, 
	    $p->OpponentScore($r0),
	    LongTaggedHTMLName($p->Opponent($r0))
	    )
	  );
        },
      'rankcriterion' => sub ($) { my $p = shift @_; return $p->{'xhl'}; },
      },
    'highratingchange' => {
      'initialise' => sub { 
	my $prize = shift;
	my $tournament = shift;
	my $dname = $prize->{division};
	&::Use('TSH::ReportCommand::ExtremePlayers');
	for my $dp ($tournament->Divisions()) {
	  next if $dp->Name() ne $dname and $dname ne '*';
	  my $r0 = $dp->MostScores() - 1;
	  $dp->ComputeRatings($r0);
	  }
        },
      'unit' => 'player',
      'filter' => sub ($$) {
	my $p = shift;
	my $prize = shift;
	return 0 unless $prize->{unratedok} 
	  or TSH::ReportCommand::ExtremePlayers::IsActiveRatedPlayer($p);
	$p->{'xhrc'} = TSH::ReportCommand::ExtremePlayers::EvaluatePlayerRatingChange($p);
	return 1;
        },
      'compare' => sub ($$) { $_[1]->{'xhrc'} <=> $_[0]->{'xhrc'} },
      'prizename' => 'High Rating Change',
      'formatwinner' => sub {
	my $p = shift;
	my $prize = shift;
	return (
	  sprintf("%s %+d = %d-%d",
	    LongTaggedName($p),
	    $p->{'xhrc'}, 
	    $p->NewRating(-1),
	    $p->Rating()
	    ),
	  sprintf("<span class=winner>%s</span> <span class=record>%+d = %d-%d<span>",
	    LongTaggedHTMLName($p),
	    $p->{'xhrc'}, 
	    $p->NewRating(-1),
	    $p->Rating()
	    )
	  );
        },
      'rankcriterion' => sub ($) { my $p = shift @_; return $p->{'xhrc'}; },
      },
    'highwin' => {
      'unit' => 'player',
      'filter' => sub ($$) { 
	my $p = shift;
	my $prize = shift;
	my $firstr0 = $prize->{'first'} - 1;
	my $lastr0 = $prize->{'last'} - 1;
	$p->{'xhw'} = -9999;
	$p->{'xr0'} = undef;
	for my $r0 ($firstr0..$lastr0) {
	  my $ms = $p->Score($r0);
	  my $os = $p->OpponentScore($r0);
	  next unless (defined $ms) && (defined $os) && $ms > $os;
	  if ($p->{'xhw'} < $ms) {
	    $p->{'xhw'} = $ms;
	    $p->{'xr0'} = $r0;
	    }
	  }
	return defined $p->{'xr0'};
	},
      'compare' => sub ($$) { $_[1]->{'xhw'} <=> $_[0]->{'xhw'} },
      'prizename' => 'High Win',
      'formatwinner' => sub {
	my $p = shift @_;
	my $r0 = $p->{'xr0'};
	return (
	  sprintf("Round %d. %s %d-%d vs. %s",
	    $r0+1,
	    LongTaggedName($p),
	    $p->{'xhw'}, 
	    $p->OpponentScore($r0),
	    LongTaggedName($p->Opponent($r0))
	    ),
	  sprintf("<span class=round>Round %d.</span> <span class=winner>%s</span> <span class=record>%d-%d vs. %s</span>",
	    $r0+1,
	    LongTaggedHTMLName($p),
	    $p->{'xhw'}, 
	    $p->OpponentScore($r0),
	    LongTaggedHTMLName($p->Opponent($r0))
	    )
	  );
        },
      'rankcriterion' => sub ($) { my $p = shift @_; return $p->{'xhw'}; },
      },
    'lowloss' => {
      'unit' => 'player',
      'filter' => sub ($$) { 
	my $p = shift;
	my $prize = shift;
	my $firstr0 = $prize->{'first'} - 1;
	my $lastr0 = $prize->{'last'} - 1;
	$p->{'xll'} = 9999;
	$p->{'xr0'} = undef;
	for my $r0 ($firstr0..$lastr0) {
	  my $ms = $p->Score($r0);
	  my $os = $p->OpponentScore($r0);
	  next unless (defined $ms) && (defined $os) && $ms < $os;
	  if ($p->{'xll'} > $ms) {
	    $p->{'xll'} = $ms;
	    $p->{'xr0'} = $r0;
	    }
	  }
	return defined $p->{'xr0'};
	},
      'compare' => sub ($$) { $_[0]->{'xll'} <=> $_[1]->{'xll'} },
      'prizename' => 'Low Loss',
      'formatwinner' => sub {
	my $p = shift @_;
	my $r0 = $p->{'xr0'};
	return (
	  sprintf("Round %d. %s %d-%d vs. %s",
	    $r0+1,
	    LongTaggedName($p),
	    $p->{'xll'}, 
	    $p->OpponentScore($r0),
	    LongTaggedName($p->Opponent($r0))
	    ),
	  sprintf("<span class=round>Round %d.</span> <span class=winner>%s</span> <span class=record>%d-%d vs. %s</span>",
	    $r0+1,
	    LongTaggedHTMLName($p),
	    $p->{'xll'}, 
	    $p->OpponentScore($r0),
	    LongTaggedHTMLName($p->Opponent($r0))
	    )
	  );
        },
      'rankcriterion' => sub ($) { my $p = shift @_; return $p->{'xll'}; },
      },
    'lowwin' => {
      'unit' => 'player',
      'filter' => sub ($$) { 
	my $p = shift;
	my $prize = shift;
	my $firstr0 = $prize->{'first'} - 1;
	my $lastr0 = $prize->{'last'} - 1;
	$p->{'xlw'} = 9999;
	$p->{'xr0'} = undef;
	for my $r0 ($firstr0..$lastr0) {
	  my $ms = $p->Score($r0);
	  my $os = $p->OpponentScore($r0);
	  next unless (defined $ms) && (defined $os) && $ms > $os;
	  if ($p->{'xlw'} > $ms) {
	    $p->{'xlw'} = $ms;
	    $p->{'xr0'} = $r0;
	    }
	  }
	return defined $p->{'xr0'};
	},
      'compare' => sub ($$) { $_[0]->{'xlw'} <=> $_[1]->{'xlw'} },
      'prizename' => 'Low Win',
      'formatwinner' => sub {
	my $p = shift @_;
	my $r0 = $p->{'xr0'};
	return (
	  sprintf("Round %d. %s %d-%d vs. %s",
	    $r0+1,
	    LongTaggedName($p),
	    $p->{'xlw'}, 
	    $p->OpponentScore($r0),
	    LongTaggedName($p->Opponent($r0))
	    ),
	  sprintf("<span class=round>Round %d.</span> <span class=winner>%s</span> <span class=record>%d-%d vs. %s</span>",
	    $r0+1,
	    LongTaggedHTMLName($p),
	    $p->{'xlw'}, 
	    $p->OpponentScore($r0),
	    LongTaggedHTMLName($p->Opponent($r0))
	    )
	  );
        },
      'rankcriterion' => sub ($) { my $p = shift @_; return $p->{'xlw'}; },
      },
    'luckystiff' => {
      'initialise' => sub { 
	my $prize = shift;
	my $tournament = shift;
	eval "use TSH::Player::LuckyStiff";
	if ($@) {
	  $tournament->TellUser('enomod', 'TSH/Player/LuckyStiff.pm', $@);
	  }
        },
      'unit' => 'player',
      'filter' => sub ($$) { 
	my $pp = shift;
	my $prize = shift;
	my ($tl, $lossesp) = $pp->LuckyStiff($prize->{'rounds'}||6);
	$pp->{'xls'} = $tl || return 0;
	$pp->{'xlss'} = $lossesp;
	return 1;
	},
      # big ratings differences first
      'compare' => sub ($$) { $_[0]{'xls'} <=> $_[1]{'xls'} },
      'prizename' => 'Lucky Stiff',
      'formatwinner' => sub {
	my $p = shift @_;
	return (
	  sprintf("%s %d = %s",
	    LongTaggedName($p),
	    $p->{'xls'},
	    join('+', @{$p->{'xlss'}}),
	    ),
	  sprintf("<span class=winner>%s</span> <span class=record>%d = %s</span>",
	    LongTaggedHTMLName($p),
	    $p->{'xls'},
	    join('+', @{$p->{'xlss'}}),
	    )
	  );
        },
      'rankcriterion' => sub ($) { my $p = shift @_; return $p->{'xls'}; }
      },
    'overexp' => {
      'initialise' => sub { 
        &::Use('TSH::ReportCommand::ExtremePlayers');
	my $prize = shift;
	my $tournament = shift;
	my $dp = $tournament->GetDivisionByName($prize->{'division'}) 
	  or $tournament->TellUser('ebaddiv', $prize->{'division'});
	my $r0 = $dp->MostScores() - 1;
	$dp->ComputeRatings($r0);
	for my $p ($dp->Players()) {
	  $p->{'xrw'} = ($p->{'ewins1'}||0) + ($p->{'ewins2'}||0);
	  $p->{'xoe'} = $p->GetOrSetEtcScalar('excwins');
	  }
        },
      'unit' => 'player',
      'filter' => sub ($$) { 
	my $p = shift @_;
	return 0 unless $p->CountScores(); 
	return 0 unless $p->Active();
	return 0 unless TSH::ReportCommand::ExtremePlayers::IsActiveRatedPlayer($p);
#	warn $p->Name();
	1;
        },
      'compare' => sub ($$) { 
	$_[1]->{'xoe'} <=> $_[0]->{'xoe'};
        },
      'prizename' => 'OverExpectation',
      'formatwinner' => sub {
	my $p = shift @_;
	my $wins = $p->Wins();
	return (
	  sprintf("%s %g-%g %+d (expected %.2f excess %.2f)", 
	    LongTaggedName($p), $wins, $p->Losses(), $p->Spread(), 
	    $p->{'xrw'} - $p->{'xoe'},
	    $p->{'xoe'},
	    ),
	  sprintf("<span class=winner>%s</span> <span class=record>%g-%g %+d (expected %.2f excess %.2f)</span>", 
	    LongTaggedHTMLName($p), $wins, $p->Losses(), $p->Spread(), 
	    $p->{'xrw'} - $p->{'xoe'},
	    $p->{'xoe'},
	    )
	  );
        },
      'rankcriterion' => sub ($) { 
	my $p = shift @_;
	return join(';', $p->{'xoe'});
        },
      },
    'overseed' => {
      'initialise' => sub { 
	my $prize = shift;
	my $tournament = shift;
	my $dp = $tournament->GetDivisionByName($prize->{'division'}) 
	  or $tournament->TellUser('ebaddiv', $prize->{'division'});
	my $lastr0 = $dp->MaxRound0();
	$dp->ComputeRanks($lastr0);
	my (@players) = TSH::Player::SortByInitialStanding($dp->Players());
	my $lastrat = -1;
	my $rank = 0;
	# TODO: should use Utility::*Rank*
	for my $i (0..$#players) {
	  my $p = $players[$i];
	  my $rat = $p->Rating();
	  if ($rat != $lastrat) {
	    $rank = $i + 1;
	    $lastrat = $rat;
	    }
	  $p->{'xseed'} = $rank;
	  }
        },
      'unit' => 'player',
      'filter' => sub ($$) { 
	my $p = shift @_;
#	warn $p->Name();
	return 0 unless $p->CountScores() || $p->Division()->Tournament()->Config->Value('scores') eq 'sudoku'; 
	return 0 unless $p->Active();
#	warn $p->Name();
	1;
        },
      # TODO: duplicated in TSH::Player::SortByCurrentStanding
      'compare' => sub ($$) { 
	$_[0]->RoundRank(-2) - $_[0]->{'xseed'} 
	  <=> $_[1]->RoundRank(-2) - $_[1]->{'xseed'} ||
	    ($_[0]->Division()->Tournament()->Config->Value('overseed_tiebroken_by_spread')
             ? ($_[1]->Spread() <=> $_[0]->Spread()) : 0 ) ||
	$_[0]->RoundRank(-2) <=> $_[1]->RoundRank(-2)
        },
      'prizename' => 'OverSeed',
      'formatwinner' => sub {
	my $p = shift @_;
	return (
	  sprintf("%s %g-%g %+d (seed %d overall rank %d)",
	    LongTaggedName($p),
	    $p->Wins(),
	    $p->Losses(),
	    $p->Spread(),
	    $p->{'xseed'},
	    $p->RoundRank(-2)
	    ),
	  sprintf("<span class=winner>%s</span> <span=record>%g-%g %+d (seed %d overall rank %d)</span>",
	    LongTaggedHTMLName($p),
	    $p->Wins(),
	    $p->Losses(),
	    $p->Spread(),
	    $p->{'xseed'},
	    $p->RoundRank(-2)
	    )
	  );
        },
      'rankcriterion' => sub ($) { 
	my $p = shift @_;
	return join(';', $p->RoundRank(-2) - $p->{'xseed'}, $p->RoundRank(-2));
        },
      },
    'rank' => {
      'unit' => 'player',
      'filter' => sub ($$) { 
#	$_[0]->Active();
	return 0 unless $_[0]->GamesPlayed() || ($_[0]->Division()->Tournament()->Config->Value('scores')||'') eq 'sudoku'; 
	1;
        },
      'compare' => sub ($$) { 
	my $is_capped = $_[0]->Division()->Tournament()->Config()->HasSpreadCaps();
	$_[1]->Wins() <=> $_[0]->Wins()
	|| $_[0]->Losses() <=> $_[1]->Losses()
	|| (
	  $is_capped
	    ? ($_[1]->CappedSpread() <=> $_[0]->CappedSpread())
	    : ($_[1]->Spread() <=> $_[0]->Spread())
	  )
        },
      'prizename' => 'Rank',
      'formatwinner' => sub {
	my $p = shift @_;
	my $prize = shift @_;
	my $is_capped = $p->Division()->Tournament()->Config()->HasSpreadCaps();
        my $ltm = LongTaggedName($p);
        my $lthm = LongTaggedHTMLName($p);
	return (
	  sprintf("%s %g-%g %+d",
	    $ltm . ($prize->{'eval'} ? (" " . join " ", eval ($prize->{'eval'}) ) : ""),
	    $p->Wins(),
	    $p->Losses(), $is_capped ? $p->CappedSpread() : $p->Spread()
	    ),
	  sprintf("<span class=winner>%s</span> <span class=record>%g-%g %+d</span>",
	    $lthm . ($prize->{'eval'} ? (" " . join " ", eval ($prize->{'eval'}) ) : ""),
	    $p->Wins(),
	    $p->Losses(), $is_capped ? $p->CappedSpread() : $p->Spread()
	    )
	  );
        },
      'rankcriterion' => sub ($) { 
	my $p = shift @_;
	return join(';', $p->Wins(), $p->Losses(), $p->Spread()); 
        },
      },
    'roundrecord' => {
      'unit' => 'player',
      'filter' => sub ($$) { 
	my $p = shift;
	$p->Division()->Tournament()->Config()->Value('standings_spread_cap') && die "not yet";
	my $prize = shift;
	my $firstr0 = $prize->{'first'} - 1;
	my $lastr0 = $prize->{'last'} - 1;
	return 0 unless $p->CountScores() > $firstr0; # must have played at least one game in range
	$p->{'xw'} = $p->RoundWins($lastr0)-$p->RoundWins($firstr0-1);
	$p->{'xl'} = $p->RoundLosses($lastr0)-$p->RoundLosses($firstr0-1);
	$p->{'xs'} = $p->RoundSpread($lastr0)-$p->RoundSpread($firstr0-1);
	return 1;
	},
      'compare' => sub ($$) { 
	$_[1]->{'xw'} <=> $_[0]->{'xw'}
	|| $_[0]->{'xl'} <=> $_[1]->{'xl'}
	|| $_[1]->{'xs'} <=> $_[0]->{'xs'}
	},
      'prizename' => 'Best Record',
      'formatwinner' => sub {
	my $p = shift @_;
	return (
	  sprintf("%s %.1f-%.1f %+d", LongTaggedName($p), 
	    $p->{'xw'}, $p->{'xl'}, $p->{'xs'},
	  ),
	  sprintf("<span class=winner>%s</span> <span class=record>%.1f-%.1f %+d</span>", LongTaggedHTMLName($p), 
	    $p->{'xw'}, $p->{'xl'}, $p->{'xs'},
	    )
	);
        },
      'rankcriterion' => sub ($) { my $p = shift @_; return 
	join(';', @$p{qw(xw xl xs)}) 
        },
      },
    # rank players according to cumulative spread 
    'spread' => {
      'unit' => 'player',
       # choose which players are eligible
      'filter' => sub ($$) { #	$_[0]->Active();
	my $p = shift;
	my $prize = shift;
	# determine the first and last 0-based rounds of interest
	my $firstr0 = $prize->{'first'} - 1;
	my $lastr0 = $prize->{'last'} - 1;
	# check to see if our event has spread caps
	my $is_capped = $p->Division()->Tournament()->Config()->HasSpreadCaps();
	# include players unless
	return 0 unless 
	  # they have not played any games 
	  $p->GamesPlayed();
	# cache the player's (possibly capped) spread for subsequent comparison
	$p->{'xs'} = $is_capped
	  ? $p->RoundCappedSpread($lastr0)-$p->RoundCappedSpread($firstr0-1)
	  : $p->RoundSpread($lastr0)-$p->RoundSpread($firstr0-1);
	1;
        },
       # compare them based on spread values cached above in 'filter'
      'compare' => sub ($$) { 
	return $_[1]->{'xs'} <=> $_[0]->{'xs'};
        },
      # how we label this prize
      'prizename' => 'Cumulative Spread',
      # how we render the winner's achievement
      'formatwinner' => sub {
	my $p = shift @_;
	my $prize = shift @_;
        my $ltm = LongTaggedName($p);
        my $lthm = LongTaggedHTMLName($p);
	return (
	  sprintf("%s %+d",
	    $ltm . ($prize->{'eval'} ? (" " . join " ", eval ($prize->{'eval'}) ) : ""),
	    $p->{'xs'}),
	  sprintf("<span class=winner>%s</span> <span class=record>%+d</span>",
	    $lthm . ($prize->{'eval'} ? (" " . join " ", eval ($prize->{'eval'}) ) : ""),
	    $p->{'xs'})
	);
        },
      # data that we use to determine when two ranks are equivalent
      'rankcriterion' => sub ($) { 
	my $p = shift @_;
	return $p->{'xs'};
        },
      },
    'tuffluck' => {
      'initialise' => sub { 
	my $prize = shift;
	my $tournament = shift;
	eval "use TSH::Player::TuffLuck";
	if ($@) {
	  $tournament->TellUser('enomod', 'TSH/Player/TuffLuck.pm', $@);
	  }
        },
      'unit' => 'player',
      'filter' => sub ($$) { 
	my $pp = shift;
	my $prize = shift;
	my ($tl, $lossesp) = $pp->TuffLuck($prize->{rounds}||6);
	$pp->{'xtl'} = $tl || return 0;
	$pp->{'xtls'} = $lossesp;
	return 1;
	},
      # big ratings differences first
      'compare' => sub ($$) { $_[0]{'xtl'} <=> $_[1]{'xtl'} },
      'prizename' => 'Tuff Luck',
      'formatwinner' => sub {
	my $p = shift @_;
	return (
	  sprintf("%s %d = %s",
	    LongTaggedName($p),
	    $p->{'xtl'},
	    join('+', @{$p->{'xtls'}}),
	    ),
	  sprintf("<span class=winner>%s</span> <span class=record>%d = %s</span>",
	    LongTaggedHTMLName($p),
	    $p->{'xtl'},
	    join('+', @{$p->{'xtls'}}),
	    )
	  );
        },
      'rankcriterion' => sub ($) { my $p = shift @_; return $p->{'xtl'}; }
      },
    'totalteam' => {
      'unit' => 'totalteam',
      'initialise' => sub {
	my $prize = shift;
	$prize->{'prizename'} = 'Average Team Record' unless defined $prize->{'prizename'};
        },
      'filter' => sub ($$) { 
	my $teamp = shift;
	my $prize = shift;
	my $w = 0;
	my $l = 0;
	my $s = 0;
	my $n = 0;
	for my $p (@{$teamp->{'members'}}) {
	  $w += $p->Wins();
	  $l += $p->Losses();
	  $s += $p->Spread();
	  $n ++;
	  }
	$teamp->{'wins'} = $w;
	$teamp->{'losses'} = $l;
	$teamp->{'spread'} = $s;
	$teamp->{'count'} = $n;
	my $config = $teamp->{'members'}[0]->Division()->Tournament()->Config();
	if (my $quota = $config->Value('minimum_prize_team')) {
	  return 0 unless $n >= $quota;
	  }
	return 0 unless $n;
	return 1;
	},
      # big ratings differences first
      'compare' => sub ($$) {
	$_[1]->{'wins'}/$_[1]->{'count'}
	  <=> $_[0]->{'wins'}/$_[0]->{'count'}
	|| $_[0]->{'losses'}/$_[0]->{'count'}
	  <=> $_[1]->{'losses'}/$_[1]->{'count'}
	|| $_[1]->{'spread'}/$_[1]->{'count'}
	  <=> $_[0]->{'spread'}/$_[0]->{'count'}
        },
      'prizename' => 'Average Team Record',
      'formatwinner' => sub {
	my $e = shift @_;
	return (
	  sprintf("%s %.2f-%.2f %+.1f",
	    $e->{'name'},
	    $e->{'wins'}/$e->{'count'},
	    $e->{'losses'}/$e->{'count'},
	    $e->{'spread'}/$e->{'count'},
	    ),
	  sprintf("<span class=winner>%s</span> <span class=record>%.2f-%.2f %+.1f</span>",
	    $e->{'name'},
	    $e->{'wins'}/$e->{'count'},
	    $e->{'losses'}/$e->{'count'},
	    $e->{'spread'}/$e->{'count'},
	    )
	  );
        },
      'rankcriterion' => sub ($) { my $e = shift @_; 
	return join(';',
	  $e->{'wins'}/$e->{'count'},
	  $e->{'losses'}/$e->{'count'},
	  $e->{'spread'}/$e->{'count'},
	  ); },
      },
    'upset' => {
      'initialise' => sub { 
	&::Use('TSH::ReportCommand::ExtremeGames');
        },
      'unit' => 'game',
      'filter' => sub ($$) { 
	my $e = shift;
	my $prize = shift;
	return 0 unless TSH::ReportCommand::ExtremeGames::IsUpset($e);
	my $firstr0 = $prize->{'first'} - 1;
	return 0 unless $e->[4] >= $firstr0;
	my $lastr0 = $prize->{'last'} - 1;
	return 0 unless $e->[4] <= $lastr0; 
	$e->[7] = $e->[2]->Division()->RatingSystem();
	$e->[8] = $e->[7]->RatingDifference($e->[6], $e->[5]);
#	warn "$e->[2]{'name'} $e->[8]";
	return 1;
	},
      # big ratings differences first
      'compare' => sub ($$) {
	return $_[0][7]->CompareRatings($_[1][8], $_[0][8]);
#	my $x = $_[0][7]->CompareRatings($_[1][8], $_[0][8]);
#	warn "$x $_[0][2]{'name'} $_[0][8] $_[1][2] $_[1][8]";
#	return $x;
        },
      'prizename' => 'Ratings Upset Win',
      'formatwinner' => sub {
	my $e = shift @_;
	return (
	  sprintf("%s %d-%d=%d, %d-%d vs. %s", 
	    LongTaggedName($e->[2]), 
	    $e->[7]->RenderRating($e->[6]), # opp rating
	    $e->[7]->RenderRating($e->[5]), # player rating
	    $e->[7]->RenderRating($e->[8]), # rating difference
	    $e->[0], # player score
	    $e->[1], # opp score
	    LongTaggedName($e->[3]), # opp name
	    ),
	  sprintf("<span class=name>%s</span> <span class=record>%d-%d=%d, %d-%d vs. %s</span>", 
	    LongTaggedHTMLName($e->[2]), 
	    $e->[7]->RenderRating($e->[6]), # opp rating
	    $e->[7]->RenderRating($e->[5]), # player rating
	    $e->[7]->RenderRating($e->[8]), # rating difference
	    $e->[0], # player score
	    $e->[1], # opp score
	    LongTaggedHTMLName($e->[3]), # opp name
	    ),
	  );
        },
      'rankcriterion' => sub ($) { return $_[0]->[8]; },
      },
    );
  }

sub PageBreak ($$) {
  my $this = shift;
  my $logp = shift;
  $logp->PageBreak();
# $logp->ColumnTitles({'text' => [], 'html' => \@html_titles});
  $this->{'x_page_row'} = 0;
  }

sub PageRowIncrement ($$$) {
  my $this = shift;
  my $logp = shift;
  my $delta = shift;
  
  my $break = $this->{'x_config'}->Value('prizes_page_break') || 1000;

  $this->{'x_page_row'} += $delta;
  if ($this->{'x_page_row'} >= $break and not $this->{'x_at_end'}) {
    $this->PageBreak($logp);
    }
  }

=item $this->ShowPrize($tournament, $logp, $prizeno, $prize);

Add the data for the given prize to the log.

=cut

sub ShowPrize ($$$$) {
  my $this = shift;
  my $tournament = shift;
  my $logp = shift;
  my $prizeno = shift;
  my $prize = shift;
  my $type = $prize->{'type'} || '';
  my $config = $tournament->Config();
  my $show_honourable_mention = $config->Value('show_honourable_mention');
  # normalize prize type
  {
    # longer type names retained for backward compatibility
    $prize->{'type'} = $type if $type =~ s/^(high|low)round(loss|win)$/$1$2/;
  }
# warn "1. type: $type";
  if (my $prize_data = $gPrizeData{$type}) {
    my $dname = $prize->{'division'} || '';
    my $dp;
    if ($dname ne '*') {
      $dp = $tournament->GetDivisionByName($dname) || do {
	$tournament->TellUser('ebaddiv', $dname);
	return ([], []);
	};
      }
    # normalize configuration data
    {
      # 'round' is deprecated in favour of 'first' and 'last'
      my $r1first = $prize->{'round'};
      my $r1last;
      $r1last = $r1first =~ s/-(\d+)// ? $1 : $r1first if $r1first;
      # 'first' and 'last' are guaranteed to be set
      $prize->{'first'} ||= $r1first || 1;
      $prize->{'last'} ||= $r1last || $config->{'max_rounds'};
    }
    # subtype: typically the rank within the category being awarded
    my $subtype = $prize->{'subtype'} || 1;
    my $value = $prize->{'value'} || '?';
    my $groupname = (defined $prize->{'groupname'}) ?  "$prize->{'groupname'} " : '';
    my $initialiser = $prize_data->{'initialise'};
    if (ref($initialiser) eq 'CODE') { &$initialiser($prize, $tournament); }
    my $entriesp;
    my $unit = $prize_data->{'unit'};
    if ($unit eq 'game') {
      my $count = $subtype < 0 ? 1E12 : $subtype + 20; # just to be safe
      $entriesp = TSH::Division::FindExtremeGames::Search(
	$dp, $count, \&{$prize_data->{'filter'}}, \&{$prize_data->{'compare'}},
        $prize)
      }
    elsif ($unit eq 'player') {
      my $compare = $prize_data->{'compare'};
      my $filter = $prize_data->{'filter'};
      my (@players) = $this->FindPlayers($tournament, $dp, $prize);
      $entriesp = [sort $compare grep { &$filter($_, $prize) } @players];
      }
    elsif ($unit eq 'totalteam') {
      my %teams;
      for my $dp ($tournament->Divisions()) {
	next if $dp->Name() ne $dname and $dname ne '*';
	for my $p ($dp->Players()) {
	  if (my $team = $p->Team()) {
	    $teams{$team}{'name'} = $team;
	    push(@{$teams{$team}{'members'}}, $p);
	    }
	  }
        }
      my $compare = $prize_data->{'compare'};
      my (@teams) = keys %teams;
#     die "@$members" if ref($prize->{'members'}) eq 'ARRAY';
      $entriesp = 
        [sort $compare
        grep { &{$prize_data->{'filter'}}($_, $prize) } 
	values %teams];
      }
    my $lastv = undef;
    my $rank = 0;
    my $rankcriterion = $prize_data->{'rankcriterion'};
    my $prize_name = $prize_data->{'prizename'};
    if ($prize->{'prizename'}) 
      { $prize_name = $prize->{'prizename'}; }
    elsif (ref($prize_name) eq 'CODE') 
      { $prize_name = &$prize_name($prize, $tournament); }
    else { 
      $prize_name = DivisionName($tournament, $dname)
        . "${groupname}$prize_name" 
	. Rounds($config, $prize->{'first'}, $prize->{'last'});
      }
    if (($subtype != 1 || $prize_data->{'prizename'} =~ /^(?:Rank|Average Team Record)$/) 
      and not $prize->{'norank'}) {
      $prize_name .= ": ";
      $prize_name .= Ordinal(abs($subtype));
      $prize_name .= ' (from bottom)' if $subtype < 0;
      }

    my $delta;
    my $start;
    my $end;
    if ($subtype >= 0) {
      $delta = 1;
      $start = 0;
      $end = $#$entriesp+1;
      }
    else {
      $delta = -1;
      $start = -1;
      $end = -@$entriesp-1;
      }
#   warn "$prize_data->{'prizename'} entries=@{[$#$entriesp+1]} $subtype $delta $start $end" if $prize_data->{'prizename'} eq 'High Win' and $prize->{'first'} == 12;
    if ($this->{'prz_nowinner'} ||$prize->{'winner'}) {
      $this->RowBufferAdd($prize->{'order'}, 1, sub(){
	$this->WritePrizeRow($logp, $prizeno, $prize_name, $value, $prize->{'winner'});
	push(@{$this->{'csv'}}, [$prizeno,'','',$prize->{'winner'},$prize_name, $value]);
	push(@{$this->{'slides'}}, ['',$prize_name,$prize->{'winner'}, $value]);
        });
      }
    elsif (@$entriesp) {
      my @winners;
      # loop until we find one or more winners
      while (1) {
	my $someone_excluded = 0;
	# count winners at current rank
	for (my $i = $start; $i != $end; $i += $delta) {
	  my $changed = 0; # true if rankcriterion value changed
	  my $e = $entriesp->[$i];
	  my $v = &$rankcriterion($e);
#          warn scalar(@$entriesp)." $prize_data->{'prizename'} $subtype $i $v $e->{'name'}";
	  if ((!defined $lastv) || $v ne $lastv) { 
	    $rank = $i < 0 ? $i : $i + 1; $lastv = $v; $changed++; 
	    last if @winners;
	    }
# 	  print "A: $i $rank $subtype $changed $v @{[$e->Name()]}\n" if $prize_data->{'prizename'} eq 'Rank'; # and $prize->{'first'} == 12;
	  if (($rank-$subtype)*$delta >= 0) { # if current entry is of at least the correct rank
# 	    print "B: rank is correct\n" if $prize_data->{'prizename'} eq 'Rank'; # and $prize->{'first'} == 12;
	    if (my $excludes = $prize->{'exclusive'}) { # check to see if it already won an exclusive prize
	      my $excluded = 0;
	      for my $exclude (split(/,/, $excludes)) {
		my $p;
		if ($unit eq 'player') { $p = $e; }
		elsif ($unit eq 'game') { $p = $e->[2]; }
		else { warn "Can't check exclusivity for prizes of entry type $unit"; next; }
		if ($this->{'xclude'}{$exclude}{$p->FullID()}) {
		  if ($show_honourable_mention) { # experimental code, still under development
		    # one known bug is that if someone is excluded from winning first place in a category, then the actual first place winner gets listed as HM for second.
		    my ($text,$html) = &{$prize_data->{'formatwinner'}}($e, $prize);
		    $this->RowBufferAdd($prize->{'order'}, 1, sub(){
		      $logp->WriteRow(
			[$prizeno, "$prize_name; Hon. Mention: $text"],
			[$prizeno, $prize_name, 'Hon. Mention', $html]
			);
		      push(@{$this->{'csv'}}, [$prizeno, $p->Division()->Name(), $p->ID(), $text, $prize_name, 'Hon. Mention']);
		      push(@{$this->{'slides'}}, [$p->PhotoURL(), $prize_name, $html, "Hon. Mention"]);
		      });
		    }
#   		  warn "Skipping for first=$prize->{'first'} $prize_data->{'prizename'}: ".$e->FullID();
		  $excluded = $someone_excluded = 1;
		  }
		}
#	      print "excluded=$excluded\n" if $prize_data->{'prizename'} eq 'High Win' and $prize->{'first'} == 12;
              next if $excluded;
	      }
	    push(@winners, $i);
	    }
	  } # for $i = $start to $end by $delta
# 	warn "winners:@winners; someone_excluded:$someone_excluded\n" if $prize_data->{'prizename'} eq 'High Win' and $prize->{'first'} == 12;
	# if we found at least one winner, we're done
	last if @winners;
	last unless $someone_excluded;
	$subtype += $delta;
	}
      # no winners yet
      if (@winners == 0) {
	$this->RowBufferAdd($prize->{'order'}, 1, sub(){
	  $logp->WriteRow(
	    [$prizeno, "$prize_name; Value: $value; Winner: "],
	    [$prizeno, $prize_name, $value, '&nbsp;']
	    );
	  push(@{$this->{'csv'}}, [$prizeno, '', '', '', $prize_name, $value]);
	  push(@{$this->{'slides'}}, ['', $prize_name, '', $value]);
	  });
        }
      # the one winner we wanted
      elsif (@winners == 1) {
	my $winner = $entriesp->[$winners[0]];
	my $wp = $winner;
	if (ref($wp) eq 'ARRAY') { # prize unit was game, not player
	  $wp = $wp->[2];
	  }
	my ($text,$html) = &{$prize_data->{'formatwinner'}}($winner, $prize);
	if (my $excludes = $prize->{'exclusive'}) {
	  for my $exclude (split(/,/, $excludes)) {
	    $this->{'xclude'}{$exclude}{$wp->FullID()}++;
	    }
	  }
	$this->RowBufferAdd($prize->{'order'}, 1, sub(){
	  $logp->WriteRow(
	    [$prizeno, "$prize_name; Value: $value; Winner: $text"],
	    [$prizeno, $prize_name, $value, $html]
	    );
	  my $dname = eval { $winner->Division()->Name() } || 'no-division';
	  my $id = eval { $winner->ID() } || 'no-id';
	  push(@{$this->{'csv'}}, [$prizeno, $dname, $id, $text, $prize_name, $value]);
	  push(@{$this->{'slides'}}, [eval { $winner->PhotoURL() } // '', $prize_name, $html, $value]);
	  });
        }
      # multiple shared winners
      else {
	my $nwinners = scalar(@winners);
	$this->RowBufferAdd($prize->{'order'}, 0, sub(){
	  $logp->ColumnAttributes([("rowspan=$nwinners") x 3]);
	  });
        my $slidesSeen = 0;
	for my $i (0..$#winners) {
	  if ($i == 1) {
	    $this->RowBufferAdd($prize->{'order'}, 0, sub(){
	      $logp->ColumnAttributes([]);
	      $logp->ColumnClasses([qw(winner)]);
	      });
	    }
	  my $winner = $entriesp->[$winners[$i]];
	  my $p;
	  if ($unit eq 'player') { $p = $winner; }
	  elsif ($unit eq 'game') { $p = $winner->[2]; }
	  my ($text,$html) = &{$prize_data->{'formatwinner'}}($winner, $prize);
	  $this->RowBufferAdd($prize->{'order'}, 1, sub(){
	    $logp->WriteRow(
	      ["$prizeno (tie)", "$prize_name; Value: $value (shared); Winner: $text"],
	      $i == 0 
		? ["$prizeno (tie)", $prize_name, "$value (shared)", $html]
		: [$html]
	      );
	    my $dname = eval { $p->Division()->Name() } || 'no-division';
	    my $id = eval { $p->ID() } || 'no-id';
	    push(@{$this->{'csv'}}, [$prizeno, $dname, $id, $text, $prize_name, "$value (shared)"]);
	    if ($slidesSeen) {
	      $this->{slides}[-1][2] .= "<br>$html";
	      $this->{slides}[-1][3] .= " (shared)" unless $this->{slides}[-1][3] =~ / \(shared\)/;
	      }
	    else {
	      $slidesSeen++;
	      push(@{$this->{slides}}, [$p->PhotoURL(), $prize_name, $html, $value]);
	      }
	    if (my $excludes = $prize->{'exclusive'}) {
	      for my $exclude (split(/,/, $excludes)) {
		$this->{'xclude'}{$exclude}{$p->FullID()}++;
		}
  #	    warn "Exclusive prizes may not be awarded correctly when ties occur.\n";
	      }
	    });
	  }
	$this->RowBufferAdd($prize->{'order'}, 0, sub(){
	  $logp->ColumnClasses(\@column_classes);
	  });
        }
      }
    else {
      $this->RowBufferAdd($prize->{'order'}, 1, sub(){
	$this->WritePrizeRow($logp, $prizeno, $prize_name, $value, '');
	push(@{$this->{'csv'}}, [$prizeno,'','','',$prize_name, $value]);
        });
      }
    }
  elsif ($type eq 'average') { # Diane Firstman's prize
    my $dname = $prize->{'division'} || '';
    my $dp = $tournament->GetDivisionByName($dname) || do {
      $tournament->TellUser('ebaddiv', $dname);
      return ([],[]);
      };
    my $lastwl = 999;
    my $lastspread = 0;
    my $subtype = $prize->{'subtype'} || 1;
    my $i = 0;
    my $value = $prize->{'value'} || '?';
    my $rank = 0;
    for my $p (sort {
      abs($a->Wins()-$a->Losses()) <=> abs($b->Wins()-$b->Losses())
      || abs($a->Spread()) <=> abs($b->Spread())
      } $dp->Players()) {
      next unless $p->Active();
      my $changed = 0;
      $i++;
      my $wl = abs($p->Wins()-$p->Losses());
      my $spread = abs($p->Spread());
      if ($wl != $lastwl || $lastspread != $spread) {
	$changed++;
	$lastwl = $wl;
	$lastspread = $spread;
	$rank = $i;
#	warn "rank=$rank wl=$lastwl p=$p->{'name'}\n";
        }
      if ($rank == $subtype) {
	$prizeno = '...' unless $changed;
	my $pname = sprintf("%s %g-%g %+d", LongTaggedName($p), $p->Wins(),
	  $p->Losses(), $p->Spread());
	my $phname = sprintf("%s %g-%g %+d", LongTaggedHTMLName($p), $p->Wins(),
	  $p->Losses(), $p->Spread());
	my $prizename = "Division $dname Most Average Rank: $subtype";
	$this->RowBufferAdd($prize->{'order'}, 1, sub(){
	  $this->WritePrizeRow($logp, $prizeno, $prizename, $value, $pname);
	  # TODO: check why this says shared 
	  push(@{$this->{'csv'}}, [$prizeno, $p->Division()->Name(), $p->ID(), $pname, $prizename, "$value (shared)"]);
	  push(@{$this->{'slides'}}, [$p->PhotoURL(), $prizename, $phname, $value]);
	  });
        }
      }
    }
  elsif ($type eq 'signup') {
    my $subtype = $prize->{'subtype'} || '';
    my $value = $prize->{'value'} || '?';
    my $winner = $prize->{'winner'} || '?';
    my $p;
    $winner =~ s/\[(\w+)\]\s*/
      my $s = $1;
      my $orig = $&;
      my ($dp, $pn) = $tournament->CheckMatchDivPN($s);
      $s = $orig;
      if ($pn and ref($dp)) {
        if ($p = $dp->Player($pn)) {
	  $s = '';
	  }
        }
      $s;
      /ex;
    my ($textWinner, $htmlWinner);
    if ($p) {
      $textWinner = LongTaggedName($p) . $winner;
      $winner =~ s/^[,;\s]*/ /;
      $htmlWinner = LongTaggedHTMLName($p) . "<span class=record>$winner</span>";
      }
    else {
      $textWinner = $htmlWinner = $winner;
      }
    $this->RowBufferAdd($prize->{'order'}, 1, sub(){
      $this->WritePrizeRow($logp, $prizeno, $subtype, $value, $textWinner);
      push(@{$this->{'csv'}}, [$prizeno, '', '', $textWinner, $subtype, "$value (shared)"]);
      push(@{$this->{'slides'}}, [$p ? $p->PhotoURL() : '', $subtype, $htmlWinner, $value]);
      });
    }
  elsif ($type eq 'separator') {
    my $width = $this->{'prz_nowinner'} ? 3 : 4;
    $this->RowBufferFlush($logp);
    $logp->ColumnAttributes(["colspan=$width"]);
    $logp->WriteRow(['---'], ['&nbsp;']);
    $logp->ColumnAttributes([]);
    $this->PageRowIncrement($logp, 1);
    }
  elsif ($type eq 'note') {
    my $width = $this->{'prz_nowinner'} ? 3 : 4;
    $this->RowBufferFlush($logp);
    $logp->ColumnAttributes(["colspan=$width"]);
    my $note = $prize->{'note'};
    $logp->WriteRow(['*', $note], [$note]);
    $logp->ColumnAttributes([]);
    $this->PageRowIncrement($logp, 1);
    }
  elsif ($type eq 'title') { # appears only in slide show
    push(@{$this->{'slides'}}, [$config->Value('prize_title_logo')||'', "<span class=title>$prize->{'note'}</span>", '', '']);
    }
  elsif ($type eq 'break') {
    my $width = $this->{'prz_nowinner'} ? 3 : 4;
    $this->RowBufferFlush($logp);
    $this->PageBreak($logp);
    }
  }

sub WritePrizeRow($$$$$$) {
  my $this = shift;
  my $logp = shift;
  my $prize_number = shift;
  my $prize_name = shift;
  my $prize_value = shift;
  my $prize_winner = shift;
  if ($this->{'prz_nowinner'}) {
    $logp->WriteRow([$prize_number, "$prize_name; Value: $prize_value"],
      [$prize_number, $prize_name, $prize_value]);
    }
  else {
    $logp->WriteRow([$prize_number, "$prize_name; Value: $prize_value; Winner: $prize_winner"],
      [$prize_number, $prize_name, $prize_value, $prize_winner||'&nbsp;']);
    }
  }

=back

=cut

=head1 BUGS

Not easy to configure.

More use should be made of FindExtremeGames and TSH::Utility::DoOneRank.

Should switch to using modern interface for Log.

Should be using the new Class() routine to designate prize classes.

Should allow multidivision syntax in prize data.

Should parse monetary value out of prize value, and use to automate 
class prizes.

The rest of the routines in gPrizeData should be moved to subclasses of 
TSH::ReportCommand::ExtremePlayers
or TSH::ReportCommand::ExtremeGames,
so that they can be shared with other commands.
Have tried doing this for a start with highratingchange.

=cut

1;
