#!/usr/bin/perl

# Copyright (C) 2012 John J. Chew, III <jjchew@math.utoronto.ca>
# All Rights Reserved

package Ratings::None;

use strict;
use warnings;

our (@ISA) = qw(Ratings);

=pod

=head1 NAME

Ratings::None - code related to null rating system

=head1 SYNOPSIS

  my $name = Ratings::None::Canonicalise($string);
  
=head1 ABSTRACT

Ratings::None contains utility functions related to the null rating system.

=cut

=head1 DESCRIPTION

=over 4

=cut

sub AverageRatings ($@) { return 0; }

sub Canonicalise ($);

=item $name = Ratings::None::Canonicalise($string);

Apply no changes to canonicalise a name.

=cut

sub Canonicalise ($) {
  return;
  }

sub CompareRatings ($$$) {
  return 0;
  }

sub initialise ($) {
  my $this = shift;
  my (%argh) = @_;
  $this->{'rating_system'} = $argh{'rating_system'};
  }

sub new ($) { return TSH::Utility::newshared(@_); }

sub RateDivision ($@) {
  my $this = shift;
  my (%argh) = @_;
  my $dp = $argh{'division'};
  my $r0 = $argh{'r0'};

  for my $p ($dp->Players()) { 
    $p->NewRating($r0, $p->Rating()); 
    }
  }

=back

=cut

=head1 BUGS

None known.

=cut

1;

