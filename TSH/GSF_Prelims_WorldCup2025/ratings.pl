#!/usr/bin/perl

# ratings.pl - Perl library of routines for manipulating NSA Elo ratings

# Copyright (C) 1996-2008 by John J. Chew, III <jjchew@math.utoronto.ca>
# All Rights Reserved

use Ratings::Elo;

use strict;
use warnings;

sub make_fmt_file ($);

my $elo = new Ratings::Elo();

sub erf ($) { my $x = shift; return $elo->Erf($x); }

sub erf2 ($) { my $x = shift; return $elo->Erf2($x); }

sub outcome ($$) { my $r1 = shift; my $r2 = shift;  return $elo->Outcome($r1, $r2); }

sub main::outcome_cached ($) { my $r = shift; return $elo->OutcomeCached($r); }

# @lines = &format_table($columns, @align, @row1, @row2, ...)
sub format_table ($@) { 
  my $columns = shift;
  my @data = shift;
  my($j, @align, @width, @lines);

  # initialise widths
  @width = (0) x $columns;

  # extract alignments
  @align = splice(@data, 0, $columns);

  # measure columns
  $j = 0;
  for my $i (@data) {
    my $l = length($i);
    $width[$j] = $l if $width[$j] < $l;
    $j = 0 if ++$j == $columns;
    }

  # format rows
  @lines = ();
  $j = 0;
  for my $i (@data) {
    my $pad = ' ' x ($width[$j] - length($i));
    push(@lines, '') unless $j;
    $lines[$#lines] .= ($align[$j] eq 'l') ? "$i$pad " : "$pad$i ";
    $j = 0 if ++$j == $columns;
    }

  for my $i (@lines) { $i =~ s/ $//; }
  return @lines;
  }

# $i = &round($f) - round to nearest integer
sub round ($) { int($_[0] + ($_[0] >=0 ? 0.5 : -0.5)); }

# very simple binary search
sub search ($$$) { 
  my $sub = shift;
  my $low = shift;
  my $high = shift;
  my $mid;
  while ($high - $low > 1) {
    $mid = int(($low+$high)/2);
    if (&$sub($mid) < 0) { $low = $mid; } else { $high = $mid; }
    }
  $mid;
  }

# very simple binary search
sub search4 ($$$$) { 
  my $sub = shift;
  my $low = shift;
  my $high = shift;
  my $thresh = shift;
  my $mid;
  while ($high - $low > $thresh) {
    $mid = ($low+$high)/2;
    if (&$sub($mid) < 0) { $low = $mid; } else { $high = $mid; }
    }
  $mid;
  }

# &load_ratings - load DOoM ratings database
sub load_ratings { 
  my $database = shift;
  my $lines_only = shift;
  local($_);

  if ((!-f "$database.fmt") || -M _ > -M "$database.db") {
    open my $fh, '<', "$database.db" || die "open($database.db): $!\n";
    while (<$fh>) { chop; s/\s*#.*$//; next unless length; @_ = split;
      for my $i (1..2) {
	my $player = $_[$i];
	$::rating{$player} = $_[6+$i];
	$::games{$player}++;
	my $spread = $_[2+$i] - $_[5-$i];
	if ($spread > 0) { $::wins{$player}++; }
	elsif ($spread < 0) { $::losses{$player}++; }
	else { $::ties{$player}++; }
	$::last{$player} = $_[0] if $::last{$player} < $_[0];
	}
      }
    close($fh);
    make_fmt_file $database;
    }
  {
    open my $fh, '<', "$database.fmt" || die "open($database.fmt): $!\n";
    while (<$fh>) { 
      last if $_ eq "EOF\n";
      push(@::lines, $_); 
      next if $lines_only;
      next unless /^\s*[-\d]/;
      chop;
      s/^\s+//;
      my ($rank, $player, @fields) = split(/\s+/);
      die "Bad line in $database.fmt: $_\n" unless $#fields == 4;
      ($::rating{$player}, $::wins{$player}, $::losses{$player}, $::ties{$player},
	$::last{$player}) = @fields;
      $::games{$player} = $::wins{$player} + $::losses{$player} + $::ties{$player};
      }
    close($fh);
  }
  die "$database.fmt is incomplete.\n" unless $_ eq "EOF\n";
  }

# &make_fmt_file - create DOoM cached results file
sub make_fmt_file ($) { 
  my $database = shift;
  my $players;

  open my $fh, '>', "$database.fmt"
    or die "open(>$database.fmt): $!\n";

  my (@cells) = (7, 'r', 'l', 'r', 'r', 'r', 'r', 'l', 'Rank', 'Player', 'Rating',
    'Won', 'Lost', 'Tied', 'Last');
  my $last=''; 
  my $rank=0; 
  my $tiedPlayers = 1;
  for (sort { 
    $::rating{$b} <=> $::rating{$a} ||
    $::wins{$b} <=> $::wins{$a} ||
    $::losses{$a} <=> $::losses{$b} ||
    $::ties{$b} <=> $::ties{$a} ||
    $::last{$b} <=> $::last{$a} ||
    $a cmp $b 
    } keys %::last) {
    my $thisrank;
    if (/^\*/) {
      next;
      $thisrank = '-';
      }
    else {
      if (length($last) && $::rating{$_} == $::rating{$last}
	&& $::wins{$_} == $::wins{$last} && $::losses{$_} == $::losses{$last}
	&& $::ties{$_} == $::ties{$last} && $::last{$_} == $::last{$last})
	{ $tiedPlayers++; }
      else { $rank+=$tiedPlayers; $tiedPlayers=1; $last=$_; }
      $thisrank = $rank;
      }
    $::wins{$_} = 0 unless defined $::wins{$_};
    $::losses{$_} = 0 unless defined $::losses{$_};
    $::ties{$_} = 0 unless defined $::ties{$_};
    push(@cells, $thisrank, $_, $::rating{$_}, $::wins{$_},
      $::losses{$_}, $::ties{$_}, $::last{$_});
    }
  print $fh join("\n", &format_table(@cells)), "\nEOF\n";
  close($fh);
  }
1;
