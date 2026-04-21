#!/usr/bin/perl

use warnings;
use strict;
BEGIN {
  if (defined $ENV{'HOME'}) {
    eval { use lib "$ENV{'HOME'}/lib/perl" };
    }
  }
use lib './lib/perl';
use lib '.';

# tourney.pl - perform Scrabble tournament calculations

# Copyright (C) 1996-2006 by John J. Chew, III <jjchew@math.utoronto.ca>
# All Rights Reserved

# $Id: tourney.pl,v 1.10 2005/06/26 03:09:21 jjc Exp jjc $

# 1998-10-20 byes scoring 0 points are not recorded as ties
#
# $Log: tourney.pl,v $
# Revision 1.10  2005/06/26 03:09:21  jjc
# ! accept extended .t files
#
# Revision 1.9  2005/05/24 21:24:19  jjc
# ! Byes now display scores to distinguish forfeit wins/losses
# ! Some additional multipart names added
#
# Revision 1.8  2004/08/24 17:51:19  jjc
# ! changed -t to conform with Scrabble News requirements
#
# Revision 1.7  2004/08/24 16:39:47  jjc
# + Added -t
#
# Revision 1.6  2004/08/08 23:23:27  jjc
# + added -N option
#
# Revision 1.5  2004/07/24 02:19:34  jjc
# + added -e tor80
#
# Revision 1.4  2003/11/02 18:13:35  jjc
# ! minor bug fix
#
# Revision 1.3  2003/11/02 18:08:06  jjc
# ! code cleanup
# + credits listed in reports
#
# Revision 1.2  2003/11/02 17:21:16  jjc
# + added NSC78 credit option
# + added NSC78 credit support to scorecard option
#
# Revision 1.1  2003/10/28 04:46:41  jjc
# Initial revision

## include libraries

if ($^O eq 'MacOS') { use lib ':'; }

use Ratings;
require 'getopts.pl';
require 'ratings.pl';
require 'ratings2.pl';

our($gVersion);

# version number of this script
$gVersion     = '1.11';
# 1.2.1: apostrophe okay in player name
# 1.3: oldstyle credits
# 1.3.1: code cleanup
# 1.4: credits shown in reports
# 1.4.1: bug fix
# 1.5: code cleanup, lifeg, cross-tables
# 1.5.1: -C bug fix
# 1.5.2: use etc/cume in reports when available
# 1.6: added -T option

# prototypes

sub CalculateSeeds ($);
sub Center ($$);
sub Initialise ();
sub Main ();
sub Online ($);
sub ParseCommandLine ();
sub ProcessFile ($);
sub ProcessOpenFile ($);
sub ReadFile ($);
sub Usage ();
sub WriteClub3 ($);
sub WriteCrossTables ($);
sub WriteNSA ($$);
sub WritePairings ($);
sub WriteRatingsData ($);
sub WriteReport ($);
sub WriteSimpleTable ($);
sub WriteSS ($$);
sub WriteTransfer ($);

Main;

=over 4

=cut

# CalculateSeeds $players
sub CalculateSeeds ($) {
  my $ps = shift;
  my($id, $last, $lastseed, $seed) = (0, -1, 1, 0);
  for my $id (sort {$ps->[$b]{'oldr'} <=> $ps->[$a]{'oldr'}} 0..$#$ps) { 
    $seed++;
    if ($ps->[$id]{'oldr'} != $last) 
      { $lastseed=$seed; $last=$ps->[$id]{'oldr'}; }
    $ps->[$id]{'seed'} = $lastseed;
    }
  }

sub Main () {
  Initialise;
  our(%ONLINE, $opt_O, $opt_v);
  dbmopen(%ONLINE, 'online', 0600) unless $opt_O;
  if ($opt_v) { print "$0: version $gVersion.\n"; exit 0; }
  elsif ($#ARGV == -1) { ProcessOpenFile *STDIN; }
  else { for $ARGV (@ARGV) { ProcessFile $ARGV; } }
  dbmclose(%ONLINE) unless $opt_O;
  }

sub Center ($$) {
  my $line = shift;
  my $length = shift;
  (' ' x (($length - length($line))/2)) .  $line;
  }

sub Initialise () {
  our($opt_A, $opt_C, $opt_w);
  ParseCommandLine;
  # the following two lines have to be in the following order for -C to work
  &ratings2'UseAccelerationBonuses(!$opt_A);
  &ratings2'UseClubDivisor($opt_C);
  # maximum number of times to iterate when calculating initial ratings
  &ratings2'SetMaximumIterations(25);

  # length of output lines
  our $gLineLength = $opt_w;
  }

# $full_name = Online $real_name;
sub Online ($) { 
  our(%ONLINE);
  defined $ONLINE{$_[0]} ? "$_[0] ($ONLINE{$_[0]})" : $_[0]; 
  }

sub ParseCommandLine () {
  our(@ARGV, $opt_A, $opt_b, $opt_C, $opt_N, $opt_O, $opt_c, $opt_d,
    $opt_e, $opt_f, $opt_n, $opt_p, $opt_r, $opt_s, $opt_t, $opt_T,
    $opt_v, $opt_w, $opt_x, $opt_X);
  # Classic MacOS support
  my @argv = split(/:/, $0); @argv = split(/\s+/, pop @argv); 
  shift(@argv); unshift(@ARGV, @argv);
  {
    no warnings;
    &Getopts('Ab:Ccd:e:fnNOp:rs:tTvSw:xX-:') || Usage;
  }
  my $n = 0; 
  $opt_A = 0 unless defined $opt_A;
  $opt_w = 80 unless defined $opt_w;
  $opt_b = 50 unless defined $opt_b;
  $opt_C = 0 unless defined $opt_C;
  $opt_f = 0 unless defined $opt_f;
  $opt_e = 'wls' unless defined $opt_e;
  $opt_O = 1 unless defined $opt_O;
  defined $opt_c && $n++;
  defined $opt_n && $n++;
  defined $opt_N && $n++;
  defined $opt_p && $n++;
  defined $opt_r && $n++;
  defined $opt_s && $n++;
  defined $opt_t && $n++;
  defined $opt_T && $n++;
  defined $opt_v && $n++;
  defined $opt_x && $n++;
  defined $opt_X && $n++;
  $n == 0 ? ($opt_r = 1) : $n > 1 && Usage;
  }

# ProcessFile $filename
sub ProcessFile ($) { my $filename = shift;
  my $fh;
  if (open($fh, '<', $filename)) { ProcessOpenFile $fh; close $fh; }
  else { warn "Can't read file \`$filename': $!\n"; }
  }

# ProcessOpenFile $fh; 
sub ProcessOpenFile ($) { 
  my $fh = shift;
  our ($opt_c, $opt_n, $opt_p, $opt_r, $opt_s, $opt_t, $opt_T,
    $opt_x, $opt_N, $opt_X);
  my $tourney = ReadFile $fh;
  if ($opt_x) { WriteCrossTables $tourney; }
  elsif ($opt_X) { WriteRatingsData $tourney; }
  else { 
    my (@divisions) = $tourney->Divisions();
    for my $dp (@divisions) {
      if (@divisions > 1) {
	print "Division $dp->{'name'}\n\n";
        }
      defined $opt_c ? (WriteClub3 $dp) :
      defined $opt_r ? (WriteReport $dp) :
      defined $opt_n ? (WriteNSA $dp, 0) :
      defined $opt_N ? (WriteNSA $dp, 1) :
      defined $opt_t ? (WriteSimpleTable $dp) :
      defined $opt_T ? (WriteTransfer $dp) :
      defined $opt_p ? (WritePairings $dp) 
	: WriteSS $dp, $opt_s;
      print "\n" if @divisions > 1;
      }
    }
  }

sub ReadFile ($) { 
  my $fh = shift;

  my $tp = new Tourney;
  $tp->Read($fh);
  $tp->Analyse();
  return $tp;
  }

sub SortByCredits {
  $b->{'credits'}   <=> $a->{'credits'} || 
  $b->{'wins'} <=> $a->{'wins'} || 
  $a->{'sgames'}   <=> $b->{'sgames'} || 
  $b->{'afor'}   <=> $a->{'afor'} || 
  $a->{'aagn'}   <=> $b->{'aagn'} || 
  $b->{'oldr'}   <=> $a->{'oldr'} || 
  $b->{'name'}   cmp $a->{'name'} 
  }

sub SortByWinsAndCume {
  $b->{'wins'}   <=> $a->{'wins'} || 
  $a->{'sgames'}   <=> $b->{'sgames'} || 
  ((defined $a->{'cume'}) 
    ? $b->{'cume'} <=> $a->{'cume'}
    : $b->{'spread'} <=> $a->{'spread'}
  ) || 
  $b->{'oldr'}   <=> $a->{'oldr'} || 
  $b->{'name'}   cmp $a->{'name'} 
  }

sub Usage () { 
  die "Usage: $0 [-A] [-b spread] [-C] [-d r] [-e nsc78|wls] [-f] [-O] [-S] [-c|-n|-N|-r|-s pn|-p formula|-t|-T|-v] file...\n"
     ."  -A     do not use acceleration or feedback points\n"
     ."  -b     set bye spread (default: +/-50)\n"
     ."  -c     output in Club #3's format\n"
     ."  -C     use club tournament multipliers\n"
     ."  -d r   divide tournament after round r for ratings purpose\n"
     ."  -e era specify time period\n"
     ."           nsc78  50-point credits\n"
     ."           tor80  spread capped at 200\n"
     ."           wls    W-L and spread\n"
     ."  -f     use fixed player ids\n"
     ."  -n     output NSA ratings input files\n"
     ."  -N     output NSA ratings input files without inverting names\n"
     ."  -O     suppress online names\n"
     ."  -p f   output pairings according to one of the following formulae:\n"
     ."           koth - King of the Hill\n"
     ."  -r     output regular readable reports\n"
     ."  -s pn  output a scoresheet for a player specified by number\n"
     ."  -S     suppress scores\n"
     ."  -t     output a simple table of rankings, W-L and spread\n"
     ."  -T     output ratings transfer report\n"
     ."  -v     display version number of this script\n"
     ."  -w n   wrap at column n (default 80)\n"
     ."  -x     output NSA cross-table\n"
     ;
  }

sub WriteClub3 ($) { 
  my $dp = shift;
  my $ps = $dp->{'players'};
  our ($opt_S);

  &ratings2::CalculateRatings($ps, 'oldr', 1, 'newr', 10000, 'ewins');
  my @ranked = sort { 
    $b->{'newr'} <=> $a->{'newr'} || 
    $a->{'name'} cmp $b->{'name'} 
    } @$ps;

  printf "%-$dp->{'tourney'}{'maxname'}s   W-L   Sprd OldR NewR +-R PFor PAgn HiG\n\n",
    'Name';

  for my $p (@ranked) {
    if ($p->{'games'}) {
      printf "%-$dp->{'tourney'}{'maxname'}s %3g-%-3g", 
	$p->{'fname'}, $p->{'ewins'}, $p->{'rgames'}-$p->{'ewins'};
      printf " %+4d", $p->{'spread'} unless $opt_S;
      if ($p->{'oldr'}) { 
	printf " %4d %4d %+3d ", $p->{'oldr'}, $p->{'newr'}, $p->{'newr'}-$p->{'oldr'}; 
	}
      else { printf " n.r. %4d     ", $p->{'newr'}; }
      printf "%4d %4d %3d", $p->{'tfor'}, $p->{'tagn'}, $p->{'hi'} 
	unless $opt_S;
      print "\n";
      }
    else {
      printf "%-$dp->{'tourney'}{'maxname'}s                   %4d\n",
        $p->{'fname'}, $p->{'newr'};
      }
    }
  }

sub WriteCrossTables ($) {
  my $tp = shift;
  my $dsp = [$tp->Divisions()];
  my @collate;
  my $rounds = $tp->{'rounds'};
  my $ranksize = $tp->{'maxnum'} > 3 ? $tp->{'maxnum'} : 3;
  my $oppsize = $tp->{'maxnum'} > 2 ? $tp->{'maxnum'} : 2;
  my $namelength = $tp->{'maxname'} > 23 ? $tp->{'maxname'} : 23;
  my $crosslength = $rounds * (3 + $oppsize) - 1;
  my $linelength = $ranksize + 2 + $namelength + 1 + 6 + 1 
    + $crosslength + 1 + 4 + 5 + 2 + 6 + 1 + 6;
  &ratings2::UseClubDivisor($tp->{'event_type'} eq 'LCT');
  for my $dp (@$dsp) {
    push(@collate, []);
    my $psp = $dp->{'players'};
    die "no players" unless @$psp;
    my @splits = &ratings2::CalculateSplitRatings($psp,
      $#{$psp->[0]{'scores'}}+1,
      {
	'ewins' => 'ewins',
	'id' => 'id',
	'lifeg' => 'totalg',
	'newr' => 'newr',
	'oldr' => 'oldr',
	'rgames' => 'rgames',
	'pairings' => 'opps',
	'scores' => 'scores',
	'splitr' => 'splitr',
      });
    for my $si (0..$#splits) {
      my $split = $splits[$si];
      my $s = '';
      my ($first_round_0, $last_round_0) = @{$splits[$si]};
      my $header_format = "%${ranksize}s  %-${namelength}s %6s "
	. "%-${crosslength}s %4s %5s  %6s %s";
      $s .= sprintf($header_format,
	'', '', ' OLD  ', '', '', '', ' PERF ', '  NEW') . "\n";
      my $results_header = 'RESULTS';
      if ($dp->{'name'}) {
	my $name = $dp->{'name'};
	$name =~ s/^[A-Z]/ord(uc $&)-ord('A')+1/e;
	$results_header = "DIVISION $name $results_header";
	}
      if (@splits > 1) {
	$results_header .= sprintf(": RDS. %d-%d", 
	  $first_round_0+1,
	  $last_round_0+1);
	}
      $s .= sprintf($header_format, '', 'NAME', 'RATING',
	(Center $results_header, $crosslength), 'WINS', 'SPR',
	'RATING', 'RATING') . " \n"; # space, sic
      &ratings2::CalculateSegmentStandings($psp,
	$first_round_0, $last_round_0, {
	'cume' => 'segcume',
	'games' => 'seggames',
	'pairings' => 'opps',
	'scores' => 'scores',
	'wins' => 'segwins',
	});
      for my $p (@$psp) 
        { $p->{'cume'} = $p->{'segcume'} unless defined $p->{'cume'}; }
      my (@sorted) = sort { 
	$b->{'segwins'} <=> $a->{'segwins'}
	|| $a->{'seggames'} <=> $b->{'seggames'}
	|| $b->{'cume'} <=> $a->{'cume'}
        } @$psp;
      for my $pn0 (0..$#sorted) { $sorted[$pn0]{'segrank'} = $pn0+1; } 
      for my $pn0 (0..$#sorted) {
	my $p = $sorted[$pn0];
	my $cross = '';
	my $scoresp = $p->{'scores'};
	my $opps = $p->{'opps'};
	my $sumor = 0;
	my $nor = 0;
	my $name = $p->{'name'};
	unless ($name =~ /,/) {
	  $name =~ s/^(\S+) (\S+(?: [A-Z])?)$/$1, $2/ 
	    || $name =~ s/^(\S+) (HEATHER JEAN)$/$1, $2/ 
	    || die "Can't split name: $name\n";
	  }
	for my $r0 ($first_round_0..$last_round_0) {
	  my $on = $opps->[$r0];
	  if ($on >= 0) { 
	    my $ms = $scoresp->[$r0];
	    my $op = $psp->[$on];
	    my $os = $on >= 0 ? $op->{'scores'}[$r0] : 0;
	    $cross .= sprintf(" %s-%0${oppsize}d",
	      ('T', 'W', 'L')[$ms<=>$os],
	      $op->{'segrank'});
	    if ($op->{'oldr'}) {
	      $sumor += $op->{'oldr'};
	      $nor++;
	      }
	    else {
	      $sumor += $op->{'newr'};
	      $nor++;
	      }
	    }
	  else {
	    $cross .= sprintf("  -%${oppsize}s", '');
	    }
	  }
        my $wins = $p->{'segwins'}; $wins =~ s/\.5$/+/ or ($wins .= ' ');
	my $pr = $nor ? &ratings2::CalculateHomanPR($p->{"ewins$si"}/$p->{"rgames$si"},
	    $sumor/$nor)
	    : 0;
# if ($nor) { warn $p->{'name'} . ' ' . &ratings2::CalculateHomanPR($p->{"ewins$si"}/$p->{"rgames$si"}, $sumor/$nor) . "\n"; }
	$s .= sprintf("%${ranksize}d. %-${namelength}s  %4d %-${crosslength}s %4s %+5d   %4s   %4d\n",
	  $pn0+1,
	  uc($name),
	  $p->{'oldr'},
	  $cross,
	  $wins,
	  $p->{'cume'},
	  $p->{'oldr'} ? $pr : '',
	  $p->{'newr'},
	  );
        }
      push(@{$collate[-1]}, $s);
      }
    }
  my $banner = Center(uc("$tp->{'event_name'} $tp->{'event_date'}"),
    $linelength) . "\n";
  $banner .= Center(uc('Local Club Tournament'), $linelength) . "\n"
    if $tp->{'event_type'} eq 'LCT';
  $banner .= "\n\n";
  for (my $split = 0; ; $split++) {
    my $found = 0;
    for my $divsplit (@collate) {
      my $s = $divsplit->[$split];
      if ($s) {
	print "$banner\n" unless $found;
	$found = 1;
	print $s;
	print "\n\n\n";
        }
      }
    last unless $found;
    }
  }

sub WriteNSA ($$) { 
  my $dp = shift;
  my $noinvert = shift;
  my $ps = $dp->{'players'};

  for my $pn (0..$#$ps) { 
    my $p = $ps->[$pn]; 
    printf "%d ", $pn+1;
    my $name = $p->{'name'};
    $name =~ s/,//;
    if ($noinvert) { print "$name/$p->{'spread'}:"; }
    else {
      my @n = split(/ /, $name);
      if ($#n != 1) {
	if ($p->{'name'} =~ /^(?:\w+ [^o] \w+|mary ellen bergeron|robin pollock daniel|ida ann shapiro)$/i) 
	  { @n = ("$n[0] $n[1]", $n[2]); }
	elsif ($p->{'name'} =~ /^(?:muriel de silva|sherrie saint john|muriel sparrow reedy|john van zeyl|john van pelt|annie st denis|sharon crawford mackay)$/i) 
	  { @n = ($n[0], "$n[1] $n[2]"); }
	elsif ($p->{'name'} =~ /^(?:verna richards berg)$/i) 
	  { @n = ($n[0], "$n[2] $n[1]"); }
	elsif ($p->{'name'} =~ /^(?:james l kille jr)$/i) 
	  { @n = ("$n[0] $n[1] $n[3]", "$n[2]"); }
	elsif ($p->{'name'} =~ /^eugene van de walker$/i) 
	  { @n = ('eugene', 'van de walker'); }
	else { die "Don't know how to parse: $p->{'name'}\n"; }
	}
      print "\U@n[1,0]/$p->{'spread'}:";
      }
    my $os = $p->{'opps'};
    for my $round (0..$#$os) {
      my $o = $os->[$round];
      if ($o == -1) { print " B"; } # bye
      else {
	print ' ', 
	  ('L','T','W')[($p->{'scores'}[$round]<=>$ps->[$o]{'scores'}[$round])+1],
	  $o+1;
	}
      }
    print "\n";
    }
  }

sub WritePairings ($) { 
  my $dp = shift;
  my $ps = $dp->{'players'};
  our($opt_e, $opt_p);
  my $pfmt = '%' . (length($#$ps+1)+1) . 'd';
  if ($opt_p =~ /^koth$/i) {
    print "# automatically generated KOTH pairings\n";
    my @ranked = $opt_e eq 'nsc78' 
      ? (sort SortByCredits @$ps)
      : (sort SortByWinsAndCume @$ps);
    for my $i (0..$#ranked) {
      my $p = $ranked[$i];
      my $opp = sprintf($pfmt, $ranked[$i^1]->{'id'}+1);
      $p->{'input'} =~ s/;/$opp;/;
      }
    for my $p (@$ps) {
      print $p->{'input'};
      }
    }
  }

sub WriteRatingsData ($) {
  my $tp = shift;
  my $dsp = [$tp->Divisions()];
  my $rounds = $tp->{'rounds'};
  my %players;
  &ratings2::UseClubDivisor($tp->{'event_type'} eq 'LCT');
  for my $dp (@$dsp) {
    my $psp = $dp->{'players'};
    die "no players" unless @$psp;
    my @splits = &ratings2::CalculateSplitRatings($psp,
      $#{$psp->[0]{'scores'}}+1,
      {
	'ewins' => 'ewins',
	'lifeg' => 'totalg',
	'newr' => 'newr',
	'oldr' => 'oldr',
	'rgames' => 'rgames',
	'pairings' => 'opps',
	'scores' => 'scores',
	'splitr' => 'splitr',
      });
    for my $p (@$psp) {
      my $name = uc $p->{'name'};
      $name =~ s/,//;
      $players{$name} = {
	'new' => $p->{'newr'},
	'games' => 0,
        };
      for my $si (0..$#splits) {
	$players{$name}{'games'} += $p->{"rgames$si"}; 
	}
      }
    }
  for my $name (sort keys %players) {
    my $p = $players{$name};
    print "$name $p->{'new'} $p->{'games'} $p->{'new'}\n";
    }
  }

sub WriteReport ($) { 
  my $dp = shift;
  my $ps = $dp->{'players'};
  our($gLineLength, $opt_d, $opt_e, $opt_f, $opt_O, $opt_S);

  CalculateSeeds $ps;
  if ($opt_d) {
    &ratings2'CalculateRatings($ps, 'oldr', 1, 'midr', $opt_d, 'ewins1');
    &ratings2'CalculateRatings($ps, 'midr', $opt_d+1, 'newr', 10000, 'ewins2');
    }
  else {
    &ratings2::CalculateSplitRatings($ps, $#{$ps->[0]{'opps'}}+1, {
      'ewins' => 'ewins',
      'id' => 'id',
      'lifeg' => 'totalg',
      'newr' => 'newr',
      'oldr' => 'oldr',
      'rgames' => 'rgames',
      'pairings' => 'opps',
      'scores' => 'scores',
      'splitr' => 'splitr',
      });
    }

  print 'Rank';
  print ' Seed' unless $opt_e eq 'nsc78';
  printf " %-$dp->{'tourney'}{'maxname'}s",
    $opt_O ? 'Name' : 'Name (online)';
  print ' Creds' if $opt_e eq 'nsc78';
  print '  Won-Lost'; 
  print  " Cumul" unless $opt_S;
  print " SOpEW";
  print  " OldR NewR Chng" unless $opt_e eq 'nsc78';
  print  " For Agn  Hi" unless $opt_S;
  print "\n"; 

  my @ranked = $opt_e eq 'nsc78' 
    ? (sort SortByCredits @$ps)
    : (sort SortByWinsAndCume @$ps);
  my $i = 1;
  my $rank = 1;
  my $last_spread = -10000;
  my $last_wins = -10000;
  my $last_games = -10000;

  # print standings
  for my $p (@ranked) {
    next if $p->{'fname'} eq 'F NORD';
    my $spread = (defined $p->{'cume'}) ? $p->{'cume'} : $p->{'spread'};
    if ($p->{'wins'} != $last_wins || $spread != $last_spread
      || $p->{'sgames'} != $last_games) {
      $last_wins = $p->{'wins'}; 
      $last_games = $p->{'sgames'}; 
      $last_spread = $spread;
      $rank = $i;
      }
    printf '%3d ', $rank;
    printf "  %3d", $p->{'seed'} unless $opt_e eq 'nsc78';
    printf " %-$dp->{'tourney'}{'maxname'}s", $p->{'fname'};
    printf ' %5.1f', $p->{'credits'} if $opt_e eq 'nsc78';
    printf " %4.1f-%4.1f", $p->{'wins'}, $p->{'sgames'}-$p->{'wins'};
    printf " %+5d", $spread unless $opt_S;
    printf "%6.1f", $p->{'sos'};
    unless ($opt_e eq 'nsc78') {
      if ($p->{'oldr'}) { 
	printf " %4d %4d %+4d", $p->{'oldr'}, $p->{'newr'}, $p->{'newr'}-$p->{'oldr'}; 
	}
      else { printf " n.r. %4d     ", $p->{'newr'}; }
      }
    printf " %3d %3d %3d", $p->{'afor'}+0.5, $p->{'aagn'}+0.5, $p->{'hi'} 
      unless $opt_S;
    print "\n";
    $p->{'rank'} = $i++;
    }
  print "\n";

  # print cross tables
  $rank = 1;
  for my $p ($opt_f ? @$ps : @ranked) {
    next if $p->{'fname'} eq 'F NORD';
    printf "%$dp->{'tourney'}{'maxnum'}d  %-$dp->{'tourney'}{'maxname'}s ", $rank++, $p->{'fname'};
    my $pos = $dp->{'tourney'}{'maxnum'} + $dp->{'tourney'}{'maxname'} + 2;
    for my $round (0..$#{$p->{'opps'}}) {
      if ($pos > $gLineLength - ($dp->{'tourney'}{'maxnum'} + 2)) {
	printf "\n%$dp->{'tourney'}{'maxnum'}s  %$dp->{'tourney'}{'maxname'}s ", '', '';
	$pos = $dp->{'tourney'}{'maxnum'} + $dp->{'tourney'}{'maxname'} + 2;
	}
      my $o = $p->{'opps'}[$round];
      if ($o == -1) { printf "B%s ", ('-' x $dp->{'tourney'}{'maxnum'}); }
      elsif ($round > $#{$p->{'scores'}}) {
	printf "?%0$dp->{'tourney'}{'maxnum'}d ",
	  $ps->[$o]{$opt_f ? 'id' : 'rank'} + $opt_f; 
	}
      else {
        printf "%s%0$dp->{'tourney'}{'maxnum'}d ", 
  	  ('L','T','W')[($p->{'scores'}[$round]<=>$ps->[$o]{'scores'}[$round])+1],
	  $ps->[$o]{$opt_f ? 'id' : 'rank'} + $opt_f;
	}
      $pos += 2 + $dp->{'tourney'}{'maxnum'};
      }
    print "\n";
    unless ($opt_S) { # $opt_S: suppress scores
      printf "%$dp->{'tourney'}{'maxnum'}s  %-$dp->{'tourney'}{'maxname'}s ", '', '';
      $pos = $dp->{'tourney'}{'maxnum'} + $dp->{'tourney'}{'maxname'} + 2;
      for my $round (0..$#{$p->{'scores'}}) {
	if ($pos > $gLineLength - ($dp->{'tourney'}{'maxnum'} + 2)) {
	  printf "\n%$dp->{'tourney'}{'maxnum'}s  %$dp->{'tourney'}{'maxname'}s ", '', '';
	  $pos = $dp->{'tourney'}{'maxnum'} + $dp->{'tourney'}{'maxname'} + 2;
	  }
	my $o = $p->{'opps'}[$round];
	if ($o == -1) { 
	  my $nlp1 = $dp->{'tourney'}{'maxnum'} + 1;
	  printf "%+${nlp1}d ", $p->{'scores'}[$round]; 
	  }
	else {
	  printf "%s%3d ", (' ' x ($dp->{'tourney'}{'maxnum'}-2)),
	    $p->{'scores'}[$round]; 
	  }
	$pos += 2 + $dp->{'tourney'}{'maxnum'};
	}
      print "\n";
      }
    }
  }

sub WriteSimpleTable ($) { 
  my $dp = shift;
  my $ps = $dp->{'players'};
  our($opt_e, $opt_S);

  my @ranked = $opt_e eq 'nsc78' 
    ? (sort SortByCredits @$ps)
    : (sort SortByWinsAndCume @$ps);
  my $i = 1;
  my $rank = 1;
  my $last_spread = -10000;
  my $last_wins = -10000;

  # print standings
  for my $p (@ranked) {
    if ($p->{'wins'} != $last_wins || $p->{'spread'} != $last_spread) {
      $last_wins = $p->{'wins'}; $last_spread = $p->{'spread'};
      $rank = $i;
      }
    my $wins = $p->{'wins'};
    $wins =~ s/\.5$/+/;
    my (@name) = split(/\s+/, $p->{'fname'});
    if (@name == 2) { }
    elsif (@name == 3) {
      if ($p->{'fname'} =~ /^(?:DANIEL ROBIN POLLOCK|BERGERON MARY ELLEN|WISNIEW DAWN CAMILLE|COHEN JO ANNE|AGDEPPA GLORIOSA ONDOY|MARIA JULIE ELLEN|GOODRICH ALICE ANN|RIBLE FRED III|SHAPIRO IDA ANN|SPARROW REEDY MURIEL|WEISSKOPF MARY ELLEN)$/) { }
      elsif ($p->{'fname'} =~ /^(?:\w+ \w+ \w|\w+ \w \w+)$/) { }
      elsif ($p->{'fname'} =~ /^(VAN PELT JOHN|SAITO STEWART PATRICIA|D AMBROSIO BRUCE|BERG RICHARDS VERNA|VAN ALEN BARBARA|POLAK SCOWCROFT CAROLINE)$/) { 
	splice(@name, 0, 2, join(' ', @name[0,1]));
        }
      else { die "Not sure how to split @name.\n"; }
      }
    elsif ($p->{'fname'} =~ /^(?:KILLE JAMES L JR)$/) {
      }
    else {
      die "Not sure how to split @name.\n";
      }
    printf "%d.\t%s, %s\t%s\t%+d\n",
      $rank, $name[0], join(' ', @name[1..$#name]), $wins, $p->{'spread'};
    $p->{'rank'} = $i++;
    }
  print "\n";
  }

sub WriteSS ($$) { 
  my $dp = shift;
  my $pn = shift;
  my $ps = $dp->{'players'};
  our($gNumberLength, $opt_e);
  if (--$pn >= 0 && $pn <= $#$ps) {
    printf "Scoresheet for player %d: %s\n", 1+$pn, $ps->[$pn]{'fname'};
    my $p = $ps->[$pn];
    my $os = $p->{'opps'};
    my $cume = 0;
    my $l = 0;
    my $w = 0;
    for my $round (0..$#$os) {
      last if $round > $#{$p->{'scores'}};
      my $o = $os->[$round];
      if ($o == -1) { # bye
	my $psc = $p->{'scores'}[$round];
	$cume += $psc;
	my $result = (($psc <=> 0) + 1) / 2;
	$w += $result; $l += 1 - $result;
	die "Unimplemented" if $opt_e eq 'nsc78';
	printf "%$dp->{'tourney'}{'maxnum'}d. %-$dp->{'tourney'}{'maxname'}s %4s %4.1f %4.1f  %3s %3s"
	  ." %+4d %+5d\n",
	  $round+1, 'bye', '', $w, $l, '', '', $psc, $cume;
	}
     else {
	$o = $ps->[$o];
	my $osc = $o->{'scores'}[$round];
	my $psc = $p->{'scores'}[$round];
        my $diff = $psc - $osc;
	if ($opt_e eq 'nsc78') {
	  my $score_credits = int($psc/50);
	  my $spread_credits = $diff > 0 ? int($diff/50) : 0;
	  my $win_credits = (($diff <=> 0) * 3 + 3)/2;
	  $cume += $score_credits + $spread_credits + $win_credits;
	  printf "%$dp->{'tourney'}{'maxnum'}d. %-$dp->{'tourney'}{'maxname'}s %4d %3d %3d %+4d"
	    ." %4.1f %4.1f %4.1f %5.1f\n",
	    $round+1, $o->{'fname'}, $o->{'oldr'}, $psc, $osc, $diff, 
	    $win_credits, $score_credits, $spread_credits, 
	    $cume;
	  }
	else {
	  if ($opt_e eq 'tor80') {
	    if ($diff > 200) { $cume += 200; }
	    elsif ($diff < -200) { $cume -= 200; }
	    else { $cume += $diff; }
	    }
	  else
	    { $cume += $diff; }
	  my $result = (($diff <=> 0) + 1) / 2;
	  $w += $result; $l += 1 - $result;
	  printf "%$dp->{'tourney'}{'maxnum'}d. %-$dp->{'tourney'}{'maxname'}s %4d %4.1f %4.1f  %3d %3d"
	    ." %+4d %+5d\n",
	    $round+1, $o->{'fname'}, $o->{'oldr'}, $w, $l, $psc, $osc, $diff, $cume;
	  }
	}
      }
    }
  else { 
    printf STDERR "Player number %d is outside of the range 1..%d.\n",
      ++$pn, $#$ps+1;
    }
  }

sub WriteTransfer ($) {
  my $dp = shift;
  my $psp = $dp->{'players'};
  die "no players" unless @$psp;
  my @splits = &ratings2::CalculateSplitRatings($psp,
    $#{$psp->[0]{'scores'}}+1,
    {
      'ewins' => 'ewins',
      'lifeg' => 'totalg',
      'newr' => 'newr',
      'oldr' => 'oldr',
      'rgames' => 'rgames',
      'pairings' => 'opps',
      'scores' => 'scores',
      'splitr' => 'splitr',
      'totalacc' => 'totalacc',
      'totalfeed' => 'totalfeed',
    });
  my $maxname = $dp->{'tourney'}{'maxname'};
  my $acc = 0;
  my $feed = 0;
  my $change = 0;
  my $increase = 0;
  my $decrease = 0;
  for my $p (@$psp) {
    my $this_acc = ($p->{'totalacc'} || 0);
    my $this_feed = ($p->{'totalfeed'} || 0);
    my $this_change = $p->{'newr'} - $p->{'oldr'};
    printf "%-$maxname.${maxname}s %5.1f %5.1f %+5d\n", $p->{'name'}, 
      $this_acc, $this_feed, $this_change;
    $acc += $this_acc;
    $feed += $this_feed;
    if ($p->{'oldr'}) {
      $increase += $this_change if $this_change > 0;
      $decrease += $this_change if $this_change < 0;
      $change += $this_change;
      }
    }
  printf "%-$maxname.${maxname}s %5.1f %5.1f %+5d (%+5d/%5d)\n", 
    'Total', $acc, $feed, $change, $increase, $decrease;
  }

package Tourney;

sub new () {
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $this = {
    'divisions' => [],
    'event_name' => '?',
    'event_date' => '?',
    'event_type' => 'ORT',
    'maxname' => length('Name (online)'),
    'maxnum' => 2,
    'rounds' => undef,
    };
  bless $this, $class;
  $this->AddDivision();
  return $this;
  }

sub AddDivision ($) {
  my $this = shift;
  my $dp = {
    'players' => [],
    'tourney' => $this,
    };
  push(@{$this->{'divisions'}}, $dp);
  }

sub Analyse ($) {
  my $this = shift;
  our $opt_b;
  for my $dp (@{$this->{'divisions'}}) {
    my $psp = $dp->{'players'};
    # analyse and check data
    for my $pn (0..$#$psp) { 
      my $p = $psp->[$pn];
      my $games = 0;
      my $opts = 0;
      my $pts = 0;
      for my $si (0..$#{$this->{'splits'}}) {
	$p->{"ewins$si"} = 0;
        }
      $p->{'ewins'} = $p->{'rgames'} = $p->{'hi'} = $p->{'spread'} =
      $p->{'tagn'} = $p->{'tfor'} = $p->{'wins'} = $p->{'credits'} = 0;
      my $os = $p->{'opps'}; 
      $p->{'games'} = scalar(@$os);
      $p->{'sgames'} = scalar(@{$p->{'scores'}});
      if (($this->{'rounds'}||0) != $p->{'games'}) {
	printf STDERR "$p->{'fname'} played $p->{'games'} rounds, not $this->{'rounds'}.\nReports may not be correct.\n"
	  if defined $this->{'rounds'};
	$this->{'rounds'} = $p->{'games'};
	}
      for my $r0 (0..$#$os) {
	my $round = $r0+1;
	my $o = $os->[$r0];
	my $sc = $p->{'scores'}[$r0];
	my $si = $this->{'round_to_split'}[$r0];
	my $spread;
	if ($o == -1) { # bye
	  next unless defined $sc;
	  $spread = $sc;
	  if ($::opt_c) {
	    printf STDERR "%s: bye in round %d scored %+d instead of standard 0.\n",
	      $p->{'fname'}, $round, $p->{'scores'}[$r0] 
	      if $p->{'scores'}[$r0];
	    }
	  elsif (0) { # code dead as of 2013-07-14
	    my $score = $p->{'scores'}[$r0];
	    printf STDERR
	      "%s: bye in round %d scored %+d instead of standard -$opt_b, 0, +$opt_b.\n",
	      $p->{'fname'}, $round, $p->{'scores'}[$r0] 
	      if $score != $opt_b && $score != -$opt_b && $score != 0;
	    }
	  }
	elsif ($o == $pn) {
	  printf STDERR "%s: played self in round %d\n", $p->{'fname'}, $round;
	  next;
	  }
	elsif ($o > $#$psp) {
	  printf STDERR
	    "%s: opponent number (%d) in round %d is too big (>%d).\n",
	    $p->{'fname'}, $o, $round, scalar(@$psp);
	  next;
	  }
	else {
	  $o = $psp->[$o];
	  printf STDERR "In round %d, %s's opp was %s but %s's opp was %s.\n",
	    $round, $p->{'fname'}, $o->{'fname'}, $o->{'fname'},
	    $psp->[$o->{'opps'}[$r0]]{'fname'}
	    if $pn != $o->{'opps'}[$r0];
	  next unless defined $sc;
	  $p->{'hi'} = $sc if $p->{'hi'} < $sc;
	  $pts  += $sc;
	  my $osc = $o->{'scores'}[$r0];
	  if (defined $osc) {
	    $opts += $osc;
	    $spread = $sc - $osc;
	    my $wins = (($spread<=>0)+1)/2;
	    $p->{"rgames"} ++;
	    $games++;
	    }
	  else {
	    printf STDERR "In round %d, %s's opp (%s) had no score.\n",
	      $round, $p->{'fname'}, $o->{'fname'}; 
	    }
	  }
	if ($::opt_e eq 'tor80') {
	  if ($spread > 200) { $p->{'spread'} += 200; }
	  elsif ($spread < -200) { $p->{'spread'} += -200; }
	  else { $p->{'spread'} += $spread; }
	  }
	else { $p->{'spread'} += $spread; }
	if ($o == -1) {
	  $p->{'wins'} ++ if $spread > 0;
	  }
	else {
	  my $this_win =(($spread<=>0)+1)/2;
	  $p->{'wins'} += $this_win;
	  $p->{'ewins'} += $this_win;
	  }
	  # unless zero-scoring bye
	$p->{'credits'} 
	  += int($sc/50) # score credits
	  +  ($spread > 0 ? int($spread/50) : 0) # spread credits
	  +  (($spread <=> 0) * 3 + 3)/2; # win credits
	}
      if (defined $p->{'rr'}) {
	$p->{'ewins'} += $p->{'rr'}[1];
	$p->{'rgames'} += $p->{'rr'}[0] * $#$psp;
	$p->{'spread'} += $p->{'rr'}[2];
	$p->{'wins'} += $p->{'rr'}[1];
	$::opt_S = 1;
	}
      if ($games > 0) { 
	$p->{'afor'} = $pts/$games;
	$p->{'aagn'} = $opts/$games; 
	$p->{'tfor'} = $pts;
	$p->{'tagn'} = $opts;
	}
      else { $p->{'afor'} = $p->{'aagn'} = 0; }
      }
    # calculate sum-of-scores
    for my $pn (0..$#$psp) { 
      my $p = $psp->[$pn];
      my $os = $p->{'opps'}; 
      my $mss = $p->{'scores'}; 
      $p->{'sos'} = 0;
      for my $r0 (0..$#$mss) {
	my $o = $os->[$r0];
	next if $o == -1;
	$o = $psp->[$o];
	$p->{'sos'} += $o->{'ewins'};
        }
      }
    }
  }

sub Divisions ($) {
  my $this = shift;
  return @{$this->{'divisions'}};
  }

sub LastDivision ($) {
  my $this = shift;
  return $this->{'divisions'}[-1];
  }

# the player hash generated by the following sub and used elsewhere
# has the following fields:
#   aagn    average points scored by opponents
#   afor    average points scored by player
#   curr    current rating during iteration of initial rating
#   ewins   earned wins (not including byes)
#   ewins0  number of earned wins in split segment 0 (similarly 1, 2)
#   fname   full name with online id appended if any
#   games   games played (including byes)
#   hi      high game score
#   id      0-based id
#   midr    mid-tournament rating in a split-rated tournament
#   name    full name
#   newr    post-tournament rating
#   oldr    pre-tournament rating
#   opps    [ opponent ids (0-based) ]
#   rank    ranking
#   rgames  real games (not including byes)
#   rgames0 number of real games in split segment 0 (similarly 1, 2)
#   rr      [ # of round robins played, wins, spread ] or undef
#   scores  [ own score in each game ]
#   sos     sum of opponent scores (total number of opp earned wins)
#   spread  point spread
#   tagn    total points scored by opps
#   tfor    total points scored by player
#   totalg  number of games played prior to this tournament
#           (-1 if rating is fixed)
#   wins    games won (including byes)

# $success = $divs->Read($fh);
sub Read ($$) { 
  my $this = shift;
  my $fh = shift;
  my $dp = $this->LastDivision();
  while (<$fh>) { my $input = $_; 
    if (s/^\s*#division\s+(.*\S)\s*$//i) { 
      if (@{$dp->{'players'}}) {
	$this->AddDivision();
	$dp = $this->LastDivision();
        }
      $dp->{'name'} = uc $1;
      next;
      }
    if (s/^\s*#(event_(?:date|name|type))\s+(.*\S)\s*$//i) { 
      $this->{$1} = uc $2;
      next;
      }
    s/#.*//; next unless /\S/;
    my $cume;
    my $lifeg;
    if (s/;\s*lifeg\s+(\d+)\s*//) { $lifeg = $1; }
    if (s/;\s*cume\s+([-+]?\d+)\s*//) { $cume = $1; }
    if (my ($n, $r, $games, $rr, $o, $s) 
= m!^([a-zA-Z&;][-/.,'a-zA-Z ]+[.a-zA-Z](?: \d+,)?) +(\d+(?:\.\d*)?)(\*\*|\*\d+)? +(R\d+/\d*\.?\d*/[+-]?\d+ )? *([\d ]*); *([-\d ]*)(?:;.*)?$!) {
      if (defined $rr) { $rr =~ s/^R//; $rr = [split(/\//, $rr)];}
      my (@opps) = (split(/\s+/, $o));
      for my $o (@opps) { $o--; }
      my $pp = { 
	input => $input,
	name => $n, 
	oldr => $r, 
	rr => $rr,
	opps => \@opps,
	scores => [split(/\s+/,$s)], 
	totalg => 
	  (defined $games) ? ($games eq '**') ? -1 : substr($games, 1)
	  : (defined $lifeg ? $lifeg : $r ? 100 : 0)
	};
      $pp->{'cume'} = $cume if defined $cume;
      push(@{$dp->{'players'}}, $pp);
      $pp->{'id'} = $#{$dp->{'players'}};
      $this->{'maxnum'} = length($pp->{'id'}+1)
        if $this->{'maxnum'} < length($pp->{'id'}+1);
      my $l = length($pp->{'fname'} = main::Online $pp->{'name'});
      $this->{'maxname'} = $l
        if $this->{'maxname'} < $l;
      my $os = $pp->{'opps'}; 
      my $scs = $pp->{'scores'};
      printf STDERR "%s: number (%d) of opponents (%s) "
	."is less than number (%d) of scores (%s).\n",
	$pp->{'name'}, 1+$#$os, "@$os", 1+$#$scs, "@$scs" if $#$os < $#$scs;
      }
    else {
      warn "Can't parse (and am ignoring) the following line:\n$_";
      }
    }
  return undef;
  }

=back

=cut

# Input File Format (historical reference only, see tsh.poslfit.com)
#
# One line per player, reading:
#
#   name rating rr pairings ; scores
#
# e.g.
#
#   John Chew 1823*75 R2/7.5/+30 1 2 3 0 ; 400 450 350 50 # comment
#
# meaning that John Chew was 
#   rated 1823 before this tournament
#   played a double round robin and won 7.5 games with a +30 spread
#   played three additional games
#     scoring 400 against player #1, 450 against player #2,
#     350 against player #3
#   and had a 50-point bye
#
# name: given name(s) followed by surname
# rating: pre-tournament rating, followed optionally by an asterisk and the 
#   number of games on which the rating is based, or by two asterisks to 
#   indicate that the rating is fixed (as e.g. for a Club #3 director)
# rr: round robin information (optional), if present prevents scoring
#   statistics from being calculated.  must be a capital 'R' followed by
#   number of round robins, games won and spread, separated by '/'s.
# pairings: opponent numbers; first in file is 1, bye is 0.
# scores: player's scores; opponent's scores are found on opponent's lines.
#
# TODO: check that ratings are calculated correctly with RRs
# TODO: make games count against director
