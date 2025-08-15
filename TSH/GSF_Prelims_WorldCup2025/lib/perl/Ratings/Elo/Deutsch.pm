#!/usr/bin/perl

# Copyright (C) 2010 John J. Chew, III <jjchew@math.utoronto.ca>
# All Rights Reserved

package Ratings::Elo::Deutsch;

use strict;
use warnings;
use Carp;

BEGIN {
  use Exporter ();
  use vars qw(
    $VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS
    );
  $VERSION = do { my @r = (q$Revision: 1.1 $ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r }; 
  @ISA = qw(Exporter);
  @EXPORT = qw();
  @EXPORT_OK = qw(
    erf erf2 outcome outcome_cached
    );
  %EXPORT_TAGS = ();
  }

=head1 SYNOPSIS

  use Ratings::Elo::Deutsch;

=head1 ABSTRACT

This Perl module contains code for performing German Scrabble rating calculations,
and is used by the Ratings::Elo module.

=cut

=head1 DESCRIPTION

=head2 Methods

=over 4

=cut

=item $hashp = Ratings::Elo::Deutsch->GetParameters();

Return this rating system's parameters to Ratings::Elo.

=cut

sub GetParameters ($) {
  my $class = shift;
  return {
    'expectation_function' => 'Ratings::Elo::Deutsch::ExpectGerman',
    'maximum_iterations' => 6,
    };
  }

=item $expected = ExpectGerman($rating_system, $rating1, $rating2);

Return the expected proportion of wins by a player rated $rating1 over a player rated $rating2.

=cut

sub ExpectGerman ($$$) {
  my $rs = shift;
  my $rating1 = shift;
  my $rating2 = shift;
  return 0.5 + ($rating1 - $rating2) / 1200;
  }

=head2 BUGS

None known.

=cut

1;
