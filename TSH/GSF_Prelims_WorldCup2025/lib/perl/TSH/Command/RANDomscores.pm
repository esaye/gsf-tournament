#!/usr/bin/perl

# Copyright (C) 2005-2010 John J. Chew, III <jjchew@math.utoronto.ca>
# All Rights Reserved

package TSH::Command::RANDomscores;

use strict;
use warnings;

use TSH::Utility;

our (@ISA) = qw(TSH::Command);

=pod

=head1 NAME

TSH::Command::RANDomscores - implement the C<tsh> RANDomscores command

=head1 SYNOPSIS

  my $command = new TSH::Command::RANDomscores;
  my $argsp = $command->ArgumentTypes();
  my $helptext = $command->Help();
  my (@names) = $command->Names();
  $command->Run($tournament, @parsed_arguments);
  
=head1 ABSTRACT

TSH::Command::RANDomscores is a subclass of TSH::Command.

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
Use this command to add a round of random scores to a division
for testing purposes.
EOF
  $this->{'names'} = [qw(rand randomscores)];
  $this->{'argtypes'} = [qw(Divisions)];
# print "names=@$namesp argtypes=@$argtypesp\n";

  return $this;
  }

sub new ($) { return TSH::Utility::new(@_); }

=item $command->Run($tournament, @parsed_args)

Should run the command in the context of the given
tournament with the specified parsed arguments.

=cut

# TODO: split this up into smaller subs for maintainability

sub Run ($$@) { 
  my $this = shift;
  my $tournament = shift;
  my $config = $tournament->Config();
  my $track_firsts = $config->Value('track_firsts');
  my $scores = uc ($config->Value('scores')||'scrabble');

  for my $dp (@_) {
    my $rsname = $dp->RatingSystemName();
    my $distrib = $scores;
    if ($scores eq 'SCRABBLE') {
      $distrib = $rsname =~ /^absp$/i 
        ? 'absp' : $rsname =~ /^(?:glixo|wespa)/i 
	? 'glixo' : $rsname eq 'none'
	? 'none' : 'nsa';
      }
    $tournament->TellUser('irandok', $dp->Name());
    my $round1 = $dp->LeastScores() + 1;
    for my $p ($dp->Players()) {
      my $nscores = $p->CountScores();
      next if $nscores >= $round1;
      next if $nscores >= $p->CountOpponents();
      my $rating = $p->Rating();
      $rating = 0 unless $rating and $rating =~ /[1-9]/;
      if ($p->{'pairings'}[$nscores]) {
	if ($distrib eq 'WL') {
	  my $opp = $p->Opponent($nscores);
	  my $rdiff = $rating - $opp->Rating();
	  my $pwin = rand(1) < ($rdiff/400 + 0.5);
	  $p->Score($nscores, $pwin ? 2 : 0);
	  $opp->Score($nscores, $pwin ? 0 : 2);
  	  }
	else {
	  $rating =~ s/\D.*//; # Glixo
	  my $opp = $p->Opponent($nscores);
	  my $opprat = $opp->Rating();
	  $opprat =~ s/\D.*//; # Glixo
	  my $rdiff = $rating - $opprat;
# $rdiff=0; warn "Assuming players of equal strength";
	  push(@{$p->{'scores'}}, 
#	    # based on the NSA Club #3 2004-2005 season
#	      ? int(130*log(($rating||1000)/75) +rand(200)-100) :
 	    $distrib =~ /^(?:nsa|glixo)$/
	    # normally distributed with sigma = 90 and mean = 400 + rdiff/5/2 
	    # so that spread is rdiff/5 per Glixo
	    # using Box-Muller method
	      ? int(sqrt(-2*log(rand(1)))*cos(2*3.141592653589793*rand(1))
	        * 90 + 400 + $rdiff/10)
	    : int(250+rand(50+($rating>200?200:$rating))));
	  }
	if ($track_firsts) {
	  my $r0 = $#{$p->{'scores'}};
	  my $first = int(rand(2));
	  my $p12p = $p->{'etc'}{'p12'};
	  if ($p12p->[$r0] != 1 && $p12p->[$r0] != 2) {
	    $p12p->[$r0] = 1 + $first;
	    }
	  $p12p = $p->Opponent($r0)->{'etc'}{'p12'};
	  if ($p12p->[$r0] != 1 && $p12p->[$r0] != 2) {
	    $p12p->[$r0] = 2 - $first;
	    }
	  }
	}
      else {
	if ($distrib eq 'SUDOKU') {
	  my $score = int(0.5+rand($rating/20));
	  $score = 100 if $score > 100;
	  $p->Score($nscores, $score);
  	  }
	else {
  	  push(@{$p->{'scores'}}, $config->Value('bye_spread')||0);
	  }
        }
      printf "%s: @{$p->{'scores'}}\n", (TSH::Utility::TaggedName $p);
      }
    if (my $cmds = $config->Value('hook_division_complete')->{$dp->Name()}) {
      $this->Processor()->RunHook('hook_division_complete', $cmds, 
	{ 'nohistory' => 1,
	  'noconsole' => $config->Value('quiet_hooks') },
	{'r' => $round1, 'd' => $dp->Name() } );
      }
    $dp->Dirty(1);
    $this->Processor()->Flush();
    }
  $tournament->TellUser('idone');
  }

=back

=cut

1;
