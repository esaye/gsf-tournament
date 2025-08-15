#!/usr/bin/perl

# Copyright (C) 2005 John J. Chew, III <jjchew@math.utoronto.ca>
# All Rights Reserved

package TSH::ParseArgs::OptionalPlayerList;

use strict;
use warnings;

use TSH::ParseArgs::OptionalInteger;
use TSH::ParseArgs::Player;
use TSH::Utility;

=pod

=head1 NAME

TSH::ParseArgs::OptionalRound - handle a command-line argument that should be a round number if present, but may be omitted

=head1 SYNOPSIS

  my $parser = new TSH::ParseArgs::OptionalPlayerList;

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
  $this->Minimum(1);
  return $this;
  }

=item $parserp = new ParserArgs::Topic;

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
  my @retval;
  my $pair_pending = 0;

  while ( defined (my $value = $line_parser->GetArg()) ) {
    if ( $value =~ /(\S+)\+(\S+)/ ) {
          $line_parser->UnGetArg($2);
	  $line_parser->UnGetArg($1);
	  push @retval, '+';
	  # Push a marker on the retval array to indicate the next two
	  # players are a pair (RPN rules ok)
      }
    else {
	$line_parser->UnGetArg($value);
      }
    # process "surname,given" or "D199" notation
    my $matchdp = $line_parser->GetShared('division');
    my $pp = TSH::ParseArgs::Player::CheckMatch($line_parser, $matchdp);
    if ($pp) {
      push @retval, $pp->ID();
      next;
      }
    # process default "123" notation
    $this->Maximum($matchdp ? $matchdp->CountPlayers() : 100000);
    $this->Minimum(0);
    $this->Description('a player number or 0');
    push @retval, $this->SUPER::Parse($line_parser);
    }
    return @retval
  }

=item $argument_description = $this->Usage()

Briefly describe this argument's usage (in a word or hyphenated phrase)

=cut

sub Usage ($) {
  my $this = shift;
  return '[p1 p2 p3 .... pN]';
  }

=back

=cut

1;
