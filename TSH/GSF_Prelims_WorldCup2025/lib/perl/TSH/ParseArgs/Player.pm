#!/usr/bin/perl

# Copyright (C) 2005 John J. Chew, III <jjchew@math.utoronto.ca>
# All Rights Reserved

package TSH::ParseArgs::Player;

use strict;
use warnings;

use TSH::ParseArgs::Integer;
use TSH::Utility;

=pod

=head1 NAME

TSH::ParseArgs::Player - handle a command-line argument that should be a player number

=head1 SYNOPSIS

  my $parser = new TSH::ParseArgs::Player;

=head1 ABSTRACT

This Perl module is used by C<ParseArgs.pm> to ignore command-line arguments.

=cut

=head1 DESCRIPTION

=over 4

=cut

our(@ISA) = qw(TSH::ParseArgs::Integer);

sub CheckMatch ($$);
sub initialise ($$);
sub new ($$);
sub Parse ($$);
sub Usage ($);

=item $pp = TSH::ParseArgs::Player::CheckMatch($line_parser, $matchdp);

Return a pointer to a player referred to on the command line 
using last,first syntax.

=cut

sub CheckMatch ($$) {
  my $line_parser = shift;
  my $matchdp = shift;
  my $tournament = $line_parser->Processor()->Tournament();
  if (my $matchpp = $line_parser->GetShared('player')) {
#   warn "found shared player\n";
    $line_parser->RemoveShared('player');
    return $matchpp;
    }
  my $value = $line_parser->GetArg();
  return undef unless defined $value;
  {
    my ($dp, $pn) = $tournament->CheckMatchDivPN($value);
    if ($pn) {
      if (ref($dp)) {
	$line_parser->SetShared('division', $dp);
	return $dp->Player($pn);
        }
      else {
	$line_parser->Error("'$dp' is not a valid division name.");
	return undef;
	}
      }
  }
  if ($value =~ /^(\S*),(\S*)$/ || $value =~ /^([^-\s\d]\S+)()$/i) {
    my $pp = $tournament->FindPlayer($1, $2, $matchdp);
#   warn "$value -> $pp->{'name'}, $matchdp";
#   warn "div=$matchdp->{'name'}" if $matchdp;
    if ($pp) {
      if (!$matchdp) { 
	$line_parser->SetShared('division', $pp->Division());
#	warn "Setting division to ".$pp->Division();
        }
# don't do following as it breaks multiple player commands like PAIR
#     $line_parser->SetShared('player', $pp);
      return $pp;
      }
    else {
      $line_parser->Error("Player match failed.");
      }
    }
  else {
    $line_parser->UnGetArg($value);
    }
  return undef;
  }

=item $parserp->initialise($processor);

Used internally to (re)initialise the object.

=cut

sub initialise ($$) {
  my $this = shift;
  $this->{'processor'} = shift;
  $this->Minimum(1);
  return $this;
  }

=item $parserp = new ParserArgs::Player($processor);

Create a new instance

=cut

sub new ($$) { TSH::Utility::new(@_); }

=item $argument_description = $this->Parse($line_parser)

Return the checked value of the command-line argument,
or () if the argument is invalid.

=cut

sub Parse ($$) {
  my $this = shift;
  my $line_parser = shift;
  # process "surname,given" or "D199" notation
  my $matchdp = $line_parser->GetShared('division');
  my $pp = TSH::ParseArgs::Player::CheckMatch($line_parser, $matchdp);
  return $pp->ID() if $pp;
  # process default "123" notation
  $this->Maximum($matchdp ? $matchdp->CountPlayers() : 100000);
  $this->Description('a player number');
  return $this->SUPER::Parse($line_parser);
  }

=item $argument_description = $this->Usage()

Briefly describe this argument's usage (in a word or hyphenated phrase)

=cut

sub Usage ($) {
  my $this = shift;
  return 'player-id';
  }

=back

=head1 BUGS

None known.

=cut

1;



