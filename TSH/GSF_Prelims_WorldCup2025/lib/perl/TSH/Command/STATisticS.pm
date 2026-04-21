#!/usr/bin/perl

# Copyright (C) 2007 John J. Chew, III <jjchew@math.utoronto.ca>
# All Rights Reserved

package TSH::Command::STATisticS;

use strict;
use warnings;

use TSH::Division::FindExtremeGames;
use TSH::Log;
use TSH::Utility;

our (@ISA) = qw(TSH::Command);

=pod

=head1 NAME

TSH::Command::STATisticS - implement the C<tsh> STATisticS command

=head1 SYNOPSIS

  my $command = new TSH::Command::STATisticS;
  my $argsp = $command->ArgumentTypes();
  my $helptext = $command->Help();
  my (@names) = $command->Names();
  $command->Run($tournament, @parsed_arguments);
  
=head1 ABSTRACT

TSH::Command::STATisticS is a subclass of TSH::Command.

=cut

=head1 DESCRIPTION

=over 4

=cut

sub initialise ($$$$);
sub new ($);
sub Run ($$@);

=item $parserp->initialise()

Used internally to (re)initialise the object.

=cut

sub initialise ($$$$) {
  my $this = shift;
  my $path = shift;
  my $namesp = shift;
  my $argtypesp = shift;

  $this->{'help'} = <<'EOF';
Use this command to list overall statistics for your tournament.
If there is a statistic that you would like to see added to this
command, please contact John Chew.
EOF
  $this->{'names'} = [qw(stats statistics)];
  $this->{'argtypes'} = [qw()];
# print "names=@$namesp argtypes=@$argtypesp\n";

  return $this;
  }

sub new ($) { return TSH::Utility::new(@_); }

=item $command->Run($tournament, @parsed_args)

Should run the command in the context of the given
tournament with the specified parsed arguments.

=cut

sub Run ($$@) { 
  my $this = shift;
  my $tournament = shift;
  my $processor = $this->Processor();
  my $config = $tournament->Config();
  my $teams = $config->Value('show_teams');
  my (@divisions) = $tournament->Divisions();

  {
    my $saved_no_console_output = ($config->Value('no_console_output', 1)||0);
    for my $dp (@divisions) {
      my $dname = $dp->Name();
      my $extra = $teams ? "ts $dname;\n" : '';
      $processor->Process(<<"EOF");
$extra wc 1 $dname;
hw 1000 $dname;
hs 1000 $dname;
hl 1000 $dname;
hc 1000 $dname;
lw 1000 $dname;
ll 1000 $dname;
ls 1000 $dname;
upset 1000 $dname;
ave 1000 $dname;
aos 1000 $dname;
totalscore 1000 $dname;
stiff 6 $dname;
tuff 6 $dname
EOF
      }
    $config->Value('no_console_output', $saved_no_console_output);
  }
  if ($teams) {
    $processor->Process('tts');
    }

  my $logp = $this->{'log'} = new TSH::Log( $tournament, undef, 'stats', undef);
  $this->{'divisions'} = \@divisions;
  $this->{'config'} = $config;
  $logp->ColumnClasses([q(empty),(q(division)) x @divisions]);
  $logp->ColumnTitles(
    {
    'text' => [ '', map { 'Div. '.$_->Name() } @divisions ],
    'html' => [ '', map { "Division ".$_->Name() } @divisions ],
    }
    );
  $logp->ColumnClasses([q(label),(q(stat)) x @divisions]);
  $this->ShowNPlayers();
  $this->ShowRatings();
  my $track_firsts = $config->Value('track_firsts');
  $this->ShowGameStats($track_firsts);
  $this->ShowP12Stats() if $track_firsts && !$config->Value('assign_firsts');
  $logp->Close();
  }

sub ShowGameStats ($$) {
  my $this = shift;
  my $track_firsts = shift;
  my $logp = $this->{'log'};
  my $divisionsp = $this->{'divisions'};
  my (@firstwon, @stronger, @firstscore, @secondscore, @firstadv, @npoints,
    @ngames, @nties, @meanpoints, @meanspread, @rpperspread);
  my $t = $this->{'config'}->Terminology({map { $_ => [] } qw(
1stadv
1stadvantage
1stplayerscore
1stsc
1stwinp
1stwp
2ndplayerscore
2ndsc
gamesplayed
gamestied
gmsplayed
gmstied
meanpoints
meanpts
meansprd
meanspread
pointsscored
ptsscored
ratingpointsperspread
rpperspread
strongerwinp
strongerwp
    )});
  my (@round_npoints, @round_games); # TESTING 2012-05-12
  for my $dp (@$divisionsp) {
    my $rating_system = $dp->RatingSystem();
    my $ngames = 0;
    my $firstwon = 0;
    my $firstscore = 0;
    my $secondscore = 0;
    my $spread = 0;
    my $stronger = 0;
    my $stronger_by = 0;
    my $stronger_won_by = 0;
    my $ngames12 = 0;
    my $npoints = 0;
    my $nties = 0;
    for my $p ($dp->Players()) {
      my $pid = $p->ID();
      for my $r (1..$p->CountScores()) {
	my $r0 = $r - 1;
	my $oid = $p->OpponentID($r0);
	# count games only once, ignore byes
	next if $pid > $oid;
	my $opp = $p->Opponent($r0);
	my $ms = $p->Score($r0);
	my $os = $opp->Score($r0);
	$npoints += $ms + $os;
	$round_npoints[$r] += $ms + $os; $round_games[$r]++; # TESTING 2012-05-12
	$nties++ if $ms == $os;
	my $result = (($ms <=> $os) + 1)/2;
	my $prat = $p->Rating();
	my $orat = $opp->Rating();
	if ($rating_system->CompareRatings($prat, $orat) > 0) { 
	  $stronger += $result; 
	  $stronger_by += $rating_system->RatingDifference($prat, $orat);
	  $stronger_won_by += $ms - $os;
	  }
	elsif ($rating_system->CompareRatings($prat, $orat) < 0) {
	  $stronger += 1 - $result; 
	  $stronger_by -= $rating_system->RatingDifference($prat, $orat);
	  $stronger_won_by += $os - $ms;
	  }
	else { 
	  $stronger += $result == 0.5 ? 1 : 0.5; 
	  }
	my $this_firstwon = $p->First($r0);
	$spread += abs($ms - $os);
	if ($this_firstwon == 1) {
	  $firstwon += $result;
	  $firstscore += $ms;
	  $secondscore += $os;
	  $ngames12++;
	  }
	else {
	  $firstwon += 1 - $result;
	  $firstscore += $os;
	  $secondscore += $ms;
	  $ngames12++;
	  }
        $ngames++;
        }
      }
#   print ": $stronger/$ngames\n";
    push(@npoints, $npoints);
    push(@ngames, $ngames);
    push(@nties, $nties);
    push(@meanpoints, $ngames ? sprintf("%.1f", $npoints/$ngames) : 'NaN');
    push(@meanspread, $ngames ? sprintf("%.1f", $spread/$ngames) : 'NaN');
    push(@stronger, $ngames ? sprintf("%.1f%%", 100*$stronger/$ngames) : 'NaN');
    push(@firstwon, $ngames12 ? sprintf("%.1f%%", 100*$firstwon/$ngames12) : 'NaN');
    push(@firstscore, $ngames12 ? sprintf("%.1f", $firstscore/$ngames12) : 'NaN');
    push(@secondscore, $ngames12 ? sprintf("%.1f",$secondscore/$ngames12) : 'NaN');
    push(@firstadv, $ngames12 ? sprintf("%.1f", ($firstscore-$secondscore)/$ngames12) : 'NaN');
    push(@rpperspread, $stronger_won_by ? sprintf("%.2f", $stronger_by / $stronger_won_by) : 'NaN');
    }
# for my $r1 (1..$#round_npoints) { printf "%d %.1f\n", $r1, $round_games[$r1] ? $round_npoints[$r1]/$round_games[$r1] : 0; } # TESTING 2012-05-12
  $logp->WriteRow([$t->{'gmsplayed'}, @ngames], [$t->{'gamesplayed'}, @ngames]);
  $logp->WriteRow([$t->{'gmstied'}, @nties], [$t->{'gamestied'}, @nties]);
  $logp->WriteRow([$t->{'ptsscored'}, @npoints], [$t->{'pointsscored'}, @npoints]);
  $logp->WriteRow([$t->{'meanpts'}, @meanpoints], [$t->{'meanpoints'}, @meanpoints]);
  $logp->WriteRow([$t->{'meansprd'}, @meanspread], [$t->{'meanspread'}, @meanspread]);
  $logp->WriteRow([$t->{'strongerwp'}, @stronger], [$t->{'strongerwinp'}, @stronger]);
  $logp->WriteRow([$t->{'rpperspread'}, @rpperspread], [$t->{'ratingpointsperspread'}, @rpperspread]);
  if ($track_firsts) {
    $logp->WriteRow([$t->{'1stwp'}, @firstwon], [$t->{'1stwinp'}, @firstwon]);
    $logp->WriteRow([$t->{'1stsc'}, @firstscore], [$t->{'1stplayerscore'}, @firstscore]);
    $logp->WriteRow([$t->{'2ndsc'}, @secondscore], [$t->{'2ndplayerscore'}, @secondscore]);
    $logp->WriteRow([$t->{'1stadv'}, @firstadv], [$t->{'1stadvantage'}, @firstadv]);
    }
  }

sub ShowNPlayers ($) {
  my $this = shift;
  my $logp = $this->{'log'};
  my $divisionsp = $this->{'divisions'};
  my $t = $this->{'config'}->Terminology({map { $_ => [] } qw(
    regdplayers registeredplayers
    scrdplayers scoredplayers
    actvplayers activeplayers
    )});
  my @data1;
  my @data2;
  my @data3;
  for my $dp (@$divisionsp) {
    push(@data1, $dp->CountPlayers());
    $dp->CountByes();
    my $scored = 0;
    my $active = 0;
    for my $p ($dp->Players()) {
      $scored++ if $p->CountOpponents() > $p->Byes();
      $active++ if $p->Active();
      }
    push(@data2, $scored);
    push(@data3, $active);
    }
  $logp->WriteRow([$t->{'regdplayers'}, @data1], [$t->{'registeredplayers'}, @data1]);
  $logp->WriteRow([$t->{'scrdplayers'}, @data2], [$t->{'scoredplayers'}, @data2]);
  $logp->WriteRow([$t->{'actvplayers'}, @data3], [$t->{'activeplayers'}, @data3]);
  }

sub ShowP12Stats ($) {
  my $this = shift;
  my $logp = $this->{'log'};
  my $divisionsp = $this->{'divisions'};
  my $tournament = $this->Processor()->Tournament();
  my (@balanced, @offby1, @error);
  for my $dp (@$divisionsp) {
    my $ngames = 0;
    my @cume_first;
    my @cume_second;
    my @p12v;
    for my $p ($dp->Players()) {
      my $pid = $p->ID();
      my $this_p12v = $p->FirstVector();
      $p12v[$pid] = $this_p12v;
      my (@this_cume_first) = (0);
      my (@this_cume_second) = (0);
      if (@$this_p12v) {
	for my $r0 (0..$#$this_p12v) {
	  my $this_p12 = $this_p12v->[$r0];
	  $this_cume_first[$r0] = $this_cume_first[$r0-1];
	  $this_cume_second[$r0] = $this_cume_second[$r0-1];
	  $this_cume_first[$r0]++ if $this_p12 == 1;
	  $this_cume_second[$r0]++ if $this_p12 == 2;
	  }
	}
      $cume_first[$pid] = \@this_cume_first;
      $cume_second[$pid] = \@this_cume_second;
      }
    my $error = 0;
    my $scored = 0;
    my @error_by_pid;
    for my $p ($dp->Players()) {
      my $pid = $p->ID();
      my $this_p12v = $p12v[$pid];
      for my $r0 (1..$#$this_p12v) {
	my $oid = $p->OpponentID($r0);
	next if $pid > $oid;
	next unless defined $p->Score($r0);
	my $opp = $p->Opponent($r0);
	$scored++;
	my $this_p12 = $this_p12v->[$r0];
	if ($this_p12 == 1 && 
	  ($cume_first[$pid][$r0-1] <=> $cume_first[$oid][$r0-1]
	  || $cume_second[$oid][$r0-1] <=> $cume_second[$pid][$r0-1])
          > 0) {
#	  $tournament->TellUser('ebadp12', $p->TaggedName(), $opp->TaggedName(), $r0+1);
#	  warn "$p->{name} went first against $opp->{name} but shouldn't have" if $p->{name} =~ /Goldman, Stu/;
	  $error_by_pid[$pid] = [] unless defined $error_by_pid[$pid];
	  push(@{$error_by_pid[$pid]}, $r0+1, $p->Score($r0)-$opp->Score($r0));
	  $error++;
	  }
	elsif ($this_p12 == 2 && 
	  ($cume_first[$oid][$r0-1] <=> $cume_first[$pid][$r0-1]
	  || $cume_second[$pid][$r0-1] <=> $cume_second[$oid][$r0-1])
          > 0) {
#	  $tournament->TellUser('ebadp12', $opp->TaggedName(), $p->TaggedName(), $r0+1);
#	  warn "$p->{name} went second against $opp->{name} but shouldn't have" if $p->{name} =~ /Goldman, Stu/;
	  $error_by_pid[$oid] = [] unless defined $error_by_pid[$oid];
	  push(@{$error_by_pid[$oid]}, $r0+1, $opp->Score($r0)-$p->Score($r0));
	  $error++;
	  }
        }
      }
    for my $pid (sort { @{$error_by_pid[$b]||[]} <=> @{$error_by_pid[$a]||[]} } 
      0..$#error_by_pid) {
      my $data = $error_by_pid[$pid];
      next unless $data && @$data;
      $tournament->TellUser('ebadp12l', $dp->Player($pid)->TaggedName(), join(' ', map { sprintf("%d%+d", @$data[$_+$_,$_+$_+1]) } sort { $data->[$a+$a] <=> $data->[$b+$b]} (0..@$data/2-1)));
      }
    push(@error, $scored ? sprintf("%.1f%%", 100*$error/$scored) : 'NaN');
    }
  $logp->WriteRow(["1st/2nd Error%", @error], ['First/Second Error%', @error]);
  }

sub ShowRatings ($) {
  my $this = shift;
  my $logp = $this->{'log'};
  my $t = $this->{'config'}->Terminology({map { $_ => [] } 
    qw(
maximumrating
maxrating
meanrating
medianrating
medrating
minimumrating
minrating
mnrating
unratedplayers
unrplayers
    )});
  my $divisionsp = $this->{'divisions'};
  my (@mean, @min, @max, @median, @unrated);
  for my $dp (@$divisionsp) {
    my $rating_system = $dp->RatingSystem();
    my @ratings;
    for my $p ($dp->Players()) {
      push(@ratings, $p->Rating()) if $p->Active();
      }
    my $minr = $ratings[0];
    my $maxr = $ratings[0];
    my $count = scalar(@ratings);
    my $mean = $rating_system->AverageRatings(@ratings);
    @ratings = sort { $rating_system->CompareRatings($a, $b) } @ratings;
    for my $r (@ratings) {
      if ($r) { 
	$minr = $r if $rating_system->CompareRatings($minr, $r) > 0;
	$maxr = $r if $rating_system->CompareRatings($maxr, $r) < 0;
        }
      else {
	$count--;
        }
      }
    push(@min, $minr);
    push(@max, $maxr);
    push(@mean, $count ? sprintf("%.1f", $mean) : 'NaN');
    push(@median, @ratings == 0 ? 0 
      : @ratings % 2 ? $ratings[int(@ratings/2)]
      : ($rating_system->AverageRatings($ratings[@ratings/2],$ratings[@ratings/2-1])));
    push(@unrated, @ratings - $count);
    }
  $logp->WriteRow([$t->{'minrating'}, @min], [$t->{'minimumrating'}, @min]);
  $logp->WriteRow([$t->{'mnrating'}, @mean], [$t->{'meanrating'}, @mean]);
  $logp->WriteRow([$t->{'medrating'}, @median], [$t->{'medianrating'}, @median]);
  $logp->WriteRow([$t->{'maxrating'}, @max], [$t->{'maximumrating'}, @max]);
  $logp->WriteRow([$t->{'unrplayers'}, @unrated], [$t->{'unratedplayers'}, @unrated]);
  }

=back

=cut

=head1 BUGS

None known.

=cut


1;
