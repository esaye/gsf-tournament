#!/usr/bin/perl

# Copyright (C) 2012 John J. Chew, III <jjchew@math.utoronto.ca>
# All Rights Reserved

package Ratings::Sudoku;

use strict;
use warnings;

use Sudoku;

our (@ISA) = qw(Ratings);

=pod

=head1 NAME

Ratings::Sudoku - code related to Sudoku rating system

=head1 SYNOPSIS

  my $name = Ratings::Sudoku::Canonicalise($string);
  
=head1 ABSTRACT

Ratings::Sudoku contains utility functions related to the Sudoku rating system.

=cut

=head1 DESCRIPTION

=over 4

=cut

my (%gNameFixes) = (
  );

sub Canonicalise ($);

=item $name = Ratings::Sudoku::Canonicalise($string);

Convert a NASPA name to WESPA form.

=cut

sub Canonicalise ($) {
  my $s = shift;
  return $gNameFixes{uc $s} || $s;
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

  my $datap = $dp->{'data'};
  Sudoku::CalculateRatings $r0, @$datap;
  }

=back

=cut

=head1 BUGS

The necessity of the existence of Canonicalise() is unfortunate.

Sudoku::CalculateRatings is in Sudoku.pm for historical reasons and should be moved here.

RateDivision should not directly access $dp->{'data'}.

=cut

1;

