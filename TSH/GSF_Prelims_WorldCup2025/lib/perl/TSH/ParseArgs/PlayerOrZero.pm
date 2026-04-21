#!/usr/bin/perl

# Copyright (C) 2005 John J. Chew, III <jjchew@math.utoronto.ca>
# All Rights Reserved

package TSH::ParseArgs::PlayerOrZero;

use strict;
use warnings;

use TSH::ParseArgs::Integer;
use TSH::ParseArgs::Player;
use TSH::Utility;

=pod

=head1 NAME

TSH::ParseArgs::PlayerOrZero - handle a command-line argument that should be a player number (or zero)

=head1 SYNOPSIS

  my $parser = new TSH::ParseArgs::PlayerOrZero;

=head1 ABSTRACT

This Perl module is used by C<ParseArgs.pm> to ignore command-line arguments.

=cut

=head1 DESCRIPTION

=over 4

=cut

our(@ISA) = qw(TSH::ParseArgs::Integer);

sub initialise ($);
sub new ($);
sub Parse ($$);
sub Usage ($);

=item $parserp->initialise();

Used internally to (re)initialise the object.

=cut

sub initialise ($) {
  my $this = shift;
  $this->Minimum(0);
  return $this;
  }

=item $parserp = new ParserArgs::PlayerOrZero

Create a new instance

=cut

sub new ($) { TSH::Utility::new(@_); }

=item $argument_description = $this->Parse($line_parser)

Return the checked value of the command-line argument,
or () if the argument is invalid.

=cut

sub Parse ($$) {
  my $this = shift;
  my $line_parser = shift;
  my $matchdp = $line_parser->GetShared('division');
  my $pp = TSH::ParseArgs::Player::CheckMatch($line_parser, $matchdp);
  return $pp->ID() if $pp;
  $this->Maximum($matchdp ? $matchdp->CountPlayers() : 100000);
  $this->Description('a player number or zero for a bye');
  return $this->SUPER::Parse($line_parser);
  }

=item $argument_description = $this->Usage()

Briefly describe this argument's usage (in a word or hyphenated phrase)

=cut

sub Usage ($) {
  my $this = shift;
  return 'player-or-zero';
  }

=back

=cut

1;
