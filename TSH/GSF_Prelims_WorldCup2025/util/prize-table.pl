#!/usr/bin/perl

use strict;
use warnings;

use Getopt::Long;
use List::Util qw(max min sum);
use Math::Round qw(nhimult nlowmult);

sub Initialise ();
sub Main ();
sub Report ($);
sub Usage ();

my $ndivisions;
my @depth;
my @entryFee;
my @fixedPrizes;
my @nplayers;
my @minPrize;
my @percentage;
my @quantum;
my @topAmount;
my @topPercentage;

my @divisionPrizes;
my @rows;

Main;

sub Initialise () {
  GetOptions(
    "players=s@" => \@nplayers,
    "entry_fee=s@" => \@entryFee,
    "fixed_prizes=s@" => \@fixedPrizes,
    "percentage=s@" => \@percentage,
    "quantum=s@" => \@quantum,
    "top_percentage=s@" => \@topPercentage,
    "top_amount=s@" => \@topAmount,
    "depth=s@" => \@depth,
    "min_prize=s@" => \@minPrize,
    ) or Usage;

  for my $argdata (
    ['players', \@nplayers, 'i'],
    ['entry_fee', \@entryFee, 'i'],
    ['min_prize', \@minPrize, 'i'],
    ['fixed_prizes', \@fixedPrizes, 's'],
    ['percentage', \@percentage, 'f'],
    ['top_percentage', \@topPercentage, 'f'],
    ['top_amount', \@topAmount, 'i'],
    ['quantum', \@quantum, 'i'],
    ['depth', \@depth, 'i'],
    ) {
    my ($name, $arrayp, $type) = @$argdata;
    next unless @$arrayp;
    my $s = join(',', @$arrayp);
    if ($type eq 'i' && $s !~ /^(\d+)(,\d+)*$/) {
      warn "Expected list of nonnegative integers for $name, not $s.\n\n";
      Usage;
      }
    if ($type eq 'f' && $s !~ /^(\d+\.?|\d*\.\d+)(,(?:\d+\.?|\d*\.\d+))*$/) {
      warn "Expected list of nonnegative real numbers for $name, not $s.\n\n";
      Usage;
      }
    @$arrayp = split(/,/, $s);
    if ($ndivisions && $ndivisions != @$arrayp) {
      warn "Number of divisions is inconsistent across options.\n\n";
      Usage;
      }
    $ndivisions = @$arrayp;
    }

  unless ($ndivisions) {
    warn "You must specify at least one division's options.\n\n";
    Usage;
    }

  unless (@entryFee) {
    warn "You must specify entry fees.\n\n";
    Usage;
    }

  unless (@nplayers) {
    warn "You must specify the number of players.\n\n";
    Usage;
    }

  unless (@percentage) {
    warn "You must specify prize percentages.\n\n";
    Usage;
    }
  }

sub Main () {
  Initialise;
  
  for my $division (1..$ndivisions) {
    Report $division;
    }
  print join("\t", qw(div ef np sumef sumprz left prz% fixed prizes)), "\n";
  print @rows;
  }

sub Report ($) {
  my $division = shift;
  my $d0 = $division - 1;
  my $nplayers = $nplayers[$d0];
  my $entryFee = $entryFee[$d0];
  my $totalEF = $nplayers * $entryFee;
  my $fixedPrizes = $fixedPrizes[$d0];
  my $percentage = $percentage[$d0];
  my $totalPrize = $percentage * $totalEF / 100;
  my $prizeLeft = $totalPrize;
  my $quantum = $quantum[$d0];
  my $depth = $depth[$d0] || min(10, $nplayers/4);
  my @prizes;

  unless ($quantum) {
    $quantum = $totalPrize / 100;
    $quantum =~ s/\..*//;
    if ($quantum == 0) { $quantum = 1; }
    elsif ($quantum =~ s/^1/A/) { $quantum =~ s/\d/0/g; $quantum =~ s/^A/1/; }
    elsif ($quantum =~ s/^[234]./A/) { $quantum =~ s/\d/0/g; $quantum =~ s/^A/25/; }
    elsif ($quantum =~ s/^[234]/A/) { $quantum =~ s/\d/0/g; $quantum =~ s/^A/2/; }
    else { $quantum =~ s/\d/0/g; $quantum =~ s/^0/5/; }
    }

  if ($ndivisions > 1) {
    warn "==========\n" if $division > 1;
    warn "Division $division\n\n";
    }

  if ($fixedPrizes) {
    $prizeLeft -= $fixedPrizes;
    }

  if (my $topAmount = $topAmount[$d0]) {
    push(@prizes, $topAmount);
    }
  else {
    my $topPercentage = $topPercentage[$d0] || 
      min(30, $percentage);
    push(@prizes, nhimult($quantum, $totalEF * $topPercentage / 100));
    }
  if ($division > 1 && $prizes[0] > $divisionPrizes[-1][0]) {
    # top prizes must be non-increasing down divisions
    $prizes[0] = $divisionPrizes[-1][0];
    }
  $prizeLeft -= $prizes[0];

  if (my $adjust = nhimult($quantum, $prizeLeft) - $prizeLeft) {
    $adjust = nhimult(0.00001, $adjust);
    warn "Adjusting prize fund upward by $adjust to be a multiple of $quantum.\n";
    $prizeLeft = nhimult($quantum, $prizeLeft);
    }

  warn "Total EF = $totalEF = $entryFee * $nplayers\n";
  warn "Nominal prize fund = $totalPrize = $totalEF * $percentage%\n";
  warn "Fixed prizes = $fixedPrizes\n" if $fixedPrizes;
  warn "Net prize fund = ",$prizes[0] + $prizeLeft, "\n";

  if ($depth > 1) {
    my (@placePrizes) = $minPrize[$d0] || (nhimult($quantum, $entryFee));
    for my $place (3..$depth) {
      unshift(@placePrizes, $placePrizes[0] + $quantum);
      }
    for my $prize (@placePrizes) {
      push(@prizes, $prize);
      $prizeLeft -= $prize;
      }
    if ($prizeLeft < 0) {
      die "Insufficient prize fund ($totalPrize) to pay down to place $depth in increments of $quantum.  Awarding @prizes leaves a deficit of $prizeLeft.\nAborting"; 
      }
    }

  for (my $place = 2; $place <= $depth && $prizeLeft > 0; $place++) {
    my $prize = max(nlowmult($quantum, $prizeLeft/2), $quantum);
    my $gap = $prizes[$place-2] - $prizes[$place-1];
    if ($prize > $gap) { $prize = $gap; }
    $prizes[$place-1] += $prize;
    $prizeLeft -= $prize;
    if ($division > 1 && $divisionPrizes[-1][$place-1]) {
      my $excess = $prizes[$place-1] - $divisionPrizes[-1][$place-1];
      if ($excess > 0) {
	$prizes[$place-1] -= $excess;
	$prizeLeft += $excess;
        }
      }
    }

  warn "Prizes: @prizes\n";
  warn "Unassigned: $prizeLeft\n";
  push(@divisionPrizes, \@prizes);
  my $sum = sum($fixedPrizes, @prizes);
  push(@rows, join("\t", $division, $entryFee, $nplayers, $totalEF, $sum, $prizeLeft, nhimult(0.1, 100*$sum/$totalEF - 0.05), $fixedPrizes, @prizes). "\n");
  }

sub Usage () {
  die "Usage: $0 --players n --entry_fee amount --fixed_prizes amount\n" .
    "  --percentage percent --top_percentage percent --top_amount amount\n".
    "  --quantum amount --depth n\n".
    "\n".
    "For multidivision events, enter options multiple times, or once\n".
    "with values separated by commas.  If you specify an option for one\n".
    "division, you must specify it for all of them, even if some values\n".
    "are left blank ('') or zero.\n".
    "\n".
    "--players n (required) number of players\n".
    "--entry_fee amt (required) entry fee\n".
    "--fixed_prizes amt (optional, default 0) fixed prizes, e.g., high word\n".
    "--percentage p (required) percentage of EF to return as prizes\n".
    "--top_percentage p (optional) percentage of EF to pay to 1st place\n".
    "--top_amount amt (optional) amount to pay to 1st place\n".
    "--quantum amt (optional, default complex) prizes must be a multiple\n".
    "--depth n (optional, default min(10,players/4)) how deep to pay out\n".
    "--min_prize amt (optional, default entry_fee) minimum prize payable\n".
    "\n".
    "If you specify both top_amount and top_percentage, the latter takes\n".
    "precedence.  If neither, top_amount defaults to the lesser of 30%\n".
    "and half the net prize fund (after fixed prizes are deducted).\n".
    "";
    
  }

