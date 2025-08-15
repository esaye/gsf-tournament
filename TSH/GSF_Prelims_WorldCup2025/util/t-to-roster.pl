#!/usr/bin/perl

use strict;
use warnings;

use lib './lib/perl';
use lib '/Users/jjc/local/tsh/lib/perl';
use TFile;

sub Main ();
sub Munge ();

$config::pnfmt = '%03d';
Main;

sub Main () {
  @::ARGV = ('a.t') unless @::ARGV;
  (@::ARGV) = sort { length($a) <=> length($b) || $a cmp $b } @::ARGV;
  my $dn = 1;
# print "pn\trating\tname\tactive\tname\tteam\n";
  my (@out);
  my %names;
  for my $fname (@::ARGV) {
    my ($lines) = (`wc -l $fname`) =~ /(\d+)/;
    $lines = length($lines);
    $config::pnfmt = "%0${lines}d" if $lines > 2;
    my $tf = new TFile $fname;
    die "Can't open $fname: $!" unless $tf;
    my (@ps) = (undef);
    while (my $p = $tf->ReadLine()) {
      push(@ps, $p);
      }
    $tf->Close();
    for my $i (1..$#ps) {
      my $p = $ps[$i];
      my $s = sprintf "$dn-$config::pnfmt\t%d\t%s\t%s\t", 
        $i, $p->{'rating'}, (exists $p->{'etc'}{'off'} ? 'no' : 'yes'),
	$p->{'name'};
      if ($p->{'etc'}{'team'}) {
	$s .= "$p->{'etc'}{'team'}[0]\t";
        }
      my $lcname = lc $p->{'name'};
      for my $word (split(/\W/, $lcname)) {
	push(@{$names{$word}}, scalar(@out)) if length($word) && $lcname ne lc $word;
	}
      push(@out, $s);
      }
    $dn++;
    }
  my @names;
  while (my ($word, $namesp) = each %names) {
    if (@$namesp == 1) {
      push(@{$names[$namesp->[0]]}, $word);
      }
    }
  for my $i (0..$#out) {
    print $out[$i];
    push(@{$names[$i]}, $i+1) if @::ARGV == 1;
    print join(',', @{$names[$i]}) if $names[$i];
#   print ',' . ($i+1) if @::ARGV == 1;
    print "\n";
    }
  }

