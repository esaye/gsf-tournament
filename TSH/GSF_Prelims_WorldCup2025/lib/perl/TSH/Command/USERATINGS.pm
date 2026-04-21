#!/usr/bin/perl

# Copyright (C) 2008-2018 John J. Chew, III <poslfit@gmail.com>
# All Rights Reserved

package TSH::Command::USERATINGS;

use strict;
use warnings;

use TSH::Log;
use TSH::Utility;

our (@ISA) = qw(TSH::Command);

=pod

=head1 NAME

TSH::Command::USERATINGS - implement the C<tsh> USERATINGS command

=head1 SYNOPSIS

  my $command = new TSH::Command::USERATINGS;
  my $argsp = $command->ArgumentTypes();
  my $helptext = $command->Help();
  my (@names) = $command->Names();
  $command->Run($tournament, @parsed_arguments);
  
=head1 ABSTRACT

TSH::Command::USERATINGS is a subclass of TSH::Command.

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
Use this command to update all player ratings according to the ratings
that you have downloaded using the UPDATERATINGS command.
EOF
  $this->{'names'} = [qw(useratings)];
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
  my (@divisions) = $tournament->Divisions();

  $tournament->LoadRatings();
  if (my $processor = $this->Processor()) { # can fail when headless
    $processor->Flush();
    }

  # warn of bad membership status
  my (@now7) = localtime(time+7*86400);
  my $now7 = sprintf("%4d-%02d-%02d", $now7[5]+1900, $now7[4]+1, $now7[3]);
  my (@now) = localtime(time);
  my $now = sprintf("%4d-%02d-%02d", $now[5]+1900, $now[4]+1, $now[3]);
  for my $dp ($tournament->Divisions()) {
    my $ratings_list = $dp->RatingList();
#   warn $ratings_list;
    if ($ratings_list eq 'nsa' || $ratings_list eq 'naspa-csw') {
      for my $p ($dp->Players()) {
	my $expiry = $p->Expiry();
	if ($expiry && $expiry ne 'not an expiry') {
	  if ($expiry =~ /^(?:suspended|x+)$/i) {
	    $tournament->TellUser('wusersusp', $p->TaggedName())
	    }
	  elsif ($expiry =~ /exp/i || $expiry lt $now) {
# 	    warn "$expiry, $now";
	    $tournament->TellUser('wuserexp', $p->TaggedName())
	    }
	  elsif ($expiry lt $now7) {
	    $tournament->TellUser('wuserexp7', $p->TaggedName(), $expiry)
	    }
	  }
	else {
	  $tournament->TellUser('wusernotm', $p->TaggedName())
	  }
	}
      }
    }
  }

=back

=cut

=head1 BUGS

None known.

=cut


1;
