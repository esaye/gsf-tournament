#!/usr/bin/perl

# Copyright (C) 2022 John J. Chew, III <poslfit@gmail.com>
# All Rights Reserved

package TSH::Command::ConfirmUnconfirmedScores;

use strict;
use warnings;

use TSH::Utility;

our (@ISA) = qw(TSH::Command);

=pod

=head1 NAME

TSH::Command::ConfirmUnconfirmedScores - implement the C<tsh> ConfirmUnconfirmedScores command

=head1 SYNOPSIS

  my $command = new TSH::Command::ConfirmUnconfirmedScores;
  my $argsp = $command->ArgumentTypes();
  my $helptext = $command->Help();
  my (@names) = $command->Names();
  $command->Run($tournament, @parsed_arguments);
  
=head1 ABSTRACT

TSH::Command::ConfirmUnconfirmedScores is a subclass of TSH::Command.

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
Use this command to confirm all pending unconfirmed scores that have
been entered using the AddProvisionalScore command, typically via
'config accept_remote_commands = 1'.  Confirmed scores will be logged
to autoconfirm.txt.
EOF
  my $config = $this->Processor()->Tournament()->Config();
  $this->{'names'} = [qw(confirmunconfirmedscores cus)];
  $this->{'argtypes'} =
    [qw(Round Division)];
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
  my ($round, $dp) = @_;
  my $round0 = $round - 1;
  my $dirty = 0;

  for my $p ($dp->Players()) {
    next if defined $p->Score($round0);
    my $opp = $p->Opponent($round0);
    next unless $opp;
    next if defined $opp->Score($round0);
    my ($ms, $os) = $p->RoundProvisionalScore($round0);
    next unless (defined $ms) and (defined $os);
    open my $ofh, '>>', $config->MakeRootPath('autoconfirm.txt');
      print $ofh join(' ', $p->ID(), $ms, $opp->ID(), $os, $round), "\n";
    close $ofh;
    $dirty++;
    $p->Score($round0, $ms);
    $opp->Score($round0, $os);
    $p->RoundProvisionalScore($round0, undef, undef);
    $opp->RoundProvisionalScore($round0, undef, undef);
    my $now = time;
    $p->Time($now);
    $opp->Time($now);
    }

  if ($dirty) {
    $dp->Dirty(1);
    $dp->DirtyRound($round0);
    $this->Processor()->Flush();
    if (my $cmds = $config->Value('hook_addscore_flush')) {
      $this->Processor()->RunHook('hook_addscore_flush', $cmds,
	{ 'nohistory' => 1,
	  'noconsole' => $config->Value('quiet_hooks') 
	  { 'd' => $dp->Name(), 'r' => $round },
	},
	);
      }
    }
  }

=back

=cut

=head1 BUGS

Needs support for game lexicon tags.

=cut

1;
