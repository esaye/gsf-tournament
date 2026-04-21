#!/usr/bin/perl

# Copyright (C) 2016 John J. Chew, III <poslfit@gmail.com>
# All Rights Reserved

package TSH::ParseArgs::NewPlayerNumber;

use strict;
use warnings;

use TSH::ParseArgs::Integer;
use TSH::ParseArgs::Player;
use TSH::Utility;

=pod

=head1 NAME

TSH::ParseArgs::NewPlayerNumber - handle a command-line argument that should be a new player number

=head1 SYNOPSIS

  my $parser = new TSH::ParseArgs::NewPlayerNumber;

=head1 ABSTRACT

This Perl module is used by C<ParseArgs.pm> to parse numbers that should be a new
player number.

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

=item $parserp = new ParserArgs::NewPlayerNumber

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
  $this->Minimum(1);
  $this->Maximum($matchdp ? $matchdp->CountPlayers()+1 : 100000);
  $this->Description('a new player number');
  return $this->SUPER::Parse($line_parser);
  }

=item $argument_description = $this->Usage()

Briefly describe this argument's usage (in a word or hyphenated phrase)

=cut

sub Usage ($) {
  my $this = shift;
  return 'new-player-number';
  }

=back

=cut

1;
