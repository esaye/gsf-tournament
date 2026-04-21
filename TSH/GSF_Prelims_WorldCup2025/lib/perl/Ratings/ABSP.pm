#!/usr/bin/perl

# Copyright (C) 2010-2012 John J. Chew, III <jjchew@math.utoronto.ca>
# All Rights Reserved

package Ratings::ABSP;

use strict;
use warnings;

use ABSP;

our (@ISA) = qw(Ratings);

=pod

=head1 NAME

Ratings::ABSP - code related to ABSP rating system

=head1 SYNOPSIS

  my $name = Ratings::ABSP::Canonicalise($string);
  
=head1 ABSTRACT

Ratings::ABSP contains utility functions related to the ABSP rating system.

=cut

=head1 DESCRIPTION

=over 4

=cut

my (%gNameFixes) = (
  'LAMABADUSURIYA, HARSHAN' => 'Lama\'suriya, Harshan',
# 'NI BHRIAIN, BRID' => 'Ui_Bhriain, Brid',
  'OWOLABI, PHILIPS LUKEMAN' => 'Owolabi, Lukeman',
  'NI BHRIAIN, BRID' => 'O\'Brien, Breda',
  'WINTER' => 'Winter, Winter',
  'ZXQKJ, WINTER' => 'Winter, Winter',
  'RAU, TERRY KANG' => 'Rau, Terry_Kang',
  'TAN, JIN CHOR' => 'Tan, Jin_Chor',
  'OKWELOGU, CHINEDU NOSIKE' => 'Okwelogu, Chinedu',
  'OWOLABI, LUKEMAN' => 'Owolabi, Philips',
  'BARRATT, LINDA' => 'Barratt, Linda{Lincoln}',
  'USAKIEWICZ, WOJCIECH' => 'Usakiewicz, Wojtek',
  'MORRIS, PAM' => 'Morris, Pamela',
  'TOH, WEIBIN' => 'Weibin, Toh',
  );

sub Canonicalise ($);

=item $name = Ratings::ABSP::Canonicalise($string);

Convert a NASPA name to WESPA form.

=cut

sub Canonicalise ($) {
  my $s = shift;
  if (my $s2 = $gNameFixes{uc $s}) { return $s2; }
  $s =~ s/([^,]) /$1_/g;
  return $s;
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
  ABSP::CalculateRatings $r0, @$datap;
  }

=back

=cut

=head1 BUGS

The necessity of the existence of Canonicalise() is unfortunate.

ABSP::CalculateRatings is in ABSP.pm for historical reasons and should be moved here.

RateDivision should not directly access $dp->{'data'}.

=cut

1;

