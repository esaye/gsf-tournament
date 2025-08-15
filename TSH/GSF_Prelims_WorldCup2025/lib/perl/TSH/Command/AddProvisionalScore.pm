#!/usr/bin/perl

# Copyright (C) 2022 John J. Chew, III <poslfit@gmail.com>
# All Rights Reserved

package TSH::Command::AddProvisionalScore;

use strict;
use warnings;

use TSH::Utility;

our (@ISA) = qw(TSH::Command);

=pod

=head1 NAME

TSH::Command::AddProvisionalScore - implement the C<tsh> AddProvisionalScore command

=head1 SYNOPSIS

  my $command = new TSH::Command::AddProvisionalScore;
  my $argsp = $command->ArgumentTypes();
  my $helptext = $command->Help();
  my (@names) = $command->Names();
  $command->Run($tournament, @parsed_arguments);
  
=head1 ABSTRACT

TSH::Command::AddProvisionalScore is a subclass of TSH::Command.

=cut

=head1 DESCRIPTION

=over 4

=cut

sub initialise ($$);
sub new ($$);
sub Run ($$@);

=item $parserp->initialise($processor)

Used internally to (re)initialise the object.

=cut

sub initialise ($$) {
  my $this = shift;

  $this->SUPER::initialise(@_);
  $this->{'help'} = <<'EOF';
Use this command to add a provisional score from the command line.
The score will remain provisional until a matching provisional score
is entered with the player numbers and scores reversed.
This command is intended primarily for scripted use.
EOF
  my $config = $this->Processor()->Tournament()->Config();
  $this->{'names'} = [qw(addprovisionalscore aps)];
  $this->{'argtypes'} =
    [qw(PlayerOrZero PlayerOrZero Score Score Round Division)];
  return $this;
  }

sub new ($$) { return TSH::Utility::new(@_); }

=item $command->Run($tournament, @parsed_args)

Should run the command in the context of the given
tournament with the specified parsed arguments.

=cut

# TODO: split this up into smaller subs for maintainability

sub Run ($$@) { 
  my $this = shift;
  my $tournament = shift;
  my $config = $tournament->Config();
  my ($pn1, $pn2, $ps1, $ps2, $round, $dp) = @_;
  my $round0 = $round - 1;

  if ($pn1 == 0) { ($pn1, $pn2, $ps1, $ps2) = ($pn2, $pn1, $ps2, $ps1); }
  if ($pn1 == 0) {
    $tournament->TellUser('ebothbye');
    return;
    }

  my $pp1 = $dp->Player($pn1);
  unless ($pp1) { $tournament->TellUser('enosuchp', $pn1); return; }

  # check round
  if ($pp1->CountScores() + 1 != $round) {
    $tournament->TellUser('eapsbr', $pp1->CountScores()+1, $round);
    return;
    }

  # check $pn1 vs. $pn2 pairing
  if (my $n = $pp1->OpponentID($round0)) { # has opponent
    if ($n != $pn2) {
      $tournament->TellUser('ebadpair', 
	$pn1, $pp1->Name(),
	$n, $dp->Player($n)->Name()//'bye',
	$pn2, $dp->Player($pn2)->Name()//'bye',
	);
      return;
      }
    }
  else { # bye or unpaired
    if (!defined $n) {
      $tournament->TellUser('eapsnoop');
      return;
      }
    if ($pn2 != 0) {
      $tournament->TellUser('ebadpair', 
	$pn1, $pp1->Name(),
	0, 'bye',
	$pn2, $dp->Player($pn2)->Name()//'bye',
	);
      }
    if ($ps2 != 0) {
      $tournament->TellUser('ebadbos', $ps2);
      return;
      }
    if ($ps1 != ($config->Value('bye_spread')//50)) {
      $tournament->TellUser('ebadobs', $ps1);
      return;
      }
    # might as well finish dealing with the bye case
    $pp1->Score($round0, $ps1);
    $dp->Dirty(1);
    $dp->DirtyRound($round0);
    $this->Processor()->Flush();
    return;
    }

  my ($olds1, $olds2) = $pp1->RoundProvisionalScore($round0, $ps1, $ps2);
  $dp->Dirty(1);
  
  if ((defined $olds2) and ($olds1 != $ps1 or $olds2 != $ps2)) {
    # note the old replaced scores, if any
    $tournament->TellUser('inewps', $olds1, $olds2);
    }

  my $pp2 = $dp->Player($pn2);
  unless ($pp2) { $tournament->TellUser('enosuchp', $pn2); return; }

  ($olds2, $olds1) = $pp2->RoundProvisionalScore($round0);

  if (defined $olds1) { # opponent had entered score
    if ($olds1 == $ps1 and $olds2 == $ps2) { # promote provisional to actual
      $pp1->Score($round0, $ps1);
      $pp2->Score($round0, $ps2);
      $pp1->RoundProvisionalScore($round0, undef, undef);
      $pp2->RoundProvisionalScore($round0, undef, undef);
      my $now = time;
      $pp1->Time($now);
      $pp2->Time($now);
      $dp->Dirty(1);
      $dp->DirtyRound($round0);
      $this->Processor()->Flush();
      if (my $cmds = $config->Value('hook_addscore_flush')) {
	$this->Processor()->RunHook('hook_addscore_flush', $cmds,
	  { 'nohistory' => 1,
	    'noconsole' => $config->Value('quiet_hooks') },
	  { 'd' => $dp->Name(), 'r' => $round },
	  );
	}
      $tournament->TellUser('iapsok2');
      }
    else {
      $tournament->TellUser('iapsbad', $olds1, $olds2);
      }
    }
  else {
    $tournament->TellUser('iapsok');
    }
  $this->Processor()->Flush();
  }

=back

=cut

=head1 BUGS

Needs support for game lexicon tags.

=cut

1;
