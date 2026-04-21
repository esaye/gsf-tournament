#!/usr/bin/perl

# an early version of a subroutine that could still be useful for
# demonstrating the equivalence of its brute force algorithm to
# newer, cleverer ones
sub CalculateBestPossibleFinish ($$) {
  my $nrounds = shift;
  my $winsprsp = shift;
  for my $i (0..$#$winsprsp) { print "$winsprsp->[$i][0]/$winsprsp->[$i][1] "; } print "\n";
  my $me = pop @$winsprsp;
  return 1 unless @$winsprsp;
# print "I am $me->[0]/$me->[1].\n";
  my $spread = $nrounds == 1 ? 500 : $nrounds == 2 ? 400 : 300;
  for my $r (1..$nrounds) {
#   print "Subround $r.\n";
    my $leader = shift @$winsprsp;
    my $subleader;
#   print "The leader is $leader->[0]/$leader->[1].\n";
    $me->[0]++;
    $me->[1] += $spread;
    $leader->[1] -= $spread;
    if (@$winsprsp % 2) {
      $subleader = shift @$winsprsp;
#     print "The subleader is $subleader->[0]/$subleader->[1]\n";
      $subleader->[1] -= $spread;
      }
    if (@$winsprsp) {
#     print "\@\$w: @$winsprsp\n";
      my $half = @$winsprsp / 2;
      # all the lower half win
      for my $i ($half..$#$winsprsp) {
	$winsprsp->[$i][0]++;
        }
      # try to minimize spreads
      my (@top_spread_order) = sort
        { $winsprsp->[$a][1] <=> $winsprsp->[$b][1] } (0..$half-1);
      my (@bot_spread_order) = sort
        { $winsprsp->[$a][1] <=> $winsprsp->[$b][1] } ($half..$#$winsprsp);
#     print "half=$half\n";
#     print "@bot_spread_order\n";
#     my ($top_i, $bot_i, $spread_diff);
      for my $i (0..$half-1) {
	my $top_i = $top_spread_order[$i];
	my $bot_i = $bot_spread_order[$i];
#	print "$top_i vs. $bot_i\n";
	my $spread_diff = $winsprsp->[$top_i][1] - $winsprsp->[$bot_i][1];
	my $this_spread = 
	  $spread_diff > $spread + $spread ? $spread
	  : $spread_diff < 1 ? 1 : int($spread_diff/2);
#	print "/$winsprsp->[$top_i][1] vs $winsprsp->[$bot_i][1] -> $this_spread\n";
	$winsprsp->[$top_i][1] -= $this_spread;
	$winsprsp->[$bot_i][1] += $this_spread;
        }
      }
    push(@$winsprsp, $leader);
    push(@$winsprsp, $subleader) if $subleader;
    @$winsprsp = sort { $b->[0] <=> $a->[0] || $b->[1] <=> $a->[1] } @$winsprsp;
    if (($me->[0] <=> $winsprsp->[0][0] || $me->[1] <=> $winsprsp->[0][1]) >= 0) {
#     print "I can finish #1.\n";
      return 1;
      }
    }
  for my $i (0..$#$winsprsp) { print "$winsprsp->[$i][0]/$winsprsp->[$i][1] "; } print "\n";
  print "I ended up $me->[0]/$me->[1].\n";
  for my $i (0..$#$winsprsp) { 
    if (($me->[0] <=> $winsprsp->[$i][0] 
      || $me->[1] <=> $winsprsp->[$i][1]) >= 0) {
#     print "I can finish #" . ($i+1) . ".\n";
      return $i+1;
      }
    }
  return scalar(@$winsprsp);
  }


