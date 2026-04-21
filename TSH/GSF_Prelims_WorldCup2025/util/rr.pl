#!/usr/bin/perl

# rr.pl - utility used to compute balanced round robin schedules

use strict;
use warnings;

my $debug_level = 1;
my $debug_log = '';

sub ComputeRPStarts ($);
sub ComputeTargets ($);
sub debug ($);
sub debug_clear ();
sub debug_dump ();
sub ExtendCycle ($);
sub FindP2Opps ($);
sub Main ();
sub MakeCycle ($);
sub Print ($);
sub Renumber ($);
sub TryClosingCycle ($);
sub TryExtendingCycle ($);
sub TryExtendingCycleNormally ($);
sub TryExtendingCycleToTarget ($);
sub TryPairing ($$$);
sub Unpair($$$);

# the basic algorithm works fine when the number of players is
# divisible by 4, but needs hints when it's two mod four

my (%hints) = ( 
   # 'n;rp;last' => 'target'
   '18;8;10' => 2,
   '18;8;14' => 4,
   '18;8;7' => 13,
   # 'n;rp' => [start of first cycle, start of second cycle, ...]
   '14;4' => [9],
   '18;2' => [6], 
   '18;4' => [7], 
   '18;6' => [8,7], 
   '18;8' => [3], 
   '22;2' => [7], 
   '22;4' => [8], 
   '22;6' => [9], 
   '22;8' => [10], 
   '22;10' => [11], 
   '26;2' => [8], 
   '26;4' => [9], 
   '26;6' => [10], 
   '26;8' => [11], 
   '26;10' => [12], 
   '26;12' => [13], 
   '28;2' => [8], 
   '28;4' => [9], 
   '28;6' => [10], 
   '28;8' => [11], 
   '28;10' => [12], 
   '28;12' => [13], 
  );

# hint calculation for n=18, a particularly hairy case
# 
# 2 needs two odd pairs
#   9s: uses 4-13 6-15 omits 4-6 13-15
# 4 needs two odd pairs
#   9s: uses 3-12 7-16 omits 3-7 12-16
# 6 needs too many 9s, borrows some 8s: 
#   9s: uses 2-11 8-17 omits 2-8 11-17
# X 8s: 8 14 2 11 5 17 / 1 13 7 15 3 9 / 4 10 16 6 18 12 uses 1-9 4-12 6-16 7-15 omits 1-7 4-16 6-12 9-15
# X 8s: 8 14 2 11 5 17 / 13 7 1 9 15 3 / 4 10 16 6 18 12 uses 1-9 3-13 4-12 6-16 omits 1-13 3-9 4-16 6-12
#   8s: 8 14 2 11 5 17 / 7 1 13 3 9 15 / 4 10 16 6 18 12 uses 3-13 4-12 6-16 7-15 omits 3-15 4-16 6-12 7-13
# 8 can use some 6s to run
#   9s: uses 1-10 9-18 omits 1-9 10-18
#   want 1 9 17 7*15 5 13*3 11 / 2 10 18 8 16*6 14 4*12 
#   but * were used so stitch together using corresponding 6s
#   must join even/odd with 1=10 9=18
#   should use 8s
#     15-5-13 3-11-1-9-17-7
#     6-14-4 12-2-10-18-8-16
#   can use
#     3-15 4_16 6_12 7-13
#   string all odds together, then evens
#     3-11-1-9-17-7_13-5-15_
#     16-8-18-10-2-12_6-14-4_
#   use 9s to join them
#     3-11-1=10-2-12_6-14-4_16-8-18=9-17-7_13-5-15_3-

Main;

=head2 DATA

=over 4

=item C<afterfirst>

Reference to list mapping round-pair numbers to index of player
who is listed after player 1 in that round pair.

=item C<beforefirst>

Reference to list mapping round-pair numbers to index of player
who is listed before player 1 in that round pair.

=item C<canon>

Reference to list mapping computed player numbers to output
player numbers.  Computed numbers were relatively easy to
compute.  Output numbers are permuted so that player #1 faces
each of his opponents in decreasing order.

=item C<cycle>

The cycle currently being constructed.

=item C<cycles>

A reference to a list of cycles currently being constructed.
It will eventually be used to pair two rounds, the first starting
odd players against their successors, the second having them reply
to their predecessors, so as to ensure that starts and replies
stay balanced.

=item C<delta>

The preferred difference between successive members of the cycle
currently being constructed.

=item C<evenstartfirst>

A reference to a list mapping round-pair numbers to flags indicating
whether even-indexed players in each cycle start (true) or reply
(false) in the first round (when even players play their successors)
of the round pair.  Starts and replies are reversed in the second
round (when odd players play their successors).

=item C<lastround>

A reference to a list of references to lists of pairs of player numbers,
to be paired in the final round.

=item C<n>

The number of players in the schedule.

=item C<paired>

A reference to a list of lists of flags indicating who has played whom.

=item C<p2opps>

A reference to a list mapping player number to 
  {
    'rp' => round pair in which this player plays the highest-numbered player,
    'iseven' => true iff this player is in an even position in its cycle,
    'firstround' => true iff this player played #2 in the 1st round of this rp,
    'other' => number of the other player who played #2 in this rp,
  }

=item C<roundpair>

The number of the pair of rounds currently being paired.
See C<cycles> for a discussion of what a round pair is.

=item C<roundpairs>

A reference to a list mapping past values of C<roundpair> to
corresponding past values of C<cycles>.

=item C<rpstarts>

A reference to a list mapping round pair to booleans.  If true,
players in even positions in cycles start in the first round of
the round pair and reply in the second; if false the reverse.

=item C<target>

The current candidate to add to a cycle.

=item C<targets>

A reference to a list of candidates to add to a cycle,
sorted in order of decreasing preference.

=item C<unpaired>

A reference to a hash whose keys are the numbers which do not yet appear
in the current set of cycles.

=back

=cut

=head2 SUBROUTINES

=over 4

=cut

sub debug ($) { $debug_log .= shift; }
sub debug_clear () {
  $debug_log = ''; 
}
sub debug_dump () { warn $debug_log; debug_clear; }

=item ComputeRPStarts \%data;

Update $data{'rpstarts'}.  This has to be done in such a way that
if the last player is dropped and all his opponents get byes, then
starts and replies remain balanced.

=cut

sub ComputeRPStarts ($) {
  my $datap = shift;
  my $n = $datap->{'n'};
  debug_clear;
  # The pairings for the last round are key.  If two players face
  # each other, neither of whom is the last player (Player n), 
  # one must have started earlier against Player n and the other
  # must have replied.  We ensure this by adjusting the value of
  # $datap->{'evenstartfirst'}.
  my $lastroundp = $datap->{'lastround'};
  # @lastopp maps player numbers to the number of their opponent
  # in $lastroundp
  my @lastopp;
  # @whichlastpair maps player numbers to the number of their pair
  # in $lastroundp
  my @whichlastpair;
  # %left contains keys equal to indexes in $lastroundp to keys 
  # if we have not yet processed them
  my %left;
  # initialise @lastopp, @whichlastpair and %left
  for my $i (0..$#$lastroundp) {
    my $pairp = $lastroundp->[$i];
    $lastopp[$pairp->[0]] = $pairp->[1];
    $lastopp[$pairp->[1]] = $pairp->[0];
    $whichlastpair[$pairp->[0]] = $i;
    $whichlastpair[$pairp->[1]] = $i;
    $left{$i} = 1;
    }
  # @todo is a list of indexes in $lastroundp which need to be worked
  # on before indexes that are not in @todo
  my (@todo);
  while (%left) {
    my $pairi;
    # work on half-done pairs first
    if (@todo) { 
      $pairi = pop @todo; 
      debug "todo queue gives last-round pair $pairi\n";
      unless ($left{$pairi}) {
	debug ".. which is already done\n";
	next;
        }
      }
    # otherwise grab a random one
    else { $pairi = (%left)[0]; }
    delete $left{$pairi};
    my $pairp = $lastroundp->[$pairi];
    debug "examining $pairp->[0]-$pairp->[1]\n";
    # if one of the players is player n, then we don't need to do
    # anything because earlier-round pairings are balanced by the
    # round-pair mechanism
    if ($pairp->[0] == 2 || $pairp->[1] == 2) {
      debug "..skipping pairing involving player 2\n";
      next;
      }
    # look up information about when these two players faced player 2
    my (@p2op) = map { $datap->{'p2opps'}[$pairp->[$_]] } 0..1;
#   debug "\@p2op: @p2op\n";
    # the round pair in which each player played player 2
    my (@rps) = map { $p2op[$_]{'rp'} } 0..1;
#   debug "\@rps: @rps\n";
    # look up which players play first in the rounds concerned
    my (@esf) = map { $datap->{'evenstartfirst'}[$rps[$_]] } 0..1;
    # see whether 
    my $count = 0;
    $count++ if defined $esf[0];
    $count++ if defined $esf[1];
    if ($count == 2) {
      my (@started_vs_p2) = map { 
	$p2op[$_]{'iseven'}
	xor $p2op[$_]{'firstround'}
	xor $esf[$_]
        } 0..1;
      if ($started_vs_p2[0] == $started_vs_p2[1]) {
	debug_dump;
	die sprintf("..%d and %d both %s vs. 2\n",
	  $pairp->[0],
	  $pairp->[1],
	  $started_vs_p2[0] ? 'started' : 'replied');
        }
      }
    if ($count == 0) {
      # set one arbitrarily
      $esf[0] = $datap->{'evenstartfirst'}[$rps[0]] = 1;
      debug "..p0=$pairp->[0]: esf[rs=$rps[0]] := 1 arbitrarily\n";
      # this also forces a choice for the last opponent of the player
      # who might get the other bye in this round pair
      my $otherbye = $p2op[0]{'other'};
      my $lastopp = $lastopp[$otherbye];
#     my $hislastpairi = $whichlastpair[$datap->{'p2opps'}[$lastopp]{'rp'}];
      my $hislastpairi = $whichlastpair[$otherbye];
      debug "....$pairp->[0] forces (1) a choice for $otherbye\n";
      if ($left{$hislastpairi}) {
        push(@todo, $hislastpairi);
        debug "......queue $otherbye-$lastopp\n";
        }
      else {
        debug "......$otherbye-$lastopp already done, not queued\n";
        }
      }

    my $old = (defined $esf[0]) ? 0 : 1;
    my $new = 1 - $old;
    debug "..oldid=$pairp->[$old] iseven=$p2op[$old]{'iseven'} firstround=$p2op[$old]{'firstround'} esf=$esf[$old]\n";
    my $old_started_vs_p2 = 
      ($p2op[$old]{'iseven'} # is in even position in cycle
      xor $p2op[$old]{'firstround'} # plays in first round of pair
      xor $esf[$old]); # in a round in which evens start first
    debug "..newid=$pairp->[$new] iseven=$p2op[$new]{'iseven'} firstround=$p2op[$new]{'firstround'} oldsvp=$old_started_vs_p2\n";
    my $newvalue = !($p2op[$new]{'iseven'} 
      xor $p2op[$new]{'firstround'}
      xor $old_started_vs_p2);
    my $oldvalue = $datap->{'evenstartfirst'}[$rps[$new]];
    if (defined $oldvalue) {
      if ($oldvalue eq $newvalue) {
	debug "..pn=$pairp->[$new]: esf[rs=$rps[$new]] = $oldvalue, no change needed\n";
        }
      else {
	debug_dump;
	die "..pn=$pairp->[$new]: esf[rs=$rps[$new]] should be $newvalue but is $oldvalue\n" 
	}
      }
    else {
      $datap->{'evenstartfirst'}[$rps[$new]] = $newvalue;
      debug "..pn=$pairp->[$new]: esf[rs=$rps[$new]] := $datap->{'evenstartfirst'}[$rps[$new]]\n";
      }
    # this also forces a choice for the last opponent of the player
    # who might get the other bye in this round pair
    my $otherbye = $p2op[$new]{'other'};
    my $lastopp = $lastopp[$otherbye];
    my $hislastpairi = $whichlastpair[$otherbye];
    debug "....$pairp->[$new] forces (2) a choice for $otherbye\n";
    if ($left{$hislastpairi}) {
      push(@todo, $hislastpairi);
      debug "......queue $otherbye-$lastopp\n";
      }
    else {
      debug "......$otherbye-$lastopp already done, not queued\n";
      }
    }
  debug 'esf: '; for my $i (1..$#{$datap->{'evenstartfirst'}}) { my $esf = $datap->{'evenstartfirst'}[$i] ? 1 : 0; debug "$i:$esf "; } debug "\n";

  debug_dump;
  debug_clear;
  }


=item ComputeRPStarts \%data;

Update $data{'targets'};

=cut

sub ComputeTargets ($) {
  my $datap = shift;
  my $last = $datap->{'cycle'}[-1];
  my $n = $datap->{'n'};
  $datap->{'targets'} = [
    # all candidates, prefering those we would want to use later
    sort { 
      my $adelta = ($last + $n - $a) % $n; $adelta = $n - $adelta if $adelta + $adelta > $n;
      my $bdelta = ($last + $n - $b) % $n; $bdelta = $n - $bdelta if $bdelta + $bdelta > $n;
  #	  debug "a=$a adelta=$adelta b=$b bdelta=$bdelta\n";
      ($adelta+$adelta != $n) <=> ($bdelta+$bdelta != $n) # best is when delta=n/2
      || ($adelta % 2) <=> ($bdelta % 2) # next best is an even delta
      || $bdelta <=> $adelta; # all else being equal choose large delta
      } grep { !$datap->{'paired'}[$last][$_] } keys %{$datap->{'unpaired'}}
    ];
}

sub ExtendCycle ($) {
  my $datap = shift;
  my $last = $datap->{'cycle'}[-1];
  my $n = $datap->{'n'};
  my $hintkey = "$n;$datap->{'roundpair'};$last";
# debug "hintkey=$hintkey\n";
  if (exists $hints{$hintkey}) {
    my $hint = $hints{$hintkey};
    $datap->{'targets'} = [abs($hint)];
    if ($hint > 0) { 
      # negate delta to cancel the upcoming negation
      $datap->{'delta'} *= -1;
      }
    }
  else {
    TryExtendingCycleNormally $datap && return 1;
    debug "Cannot extend @{$datap->{'cycle'}} by $datap->{'delta'}\n";
    TryClosingCycle $datap && return 1;
    debug "Cannot close cycle\n";
    ComputeTargets $datap;
    debug "Available targets for $datap->{'cycle'}[-1]: @{$datap->{'targets'}}\n";
    }
  while (@{$datap->{'targets'}}) {
    $datap->{'target'} = shift @{$datap->{'targets'}};
    $datap->{'delta'} *= -1;
    TryExtendingCycleToTarget $datap && return 1;
    $datap->{'delta'} *= -1;
    TryExtendingCycleToTarget $datap && return 0;
    }
  debug "cannot extend cycle\n";
  return 0;
  }

=item FindP2Opps \%data;

Update $data{'p2opps'}.

=cut

sub FindP2Opps ($) {
  my $datap = shift;
  for my $rp (1..$#{$datap->{'roundpairs'}}) {
    my $cyclesp = $datap->{'roundpairs'}[$rp];
    cycle:for my $cyclep (@$cyclesp) {
      for my $i (0..$#$cyclep) {
	if ($cyclep->[$i] == 2) { 
	  my $iseven = $i % 2; # true if $i+1 and $i-1 are even
	  my $p1 = $cyclep->[($i+1) % @$cyclep];
	  my $p2 = $cyclep->[$i-1];
	  printf STDERR "rp=$rp i=$i: 2 played %d and %d\n", $p1, $p2;
	  $datap->{'p2opps'}[$p1] = { 
	    'rp' => $rp,
	    'iseven' => $iseven,
	    'firstround' => !$iseven,
	    'other' => $p2,
	     };
	  $datap->{'p2opps'}[$p2] = { 
	    'rp' => $rp,
	    'iseven' => $iseven,
	    'firstround' => $iseven,
	    'other' => $p1,
	    };
	  last cycle;
	  }
        }
      }
    }
  }

sub Main () {
  my $n = (shift @::ARGV) || 10;
  my (%data) = ('n' => $n);
  $data{'roundpairs'} = [];
  for my $rp (1..int($n/2)-1) {
    $data{'roundpair'} = $rp;
    debug "rp=$data{'roundpair'}\n";
    $data{'cycles'} = [];
    $data{'delta'} = $data{'roundpair'};
    $data{'unpaired'} = { map { $_ => 1 } (1..$n) };
    while (%{$data{'unpaired'}}) {
      if (MakeCycle \%data) {
 	warn "cycle made for rp=$rp: @{$data{'cycles'}[-1]}\n" if $debug_level;
        }
      else {
	debug_dump;
	die "MakeCycle failed\n";
	}
      debug_clear;
      }
    $data{'roundpairs'}[$data{'roundpair'}] = \@{$data{'cycles'}};
    }
  printf STDERR "last round: " if $debug_level;
  $data{'lastround'} = [];
  for my $p1 (1..$#{$data{'paired'}}) {
    my $p1p = ${$data{'paired'}}[$p1];
    for my $p2 (1..$#$p1p) {
      next if $p1p->[$p2] || $p2 >= $p1; # if we do $p1>=$p2 we miss the last pairing
      push(@{$data{'lastround'}}, [$p1,$p2]);
      print STDERR "$p1-$p2 " if $debug_level;
      }
    }
  print STDERR "\n" if $debug_level;
  Renumber \%data;
  FindP2Opps \%data;
  ComputeRPStarts \%data;
  Print \%data;
}

sub MakeCycle ($) {
  my $datap = shift;
  my $hintkey = "$datap->{'n'};$datap->{'roundpair'}";
  my $first;
  my $hintsp = $hints{$hintkey};
  if ($hintsp) { $first = shift @$hintsp; }
  if (!defined $first) { $first = (sort { $a <=> $b } keys %{$datap->{'unpaired'}})[0]; }
  $datap->{'cycle'} = [ $first ];
# delete $datap->{'unpaired'}{$first}; # will be marked as paired when cycle is closed
  while (@{$datap->{'cycle'}}) {
    if (!ExtendCycle $datap) {
      return 0;
    }
  }
  return 1;
}

sub Print ($) {
  my $datap = shift;
  my $n = $datap->{'n'};
  my @starts;
  for my $rp (1..$#{$datap->{'roundpairs'}}) {
    my $cyclesp = $datap->{'roundpairs'}[$rp];
    my @r1p12;
    my @r1pair;
    my @r2p12;
    my @r2pair;
    my $esf = $datap->{'evenstartfirst'}[$rp];
    warn "rp=$rp esf=$esf\n";
    cycle:for my $cyclep (@$cyclesp) {
      # copy first element to end, to avoid boundary conditions
      my (@cycle) = map { $datap->{'canon'}[$_] } (@$cyclep, $cyclep->[0]);
      warn "cycle: @cycle\n";
      # first round pairs forward
      for (my $i=0; $i<= $#cycle-1; $i += 2) {
	my $p1 = $cycle[$i];
	my $p2 = $cycle[$i+1];
	$r1pair[$p1] = $p2;
	$r1pair[$p2] = $p1;
	$r1p12[$p1] = $esf ? 1 : 2;
	$r1p12[$p2] = $esf ? 2 : 1;
	if ($rp == 1) { warn "$rp.1: $p1:$r1p12[$p1] $p2:$r1p12[$p2]\n"; }
        }
      # second round pairs backward
      for (my $i=1; $i<= $#cycle; $i += 2) {
	my $p1 = $cycle[$i];
	my $p2 = $cycle[$i+1];
	$r2pair[$p1] = $p2;
	$r2pair[$p2] = $p1;
	$r2p12[$p1] = $esf ? 1 : 2;
	$r2p12[$p2] = $esf ? 2 : 1;
	if ($rp == 1) { warn "$rp.2: $p1:$r2p12[$p1] $p2:$r2p12[$p2]\n"; }
        }
      }
    printf "\$Pairings[%d][%d] = [undef,%s];\n", $n,
      $rp+$rp-1, join(',',@r1pair[1..$#r1pair]);
    printf "\$Pairings[%d][%d] = [undef,%s];\n", $n,
      $rp+$rp, join(',',@r2pair[1..$#r2pair]);
    push(@starts, sprintf("\$Starts[%d][%d] = [undef,%s];\n", $n,
      $rp+$rp-1, join(',',@r1p12[1..$#r1p12])));
    push(@starts, sprintf("\$Starts[%d][%d] = [undef,%s];\n", $n,
      $rp+$rp, join(',',@r2p12[1..$#r2p12])));
  }
  my @rpair;
  for my $cyclep (@{$datap->{'lastround'}}) {
    my $p1 = $datap->{'canon'}[$cyclep->[0]];
    my $p2 = $datap->{'canon'}[$cyclep->[1]];
    $rpair[$p1] = $p2;
    $rpair[$p2] = $p1;
    }
  printf "\$Pairings[%d][%d] = [undef,%s];\n", $n,
    $n-1, join(',',@rpair[1..$#rpair]);
  print @starts;
  printf "\$Starts[%d][%d] = [undef,%s];\n", $n,
    $n-1, join(',',(4)x$#rpair);
}

sub Renumber ($) {
  my $datap = shift;
  my $n = $datap->{'n'};
  my @canon = (undef,1);
  for my $rp (1..$#{$datap->{'roundpairs'}}) {
    my $cyclesp = $datap->{'roundpairs'}[$rp];
#   warn "Checking $rp: @{$cyclesp->[0]}\n";
    my $next;
    my $prev;
    cycle:for my $cyclep (@$cyclesp) {
      for my $i (0..$#$cyclep) {
	if ($cyclep->[$i] == 1) {
	  if ($i == 0) 
	    { $prev = $cyclep->[-1]; $next = $cyclep->[$i+1]; }
	  elsif ($i < $#$cyclep) 
	    { $prev = $cyclep->[$i-1]; $next = $cyclep->[$i+1]; }
	  else 
	    { $prev = $cyclep->[$i-1]; $next = $cyclep->[0]; }
	  if ($i % 2) { ($prev, $next) = ($next, $prev); }
	  last cycle;
	  }
        }
      }
    die unless defined $next;
#   printf "rp=%d %d=>%d %d=>%d\n", $rp, $prev, $n-$rp-$rp+1, $next, $n-$rp-$rp+2;
    $canon[$prev] = $n-$rp-$rp+1;
    $canon[$next] = $n-$rp-$rp+2;
    }
  for my $cyclep (@{$datap->{'lastround'}}) {
    if ($cyclep->[0] == 1) { $canon[$cyclep->[1]] = 2; last; }
    elsif ($cyclep->[1] == 1) { $canon[$cyclep->[0]] = 2; last; }
    }
  $datap->{'canon'} = \@canon;
  warn "canon=@canon[1..$#canon]\n" if $debug_level;
  }

sub TryClosingCycle ($) {
  my $datap = shift;
  debug "Trying to close cycle\n";
  my $cyclep = $datap->{'cycle'};
  if (@$cyclep % 2 != 0) {
    debug "Cannot close odd cycle\n";
    return 0;
    }
  my $first = $cyclep->[0];
  my $last = $cyclep->[-1];
  unless (defined $first) { debug_dump; die "no first!\n"; }
  debug "Trying to close even cycle\n";
  $datap->{'unpaired'}{$first} = 1;
  TryPairing $datap, $last, $first or return 0;
  # TODO: see when the above pairing should get unpaired
  push(@{$datap->{'cycles'}}, $datap->{'cycle'});
  $datap->{'cycle'} = [];
  debug "Closed even cycle\n";
  return 1;
  }

sub TryExtendingCycleNormally ($) {
  my $datap = shift;
  $datap->{'target'} =
    (($datap->{'cycle'}[-1] + $datap->{'delta'}) % $datap->{'n'}) 
    || $datap->{'n'};
  return TryExtendingCycleToTarget $datap;
  }

sub TryExtendingCycleToTarget ($) {
  my $datap = shift;
  my $last = $datap->{'cycle'}[-1];
  my $target = $datap->{'target'};
  debug "Trying to extend @{$datap->{'cycle'}} to $target\n";
  TryPairing $datap, $last, $target or return 0;
  push(@{$datap->{'cycle'}}, $target);
  if (ExtendCycle $datap) {
    return 1;
    }
  else {
    Unpair $datap, $last, $target;
    pop(@{$datap->{'cycle'}});
    return 0;
    }
  }

sub TryPairing ($$$) {
  my $datap = shift;
  my $p1 = shift;
  my $p2 = shift;
  if (!$datap->{'unpaired'}{$p2}) {
    debug "$p2 has already been used\n";
    return 0;
    }
  if ($datap->{'paired'}[$p1][$p2]) {
    debug "$p1 and $p2 have already been paired together\n";
    return 0;
    }
  if ($p1 == $p2) {
    debug "Cannot pair $p1 with self\n";
    return 0;
    }
  debug "pairing: $p1-$p2\n";
  delete $datap->{'unpaired'}{$p1};
  delete $datap->{'unpaired'}{$p2};
  $datap->{'paired'}[$p1][$p2] = 1;
  $datap->{'paired'}[$p2][$p1] = 1;
  return 1;
  }

sub Unpair ($$$) {
  my $datap = shift;
  my $p1 = shift;
  my $p2 = shift;
  debug "unpairing: $p1-$p2\n";
  $datap->{'unpaired'}{$p1} = 1;
  $datap->{'unpaired'}{$p2} = 1;
  $datap->{'paired'}[$p1][$p2] = 0;
  $datap->{'paired'}[$p2][$p1] = 0;
  }

=back

=cut

