#!/usr/bin/perl

# Copyright (C) 2007-2010 John J. Chew, III <jjchew@math.utoronto.ca>
# All Rights Reserved

package TSH::Command::TUFFluck;

use strict;
use warnings;

use TSH::Log;
use TSH::Utility;
use TSH::ReportCommand::ExtremePlayers;
use TSH::Player::TuffLuck;

our (@ISA) = qw(TSH::ReportCommand::ExtremePlayers);

=pod

=head1 NAME

TSH::Command::TUFFluck - implement the C<tsh> TUFFluck command

=head1 SYNOPSIS

  my $command = new TSH::Command::TUFFluck;
  my $argsp = $command->ArgumentTypes();
  my $helptext = $command->Help();
  my (@names) = $command->Names();
  $command->Run($tournament, @parsed_arguments);
  
=head1 ABSTRACT

TSH::Command::TUFFluck is a subclass of TSH::ReportCommand::ExtremePlayers.

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
Use this command to display standings for a "Tuff Luck" prize, 
typically awarded to a player who loses six games by the smallest
combined spread.  The optional second argument, if given, specifies
a value other than "six".
EOF
  $this->{'names'} = [qw(tuff tuffluck)];
  $this->{'argtypes'} = [qw(OptionalInteger Division)];
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
  my $dp = pop @_;
  my $nscores = @_ ? shift @_ : 6;

  my $setupp = $this->SetupReport(
    'comparator' => sub ($$) {
      $_[0][0][0] <=> $_[1][0][0] || do {
	for (my $i=0; $i<$nscores; $i++) {
	  my $cmp = $_[0][0][1][$i] <=> $_[1][0][1][$i];
	  return $cmp if $cmp;
	  }
	0;
	}
      },
    'evaluator' => sub ($) {
      my $p = shift;
      return [$p->TuffLuck($nscores)];
      },
    'postfilter' => sub ($) {
      return $_[0][0][0];
      },
    'dp' => $dp,
    'max_entries' => $dp->CountPlayers(),
    'selector' => sub ($) { $_[0]->Active(); },
    'type' => 'tuffluck',
    );
  my @types;
  push(@types, qw(rank p-tuff p-losses p-wl p-spread));
  if ($setupp->{'has_classes'}) {
    push(@types, 'p-class');
    }
  push(@types, qw(p-name));
  $this->SetupColumns(@types);
  $this->WriteData(@types);
  }

=back

=cut

=head1 BUGS

None known.

=cut


1;

