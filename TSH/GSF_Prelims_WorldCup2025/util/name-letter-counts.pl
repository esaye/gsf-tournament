#!/usr/bin/perl

# name-letter-counts.pl - count how many names in a t file have each letter of the alphabet
#
# Usage: util/name-letter-counts.pl tfile...

use strict;
use warnings;

use lib './lib/perl';
use lib '/Users/jjc/local/tsh/lib/perl';
use Getopt::Long;
use TFile;

sub Main ();
sub Munge ();

Main;

sub Main () {
  my $result = GetOptions(
    );
  @::ARGV = ('a.t') unless @::ARGV;
  my (@out);
  my %names;
  my %lettersByName;
  my $nplayers;
  for my $fname (@::ARGV) {
    my $tf = new TFile $fname;
    die "Can't open $fname: $!" unless $tf;
    while (my $p = $tf->ReadLine()) {
      my %lettersByPlayer;
      $nplayers++;
      # make a hash whose keys are the letters in this player's name
      for my $letter (split('', lc $p->{name})) {
	next if $letter =~ /[,\s]/;
	$lettersByPlayer{$letter}++;
	}
      # update a hash mapping letters in player names to numbers of players with those letters
      for my $letter (keys %lettersByPlayer) {
	$lettersByName{$letter}++;
	}
      }
    $tf->Close();
    }
  for my $letter (sort { $lettersByName{$a} <=> $lettersByName{$b} } keys %lettersByName) {
    printf "%s %s %.1f\n", $letter, $lettersByName{$letter},
      $lettersByName{$letter} * 100 / $nplayers;
    }
  }

