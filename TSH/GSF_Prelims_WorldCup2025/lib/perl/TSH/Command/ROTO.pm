#!/usr/bin/perl

# Copyright (C) 2005 John J. Chew, III <jjchew@math.utoronto.ca>
# All Rights Reserved

package TSH::Command::ROTO;

use strict;
use warnings;

use TSH::Log;
use TSH::Utility;
use JavaScript::Serializable;

our (@ISA) = qw(TSH::Command);

=pod

=head1 NAME

TSH::Command::ROTO - implement the C<tsh> ROTO command

=head1 SYNOPSIS

  my $command = new TSH::Command::ROTO;
  my $argsp = $command->ArgumentTypes();
  my $helptext = $command->Help();
  my (@names) = $command->Names();
  $command->Run($tournament, @parsed_arguments);
  
=head1 ABSTRACT

TSH::Command::ROTO is a subclass of TSH::Command.

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
Use the ROTO command to list current standings in a rotisserie
pool, configured using "config rotofile".
If you specify a round number, standings are shown for that round.
If you don't, current standings are shown.
EOF
  $this->{'names'} = [qw(roto)];
  $this->{'argtypes'} = [qw(OptionalRound)];
# print "names=@$namesp argtypes=@$argtypesp\n";

  return $this;
  }

sub MungeName ($$$) {
  my $this = shift;
  my $tournament = shift;
  my $name = shift;
  my $ndivisions = $tournament->CountDivisions();
  if ($ndivisions == 1) {
    if ($name =~ /^\d+$/) {
      my $dp = ($tournament->Divisions())[0];
      if ($name > 0 && $name <= $dp->CountPlayers()) {
	return $dp->Player($name)->Name();
	}
      }
    }
  elsif ($name =~ /^([A-Z]+)(\d+)$/i) {
    my $dname = $1;
    my $pn = $2;
    my $dp = $tournament->GetDivisionByName($dname);
    if ($pn > 0 && $pn <= $dp->CountPlayers()) {
      return $dp->Player($pn)->Name();
      }
    }
  return $name;
  }

sub new ($) { return TSH::Utility::new(@_); }

sub ProcessPlayer ($$$$$) {
  my $this = shift;
  my $tournament = shift;
  my $playersp = shift;
  my $datap = shift;
  my $round = shift;
  my $computed_round = shift;
  my $name = shift;

  my $p = $tournament->GetPlayerByName($this->MungeName($tournament, $name));
  if (!defined $p) {
    $tournament->TellUser('erotounp', $., $name);
    return;
    }
  my $did = $p->Division()->Name() . $p->ID();
  if ($playersp->{$did}++) {
    $tournament->TellUser('erotodup', $., $name);
    return;
    }
  push(@{$datap->{'players'}}, $p);
  if ($round) {
    $datap->{'wins'} += $p->{'twins'} = $p->RoundWins($round - 1);
    $datap->{'spread'} += $p->{'tspread'} = $p->RoundSpread($round - 1);
    }
  else {
    $datap->{'wins'} += $p->{'twins'} = $p->Wins();
    $datap->{'spread'} += $p->{'tspread'} = $p->Spread();
    my $n = $p->CountScores();
    unless (defined $n) { warn $p->Name() . ' has no scores?!'; }
    $computed_round = $n if $computed_round < $n;
    }
  $p->{'twins'} =~ s/\.5/+/;
  return (1, $computed_round);
  }

=item $command->Run($tournament, @parsed_args)

Should run the command in the context of the given
tournament with the specified parsed arguments.

=cut

sub Run ($$@) { 
  my $this = shift;
  my $tournament = shift;
  my $ndivisions = $tournament->CountDivisions();
  my ($round) = @_;
  my $round0 = ($round||0) - 1;
  my $config = $tournament->Config();
  my $rotofile = $config->Value('rotofile');
  unless ($rotofile) { $tournament->TellUser('erotocfg'); return; }
  my $fn = $config->MakeRootPath($rotofile);
  my $fh = TSH::Utility::OpenFile("<", $fn);
  unless ($fh) { $tournament->TellUser('erotoope', $fn, $!); return; }
  local($/) = "\n\n";
  my @teams;
  my $team_size;
  my $computed_round = 0;
  my @position_division; # which divisions have members in which positions on teams
  my $fail = 0;
  while (<$fh>) {
    s/^\n+//; 
    next unless /\S/;
    die "blank line in record: $_" if /\n\s+\n/;
    my (@lines) = split(/\n/);
    my %players;
    my (%data);
    for my $line (@lines) {
      next unless $line =~ /\S/;
      $line =~ s/\s+$//;
      my ($command, $args) = split(/\s+/, $line, 2);
      if ($command eq 'raw') {
	my (@players) = split(/\s+/, $args);
	$data{'owner'} = $this->MungeName($tournament, shift @players);
	for my $player (@players) { 
	  my $success;
	  ($success, $computed_round) = $this->ProcessPlayer($tournament, \%players, \%data, $round, $computed_round, $player);
          $fail++ unless $success;
	  }
        }
      elsif ($command eq 'owner') {
	if ($data{'owner'}) {
	  $tournament->TellUser('erotoown', $., $data{'owner'}, $args);
	  return;
	  }
	$data{'owner'} = $this->MungeName($tournament, $args);
        }
      elsif ($command eq 'player') {
	my $success;
	($success, $computed_round) = $this->ProcessPlayer($tournament, \%players, \%data, $round, $computed_round, $args);
	$fail++ unless $success;
        }
      else {
	$tournament->TellUser('erotosyn', $line);
	$fail++;
        }
      }
    if (defined $team_size) {
      my $this_team_size = scalar(@{$data{'players'}});
      if ($team_size != $this_team_size) {
#	warn join(";", map { $_->Name() } @{$data{'players'}});
	$tournament->TellUser('erotosiz', $data{'owner'}, $this_team_size,
          $team_size, join(' ', map { $_->TaggedName() } @{$data{'players'}}));
	$team_size = $this_team_size;
        }
      }
    else {
      $team_size = scalar(@{$data{'players'}});
      }
    push(@teams, \%data ) if %data;
    }
  unless (defined $team_size) {
    $tournament->TellUser('erotoempty');
    $fail++;
    }
  return if $fail;
  my $logp = new TSH::Log($tournament, undef, 'roto', $round || $computed_round);
  $logp->Write(
    sprintf("%3s "
      . '%5s '
      . "%-30s %s\n", ' W ', 
      ' Sprd',
      'Owner', (' ' x 19) . 'Team'),
    "<tr class=top1><th class=wins>Wins</th>"
      . '<th class=spread>Spread</th>'
      . "<th class=owner>Owner</th><th class=team colspan=$team_size>Team</th></tr>\n");
  my $even = 1;
  my (@data);
  for my $team (sort { $b->{'wins'} <=> $a->{'wins'} || 
    $b->{'spread'} <=> $a->{'spread'} ||
    lc($a->{'owner'}) cmp lc($b->{'owner'}) } @teams) {
    $even = 1 - $even;
    my $teamwins = $team->{'wins'};
    $teamwins =~ s/\.5/+/ or $teamwins .= ' ';
    $logp->Write(
      sprintf("%3s %+5d %-27.27s" . ('%6s' x $team_size) . "\n",
	$teamwins,
	$team->{'spread'},
	$team->{'owner'},
	map { 
	  my $s = sprintf("%3s%1s%03d",
	    $_->{'twins'},
            ($ndivisions == 1 ? '-' : uc($_->{'division'}{'name'})),
#	    uc($_->{'division'}{'name'}),
	    $_->{'id'},
	    );
	  $s =~ s/(\d+)\+-/ $1+/;
	  $s;
	} @{$team->{'players'}}),
      sprintf("<tr class=%s><td class=wins>%s</td>"
        . '<td class=spread>%+d</td>'
	. "<td class=owner>%s</td>\n" 
	. ("<td class=team>%s</td>\n" x $team_size) . "</tr>\n",
	$even ? 'even' : 'odd',
	$teamwins,
	$team->{'spread'},
	$team->{'owner'},
	map { 
          my $s = $_->TaggedName();
	  if ($s =~ /(.*) \((.*)\)/) {
	    $s = sprintf("%s<br>%s %s %+d\n", $1, $2, $_->{'twins'},
	      $_->{'tspread'});
	    }
	  $s;
	  } @{$team->{'players'}}),
        );
    push(@data, {
      'w' => $team->{'wins'},
      's' => $team->{'spread'},
      'o' => $team->{'owner'},
      'p' => [
	map { { 'n' => $_->Name(),
	  'd' => $_->Division()->Name(),
	  'i' => $_->ID(),
	  'w' => $_->{'twins'},
	  's' => $_->{'tspread'},
	  } } @{$team->{'players'}}
	]
      });
    }
  $logp->Close();
  $fn = $config->MakeHTMLPath('roto.json');
  $fh = TSH::Utility::OpenFile(">:encoding(utf-8)", $fn);
  if ($fh) {
    print $fh JavaScript::Serializable::ToJavaScriptAny(\@data);
    close $fh;
    }
  }

=back

=cut

1;
