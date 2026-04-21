#!/usr/bin/perl

# ratings2.pl - Additional Perl library of routines for manipulating NSA Elo ratings

# $Id: ratings2.pl,v 1.3 2005/10/05 12:37:24 jjc Exp jjc $
#
# $Log: ratings2.pl,v $
# Revision 1.3  2005/10/05 12:37:24  jjc
# minor bug fixes
#
# Revision 1.2  2005/01/06 22:56:56  jjc
# ! cleanup
#

# Copyright (C) 1997-2005 by John J. Chew, III <jjchew@math.utoronto.ca>
# All Rights Reserved

=pod

=head1 NAME

ratings2.pl - library of routines for calculating Scrabble ratings

=head1 SYNOPSIS

  ratings2::UseClubDivisor(1);
  ratings2::CalculateSplitRatings(\@psp, $nrounds, \%key_map);

=head1 ABSTRACT

  This library is maintained for backward compatibility but now
  consists entirely of glue for Ratings::Elo (q.v.).

=cut

use warnings;
use strict;

package ratings2;

use Carp qw(confess);

my $elo = new Ratings::Elo(
  'maximum_iterations' => 25,
  'use_acceleration_bonuses' => 1,
  'use_club_divisor' => 0,
  'use_homan_boundary_bug' => 1,
  'use_homan_pr' => 1,
  'rating_system' => 'nsa2008',
  );

our $gVersion = '1.5';

sub CalculateAccelerationBonus ($$$$$);
sub CalculateExcess ($$$$$);
sub CalculateHomanPR ($$);
sub CalculateRatings ($$$$$$);
sub CalculateSegmentRatings ($$$$);
sub CalculateSegmentStandings ($$$$);
sub CalculateSplitRatings ($$$);
sub ConvertExcessToPoints ($$$);
sub CopyField ($$$);
sub CountAllEWins ($$$);
sub CountEWins ($$$);
sub MakeRoundToSplit (@);
sub MakeSplits ($);
sub Multiplier ($$);
sub RateNewcomers ($$$$);
sub RateNewcomersCorrectly ($$$$$);
sub RateNewcomersHoman ($$$$$);
sub RateVeterans ($$$$);
sub SetFeedbackToZero ($);
sub SetMaximumIterations ($);
sub SetupNewcomerPR ($$$$$);
# sub trunc ($);
sub UseAccelerationBonuses ($);
sub UseClubDivisor ($);

=head1 SUBROUTINES

=over 4

=cut

sub CalculateAccelerationBonus ($$$$$) { $elo->CalculateAccelerationBonus(@_); }

sub CalculateExcess ($$$$$) { $elo->CalculateExcess(@_); }

sub CalculateHomanPR ($$) { $elo->CalculateHomanPR(@_); }

sub CalculateRatings ($$$$$$) { $elo->CalculateRatings(@_); }

sub CalculateSegmentRatings ($$$$) { $elo->CalculateSegmentRatings(@_); }

sub CalculateSegmentStandings ($$$$) { $elo->CalculateSegmentStandings(@_); }

sub CalculateSplitRatings ($$$) { $elo->CalculateSplitRatings(@_); }

sub ConvertExcessToPoints ($$$) { $elo->ConvertExcessToPoints(@_); }

sub CopyField ($$$) { $elo->CopyField(@_); }

sub CountAllEWins ($$$) { $elo->CountAllEWins(@_); }

sub CountEWins ($$$) { $elo->CountEWins(@_); }

sub MakeRoundToSplit (@) { $elo->MakeRoundToSplit(@_); }

sub MakeSplits ($) { $elo->MakeSplits(@_); }

sub Multiplier ($$) { $elo->Multiplier(@_); }

sub RateNewcomers ($$$$) { $elo->RateNewcomers(@_); }

sub RateNewcomersCorrectly ($$$$$) { $elo->RateNewcomersCorrectly(@_); }

sub RateNewcomersHoman ($$$$$) { $elo->RateNewcomersHoman(@_); }

sub RateVeterans ($$$$) { $elo->RateVeterans(@_); }

sub SetFeedbackToZero ($) { $elo->SetFeedbackToZero(@_); }

sub SetMaximumIterations ($) { $elo->SetMaximumIterations(@_); }

sub SetupNewcomerPR ($$$$$) { $elo->SetupNewcomerPR(@_); }

# sub trunc ($) { int(0.5+100000*shift)/100000; }

sub UseAccelerationBonuses ($) { $elo->UseAccelerationBonuses(@_); }

sub UseClubDivisor ($) { $elo->UseClubDivisor(@_); }

=back

1;
