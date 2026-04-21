#!/usr/bin/perl

# Copyright (C) 2009-2018 John J. Chew, III <poslfit@gmail.com>
# All Rights Reserved

package TSH::Command::NAST;

use strict;
use warnings;

use TSH::Utility;

our (@ISA) = qw(TSH::PairingCommand);
our ($pairings_data_6, $pairings_data_8);

=pod

=head1 NAME

TSH::Command::NAST - implement the C<tsh> NAST command

=head1 SYNOPSIS

  my $command = new TSH::Command::NAST;
  my $argsp = $command->ArgumentTypes();
  my $helptext = $command->Help();
  my (@names) = $command->Names();
  $command->Run($tournament, @parsed_arguments);
  
=head1 ABSTRACT

TSH::Command::NAST is a subclass of TSH::PairingCommand.

=cut

=head1 DESCRIPTION

=over 4

=cut

sub GetPairings ($$);
sub GetPairings6 ($);
sub GetPairings8 ($);
sub initialise ($$$$);
sub new ($);
sub PairNASTGroup ($$);
sub Run ($$@);

sub GetPairings ($$) {
  my $np = shift;
  my $max_round1 = shift;
  if ($max_round1 == 5 || $max_round1 == 6) {
    return GetPairings6($np);
    }
  elsif ($max_round1 == 7 || $max_round1 == 8) {
    return GetPairings8($np);
    }
  else { 
    die "Assertion failed: np=$np max_round1=$max_round1";
    }
  }

sub GetPairings6 ($) {
  my $np = shift;
  my @pairings1_by_round0;
  my $raw = $pairings_data_6;
  # strip everything before our section
  $raw =~ s/^[^\0]*NAST\s+Pairings\s*-\s*$np\s+Players.*\n//
    or return undef;
  # strip everything after our section, if any
  $raw =~ s/NAST Pairings[^\0]*//;
  # strip headers
  $raw =~ s/(?:KOT?H|Round|Swiss).*\n//g;
  for my $line (split(/\n/, $raw)) {
    my $r0 = 0;
    $line =~ s/(?:\s*-\s*)*$//;
    while ($line =~ s/^(\d+)\s+-\s+(\d+)\s*//) {
      my (@p) = ($1, $2);
      for my $i (0..1) {
	die if defined $pairings1_by_round0[$r0][$p[$i]];
	$pairings1_by_round0[$r0][$p[$i]] = $p[1-$i];
        }
      $r0++;
      }
    die "Can't parse: $line\nAborting" if length($line);
    }
  return \@pairings1_by_round0;
  }

sub GetPairings8 ($) {
  my $np = shift;
  my @pairings1_by_round0;
  my $raw = $pairings_data_8;
  # strip everything before our section
  $raw =~ s/^[^\0]*NAST\s+Pairings\s*-\s*$np\s+Players.*\n//
    or return undef;
  # strip everything after our section, if any
  $raw =~ s/NAST Pairings[^\0]*//;
  # strip headers
  $raw =~ s/(?:KOT?H|Round|Swiss|No |\* For).*\n//g;
  my $r0 = 0;
  for my $line (split(/\n/, $raw)) {
    my $r0 = 0;
    $line =~ s/(?:\s*-\s*)*$//;
    while ($line =~ s/^\s*(\d+)\s+-\s+(\d+)\s*//) {
      my (@p) = ($1, $2);
      for my $i (0..1) {
	die "r0=$r0 p1=$p[0] p2=$p[1]" if defined $pairings1_by_round0[$r0][$p[$i]];
	$pairings1_by_round0[$r0][$p[$i]] = $p[1-$i];
        }
      $r0++;
      }
    die "Can't parse: $line\nAborting" if length($line);
#     if ($line =~ /^(\d+)\s+-\s+(\d+)\s*$/) {
#       my (@p) = ($1, $2);
# #     warn "$r0 @p";
#       for my $i (0..1) {
# 	die "assertion failed: already have pairings for player $p[$i] in round $r0+1: $pairings1_by_round0[$r0][$p[$i]]"
# 	  if defined $pairings1_by_round0[$r0][$p[$i]];
# 	$pairings1_by_round0[$r0][$p[$i]] = $p[1-$i];
#         }
#       $r0++;
#       }
#     elsif ($line =~ /^\s*-\s*$/) {
#       $r0 = 0;
#       }
#     else {
#       die "Can't parse: $line\nAborting" if length($line);
#       }
    }
  return \@pairings1_by_round0;
  }

=item $parserp->initialise()

Used internally to (re)initialise the object.

=cut

sub initialise ($$$$) {
  my $this = shift;
  my $path = shift;
  my $namesp = shift;
  my $argtypesp = shift;

  $this->{'help'} = <<'EOF';
Use this command to compute the initial fixed schedule of pairings 
at satellite events of the
North American Scrabble Tour, which may be five or six rounds long.
Depending on the number of players, that fixed schedule may be
four or five rounds long, to be followed by Swiss and KOTH rounds.
EOF
  $this->{'names'} = [qw(nast)];
  $this->{'argtypes'} = [qw(Division)];
# print "names=@$namesp argtypes=@$argtypesp\n";

  return $this;
  }

sub new ($) { return TSH::Utility::new(@_); }

=item $command->PairNASTGroup($psp);

Used internally to pair a group of 5-48 players NAST style in rounds
1-4.

=cut

sub PairNASTGroup ($$) {
  my $this = shift;
  my $psp = shift;
  my $tournament = $this->Processor()->Tournament();
  my $dp = $this->{'dp'};

  my $np = scalar(@$psp);
  my $np2 = $np + ($np % 2);
  my $pairingsp = GetPairings($np2, $dp->MaxRound0()+1);
  unless (defined $pairingsp) { 
    # should not happen
    $tournament->TellUser('enastnp', $np); 
    return; 
    }
  for my $r0 (0..$#$pairingsp) {
    my $round_pairingsp = $pairingsp->[$r0];
    for my $pn1 (1..$#$round_pairingsp) {
      my $on1 = $round_pairingsp->[$pn1];
      if ($on1 == $np2 && $np < $np2) { $on1 = 0; }
      if ($np < $np2) {
	if ($on1 == $np2) { $on1 = 0; }
	elsif ($pn1 == $np2) { next; }
        }
      next if $pn1 < $on1;
#     warn "$pn1 $on1 $np2";
      $dp->Pair($psp->[$pn1-1]->ID(), $on1 ? $psp->[$on1-1]->ID() : 0, $r0, 0);
      }
    }
  }

=item $command->PairNASTGroups($psp);

Used internally to pair an arbitrary number of players NAST style
in rounds 1-4, by calling PairNASTGroup() as necessary.

=cut

sub PairNASTGroups ($$) {
  my $this = shift;
  my $psp = shift;
  my $np = scalar(@$psp);
  my $tournament = $this->Processor()->Tournament();
  if ($np <= 48) { 
    $this->PairNASTGroup($psp);
    }
  elsif ($np <= 96) {
    my (@snake1, @snake2);
    for my $i (0..$#$psp) {
      my $column = $i % 4;
      if ($column % 3) { 
	push(@snake2, $psp->[$i]);
#	warn "    $i\n";
        }
      else {
	push(@snake1, $psp->[$i]);
#	warn "$i\n";
        }
      }
    if (@snake1 % 2 && @snake2 % 2) {
      push(@snake1, pop @snake2);
      }
    $this->PairNASTGroup(\@snake1);
    $this->PairNASTGroup(\@snake2);
    }
  else
    { $tournament->TellUser('enastnp', $np); return; }
  }

=item $command->Run($tournament, @parsed_args)

Should run the command in the context of the given
tournament with the specified parsed arguments.

=cut

# TODO: split this up into smaller subs for maintainability

sub Run ($$@) { 
  my $this = shift;
  my $tournament = shift;
  my ($dp) = $this->{'dp'} = shift;
  if ($dp->LastPairedRound0() != -1) 
    { $tournament->TellUser('ehaspair', $dp->Name());  return; }
  my $max_rounds = $dp->MaxRound0();
  unless (defined $max_rounds) {
    $tournament->TellUser('eneed_max_rounds'); return; 
    }
  $max_rounds++;
  if ($max_rounds < 5 || $max_rounds > 8) 
    { $tournament->TellUser('enastsix'); return; }
  my $setupp = $this->SetupForPairings('division' => $dp, 'source0' => -1,
    'nobye' => 1) 
    or return 0;
  my $psp = $setupp->{'players'};
  $this->PairNASTGroups($psp);
# $dp->Dirty(1); # handled by $dp->Pair();
  $this->Processor()->Flush();
  }


# from http://www.bachster.com/scrabble/NAST/NASTPairingTables.html
$pairings_data_6 = <<'EOF';
NAST Pairings - 6 Players
KOH
Round 1			Round 2			Round 3			Round 4			Round 5			Round 6
1	-	6	1	-	5	1	-	4	1	-	3	1	-	2		-
2	-	5	6	-	4	5	-	3	4	-	2	3	-	6		-
3	-	4	2	-	3	6	-	2	5	-	6	4	-	5		-
NAST Pairings - 8 Players	 (Group A = 1,4,5,8; Group B = 2,3,6,7; A plays B)
Swiss			KOH
Round 1			Round 2			Round 3			Round 4			Round 5			Round 6
1	-	7	1	-	6	1	-	3	1	-	2		-			-
4	-	6	4	-	3	4	-	2	4	-	7		-			-
5	-	3	5	-	2	5	-	7	5	-	6		-			-
8	-	2	8	-	7	8	-	6	8	-	3		-			-
NAST Pairings - 10 Players	 (Group A = 1,4,5,8,9; Group B = 2,3,6,7,10; A plays B)
KOH
Round 1			Round 2			Round 3			Round 4			Round 5			Round 6
1	-	10	1	-	7	1	-	6	1	-	3	1	-	2		-
4	-	7	4	-	6	4	-	3	4	-	2	4	-	10		-
5	-	6	5	-	3	5	-	2	5	-	10	5	-	7		-
8	-	3	8	-	2	8	-	10	8	-	7	8	-	6		-
9	-	2	9	-	10	9	-	7	9	-	6	9	-	3		-
NAST Pairings - 12 Players	 (Two groups of 6, paired for even field partial RR)
Swiss			KOH
Round 1			Round 2			Round 3			Round 4			Round 5			Round 6
1	-	9	1	-	8	1	-	5	1	-	4		-			-
12	-	8	9	-	5	8	-	4	5	-	12		-			-
4	-	5	12	-	4	9	-	12	8	-	9		-			-
2	-	10	2	-	7	2	-	6	2	-	3		-			-
11	-	7	10	-	6	7	-	3	6	-	11		-			-
3	-	6	11	-	3	10	-	11	7	-	10		-			-
NAST Pairings - 14 Players	 (One groups of 6, one group of 8, paired for even field partial RR)
Swiss			KOH
Round 1			Round 2			Round 3			Round 4			Round 5			Round 6
1	-	11	1	-	9	1	-	6	1	-	4		-			-
14	-	9	11	-	6	9	-	4	6	-	14		-			-
4	-	6	14	-	4	11	-	14	9	-	11		-			-
2	-	12	2	-	10	2	-	5	2	-	3		-			-
7	-	10	7	-	5	7	-	3	7	-	12		-			-
8	-	5	8	-	3	8	-	12	8	-	10		-			-
13	-	3	13	-	12	13	-	10	13	-	5		-			-
NAST Pairings - 16 Players	 (Two groups of 8, paired for even field partial RR)
Swiss			KOH
Round 1			Round 2			Round 3			Round 4			Round 5			Round 6
1	-	13	1	-	9	1	-	8	1	-	4		-			-
5	-	9	5	-	8	5	-	4	5	-	13		-			-
12	-	8	12	-	4	12	-	13	12	-	9		-			-
16	-	4	16	-	13	16	-	9	16	-	8		-			-
2	-	14	2	-	10	2	-	7	2	-	3		-			-
6	-	10	6	-	7	6	-	3	6	-	14		-			-
11	-	7	11	-	3	11	-	14	11	-	10		-			-
15	-	3	15	-	14	15	-	10	15	-	7		-			-
NAST Pairings - 18 Players	 (Three groups of 6, paired for even field partial RR)
Swiss			KOH
Round 1			Round 2			Round 3			Round 4			Round 5			Round 6
1	-	13	1	-	12	1	-	7	1	-	6		-			-
18	-	12	13	-	7	12	-	6	7	-	18		-			-
6	-	7	18	-	6	13	-	18	12	-	13		-			-
2	-	14	2	-	11	2	-	8	2	-	5		-			-
17	-	11	14	-	8	11	-	5	8	-	17		-			-
5	-	8	17	-	5	14	-	17	11	-	14		-			-
3	-	15	3	-	10	3	-	9	3	-	4		-			-
16	-	10	15	-	9	10	-	4	9	-	16		-			-
4	-	9	16	-	4	15	-	16	10	-	15		-			-
NAST Pairings - 20 Players	 (Two groups of 6, one group of 8, paired for even field partial RR)	210
Swiss			KOH
Round 1			Round 2			Round 3			Round 4			Round 5			Round 6
1	-	15	1	-	14	1	-	7	1	-	6		-			-
20	-	14	15	-	7	14	-	6	7	-	20		-			-
6	-	7	20	-	6	15	-	20	14	-	15		-			-
2	-	16	2	-	13	2	-	8	2	-	5		-			-
19	-	13	16	-	8	13	-	5	8	-	19		-			-
5	-	8	19	-	5	16	-	19	13	-	16		-			-
3	-	17	3	-	11	3	-	10	3	-	4		-			-
9	-	11	9	-	10	9	-	4	9	-	17		-			-
12	-	10	12	-	4	12	-	17	12	-	11		-			-
18	-	4	18	-	17	18	-	11	18	-	10		-			-
NAST Pairings - 22 Players	 (One group of 6, two groups of 8, paired for even field partial RR)
Swiss			KOH
Round 1			Round 2			Round 3			Round 4			Round 5			Round 6
1	-	17	1	-	16	1	-	7	1	-	6		-			-
22	-	16	17	-	7	16	-	6	7	-	22		-			-
6	-	7	22	-	6	17	-	22	16	-	17		-			-
2	-	18	2	-	12	2	-	11	2	-	5		-			-
8	-	12	8	-	11	8	-	5	8	-	18		-			-
15	-	11	15	-	5	15	-	18	15	-	12		-			-
21	-	5	21	-	18	21	-	12	21	-	11		-			-
3	-	19	3	-	13	3	-	10	3	-	4		-			-
9	-	13	9	-	10	9	-	4	9	-	19		-			-
14	-	10	14	-	4	14	-	19	14	-	13		-			-
20	-	4	20	-	19	20	-	13	20	-	10		-			-
NAST Pairings - 24 Players	 (Three groups of 8, paired for even field partial RR)
Swiss			KOH
Round 1			Round 2			Round 3			Round 4			Round 5			Round 6
1	-	19	1	-	13	1	-	12	1	-	6		-			-
7	-	13	7	-	12	7	-	6	7	-	19		-			-
18	-	12	18	-	6	18	-	19	18	-	13		-			-
24	-	6	24	-	19	24	-	13	24	-	12		-			-
2	-	20	2	-	14	2	-	11	2	-	5		-			-
8	-	14	8	-	11	8	-	5	8	-	20		-			-
17	-	11	17	-	5	17	-	20	17	-	14		-			-
23	-	5	23	-	20	23	-	14	23	-	11		-			-
3	-	21	3	-	15	3	-	10	3	-	4		-			-
9	-	15	9	-	10	9	-	4	9	-	21		-			-
16	-	10	16	-	4	16	-	21	16	-	15		-			-
22	-	4	22	-	21	22	-	15	22	-	10		-			-
NAST Pairings - 26 Players	 (Three groups of 6, one group of 8, paired for even field partial RR)
Swiss			KOH
Round 1			Round 2			Round 3			Round 4			Round 5			Round 6
1	-	19	1	-	18	1	-	9	1	-	8		-			-
26	-	18	19	-	9	18	-	8	9	-	26		-			-
8	-	9	26	-	8	19	-	26	18	-	19		-			-
2	-	20	2	-	17	2	-	10	2	-	7		-			-
25	-	17	20	-	10	17	-	7	10	-	25		-			-
7	-	10	25	-	7	20	-	25	17	-	20		-			-
3	-	21	3	-	16	3	-	11	3	-	6		-			-
24	-	16	21	-	11	16	-	6	11	-	24		-			-
6	-	11	24	-	6	21	-	24	16	-	21		-			-
4	-	22	4	-	14	4	-	13	4	-	5		-			-
12	-	14	12	-	13	12	-	5	12	-	22		-			-
15	-	13	15	-	5	15	-	22	15	-	14		-			-
23	-	5	23	-	22	23	-	14	23	-	13		-			-
NAST Pairings - 28 Players	 (Two groups of 6, two groups of 8, paired for even field partial RR)
Swiss			KOH
Round 1			Round 2			Round 3			Round 4			Round 5			Round 6
1	-	21	1	-	20	1	-	9	1	-	8		-			-
28	-	20	21	-	9	20	-	8	9	-	28		-			-
8	-	9	28	-	8	21	-	28	20	-	21		-			-
2	-	22	2	-	15	2	-	14	2	-	7		-			-
10	-	15	10	-	14	10	-	7	10	-	22		-			-
19	-	14	19	-	7	19	-	22	19	-	15		-			-
27	-	7	27	-	22	27	-	15	27	-	14		-			-
3	-	23	3	-	18	3	-	11	3	-	6		-			-
26	-	18	23	-	11	18	-	6	11	-	26		-			-
6	-	11	26	-	6	23	-	26	18	-	23		-			-
4	-	24	4	-	16	4	-	13	4	-	5		-			-
12	-	16	12	-	13	12	-	5	12	-	24		-			-
17	-	13	17	-	5	17	-	24	17	-	16		-			-
25	-	5	25	-	24	25	-	16	25	-	13		-			-
NAST Pairings - 30 Players	 (Five groups of 6, paired for even field partial RR)
Swiss			KOH
Round 1			Round 2			Round 3			Round 4			Round 5			Round 6
1	-	21	1	-	20	1	-	11	1	-	10		-			-
30	-	20	21	-	11	20	-	10	11	-	30		-			-
10	-	11	30	-	10	21	-	30	20	-	21		-			-
2	-	22	2	-	19	2	-	12	2	-	9		-			-
29	-	19	22	-	12	19	-	9	12	-	29		-			-
9	-	12	29	-	9	22	-	29	19	-	22		-			-
3	-	23	3	-	18	3	-	13	3	-	8		-			-
28	-	18	23	-	13	18	-	8	13	-	28		-			-
8	-	13	28	-	8	23	-	28	18	-	23		-			-
4	-	24	4	-	17	4	-	14	4	-	7		-			-
27	-	17	24	-	14	17	-	7	14	-	27		-			-
7	-	14	27	-	7	24	-	27	17	-	24		-			-
5	-	25	5	-	16	5	-	15	5	-	6		-			-
26	-	16	25	-	15	16	-	6	15	-	26		-			-
6	-	15	26	-	6	25	-	26	16	-	25		-			-
NAST Pairings - 32 Players	 (Four groups of 8, paired for even field partial RR)
Swiss			KOH
Round 1			Round 2			Round 3			Round 4			Round 5			Round 6
1	-	25	1	-	17	1	-	16	1	-	8		-			-
9	-	17	9	-	16	9	-	8	9	-	25		-			-
24	-	16	24	-	8	24	-	25	24	-	17		-			-
32	-	8	32	-	25	32	-	17	32	-	16		-			-
2	-	26	2	-	18	2	-	15	2	-	7		-			-
10	-	18	10	-	15	10	-	7	10	-	26		-			-
23	-	15	23	-	7	23	-	26	23	-	18		-			-
31	-	7	31	-	26	31	-	18	31	-	15		-			-
3	-	27	3	-	19	3	-	14	3	-	6		-			-
11	-	19	11	-	14	11	-	6	11	-	27		-			-
22	-	14	22	-	6	22	-	27	22	-	19		-			-
30	-	6	30	-	27	30	-	19	30	-	14		-			-
4	-	28	4	-	20	4	-	13	4	-	5		-			-
12	-	20	12	-	13	12	-	5	12	-	28		-			-
21	-	13	21	-	5	21	-	28	21	-	20		-			-
29	-	5	29	-	28	29	-	20	29	-	13		-			-
NAST Pairings - 34 Players	 (Three groups of 6, two groups of 8, paired for even field partial RR)
Swiss			KOH
Round 1			Round 2			Round 3			Round 4			Round 5			Round 6
1	-	25	1	-	24	1	-	11	1	-	10		-			-
34	-	24	25	-	11	24	-	10	11	-	34		-			-
10	-	11	34	-	10	25	-	34	24	-	25		-			-
2	-	26	2	-	18	2	-	17	2	-	9		-			-
12	-	18	12	-	17	12	-	9	12	-	26		-			-
23	-	17	23	-	9	23	-	26	23	-	18		-			-
33	-	9	33	-	26	33	-	18	33	-	17		-			-
3	-	27	3	-	22	3	-	13	3	-	8		-			-
32	-	22	27	-	13	22	-	8	13	-	32		-			-
8	-	13	32	-	8	27	-	32	22	-	27		-			-
4	-	28	4	-	19	4	-	16	4	-	7		-			-
14	-	19	14	-	16	14	-	7	14	-	28		-			-
21	-	16	21	-	7	21	-	28	21	-	19		-			-
31	-	7	31	-	28	31	-	19	31	-	16		-			-
5	-	29	5	-	20	5	-	15	5	-	6		-			-
30	-	20	29	-	15	20	-	6	15	-	30		-			-
6	-	15	30	-	6	29	-	30	20	-	29		-			-
NAST Pairings - 36 Players	 (Six groups of 6, paired for even field partial RR)
Swiss			KOH
Round 1			Round 2			Round 3			Round 4			Round 5			Round 6
1	-	25	1	-	24	1	-	13	1	-	12		-			-
36	-	24	25	-	13	24	-	12	13	-	36		-			-
12	-	13	36	-	12	25	-	36	24	-	25		-			-
2	-	26	2	-	23	2	-	14	2	-	11		-			-
35	-	23	26	-	14	23	-	11	14	-	35		-			-
11	-	14	35	-	11	26	-	35	23	-	26		-			-
3	-	27	3	-	22	3	-	15	3	-	10		-			-
34	-	22	27	-	15	22	-	10	15	-	34		-			-
10	-	15	34	-	10	27	-	34	22	-	27		-			-
4	-	28	4	-	21	4	-	16	4	-	9		-			-
33	-	21	28	-	16	21	-	9	16	-	33		-			-
9	-	16	33	-	9	28	-	33	21	-	28		-			-
5	-	29	5	-	20	5	-	17	5	-	8		-			-
32	-	20	29	-	17	20	-	8	17	-	32		-			-
8	-	17	32	-	8	29	-	32	20	-	29		-			-
6	-	30	6	-	19	6	-	18	6	-	7		-			-
31	-	19	30	-	18	19	-	7	18	-	31		-			-
7	-	18	31	-	7	30	-	31	19	-	30		-			-
NAST Pairings - 38 Players	 (Five groups of 6, one group of 8, paired for even field partial RR)
Swiss			KOH
Round 1			Round 2			Round 3			Round 4			Round 5			Round 6			
1	-	27	1	-	26	1	-	13	1	-	12		-			-		
38	-	26	27	-	13	26	-	12	13	-	38		-			-
12	-	13	38	-	12	27	-	38	26	-	27		-			-
2	-	28	2	-	25	2	-	14	2	-	11		-			-
37	-	25	28	-	14	25	-	11	14	-	37		-			-
11	-	14	37	-	11	28	-	37	25	-	28		-			-
3	-	29	3	-	20	3	-	19	3	-	10		-			-
15	-	20	15	-	19	15	-	10	15	-	29		-			-
24	-	19	24	-	10	24	-	29	24	-	20		-			-
36	-	10	36	-	29	36	-	20	36	-	19		-			-
4	-	30	4	-	23	4	-	16	4	-	9		-			-
35	-	23	30	-	16	23	-	9	16	-	35		-			-
9	-	16	35	-	9	30	-	35	23	-	30		-			-
5	-	31	5	-	22	5	-	17	5	-	8		-			-
34	-	22	31	-	17	22	-	8	17	-	34		-			-
8	-	17	34	-	8	31	-	34	22	-	31		-			-
6	-	32	6	-	21	6	-	18	6	-	7		-			-
33	-	21	32	-	18	21	-	7	18	-	33		-			-
7	-	18	33	-	7	32	-	33	21	-	32		-			-
NAST Pairings - 40 Players	 (Five groups of 8, paired for even field partial RR)
Swiss			KOH
Round 1			Round 2			Round 3			Round 4			Round 5			Round 6	
1	-	31	1	-	21	1	-	20	1	-	10		-			-
11	-	21	11	-	20	11	-	10	11	-	31		-			-
30	-	20	30	-	10	30	-	31	30	-	21		-			-
40	-	10	40	-	31	40	-	21	40	-	20		-			-
2	-	32	2	-	22	2	-	19	2	-	9		-			-
12	-	22	12	-	19	12	-	9	12	-	32		-			-
29	-	19	29	-	9	29	-	32	29	-	22		-			-
39	-	9	39	-	32	39	-	22	39	-	19		-			-
3	-	33	3	-	23	3	-	18	3	-	8		-			-
13	-	23	13	-	18	13	-	8	13	-	33		-			-
28	-	18	28	-	8	28	-	33	28	-	23		-			-
38	-	8	38	-	33	38	-	23	38	-	18		-			-
4	-	34	4	-	24	4	-	17	4	-	7		-			-
14	-	24	14	-	17	14	-	7	14	-	34		-			-
27	-	17	27	-	7	27	-	34	27	-	24		-			-
37	-	7	37	-	34	37	-	24	37	-	17		-			-
5	-	35	5	-	25	5	-	16	5	-	6		-			-
15	-	25	15	-	16	15	-	6	15	-	35		-			-
26	-	16	26	-	6	26	-	35	26	-	25		-			-
36	-	6	36	-	35	36	-	25	36	-	16		-			-
NAST Pairings - 42 Players	 (Seven groups of 6, paired for even field partial RR)
Swiss			KOH
Round 1			Round 2			Round 3			Round 4			Round 5			Round 6	
1	-	29	1	-	28	1	-	15	1	-	14		-			-		
42	-	28	29	-	15	28	-	14	15	-	42		-			-
14	-	15	42	-	14	29	-	42	28	-	29		-			-
2	-	30	2	-	27	2	-	16	2	-	13		-			-
41	-	27	30	-	16	27	-	13	16	-	41		-			-
13	-	16	41	-	13	30	-	41	27	-	30		-			-
3	-	31	3	-	26	3	-	17	3	-	12		-			-
40	-	26	31	-	17	26	-	12	17	-	40		-			-
12	-	17	40	-	12	31	-	40	26	-	31		-			-
4	-	32	4	-	25	4	-	18	4	-	11		-			-
39	-	25	32	-	18	25	-	11	18	-	39		-			-
11	-	18	39	-	11	32	-	39	25	-	32		-			-
5	-	33	5	-	24	5	-	19	5	-	10		-			-
38	-	24	33	-	19	24	-	10	19	-	38		-			-
10	-	19	38	-	10	33	-	38	24	-	33		-			-
6	-	34	6	-	23	6	-	20	6	-	9		-			-
37	-	23	34	-	20	23	-	9	20	-	37		-			-
9	-	20	37	-	9	34	-	37	23	-	34		-			-
7	-	35	7	-	22	7	-	21	7	-	8		-			-
36	-	22	35	-	21	22	-	8	21	-	36		-			-
8	-	21	36	-	8	35	-	36	22	-	35		-			-
NAST Pairings - 44 Players	 (Six groups of 6, one group of 8, paired for even field partial RR)
Swiss			KOH
Round 1			Round 2			Round 3			Round 4			Round 5			Round 6
1	-	31	1	-	30	1	-	15	1	-	14		-			-		
44	-	30	31	-	15	30	-	14	15	-	44		-			-
14	-	15	44	-	14	31	-	44	30	-	31		-			-
2	-	32	2	-	29	2	-	16	2	-	13		-			-
43	-	29	32	-	16	29	-	13	16	-	43		-			-
13	-	16	43	-	13	32	-	43	29	-	32		-			-
3	-	33	3	-	28	3	-	17	3	-	12		-			-
42	-	28	33	-	17	28	-	12	17	-	42		-			-
12	-	17	42	-	12	33	-	42	28	-	33		-			-
4	-	34	4	-	23	4	-	22	4	-	11		-			-
18	-	23	18	-	22	18	-	11	18	-	34		-			-
27	-	22	27	-	11	27	-	34	27	-	23		-			-
41	-	11	41	-	34	41	-	23	41	-	22		-			-
5	-	35	5	-	26	5	-	19	5	-	10		-			-
40	-	26	35	-	19	26	-	10	19	-	40		-			-
10	-	19	40	-	10	35	-	40	26	-	35		-			-
6	-	36	6	-	25	6	-	20	6	-	9		-			-
39	-	25	36	-	20	25	-	9	20	-	39		-			-
9	-	20	39	-	9	36	-	39	25	-	36		-			-
7	-	37	7	-	24	7	-	21	7	-	8		-			-
38	-	24	37	-	21	24	-	8	21	-	38		-			-
8	-	21	38	-	8	37	-	38	24	-	37		-			-
NAST Pairings - 46 Players	 (One group of 6, five groups of 8, paired for even field partial RR)
Swiss			KOH
Round 1			Round 2			Round 3			Round 4			Round 5			Round 6			
1	-	35	1	-	24	1	-	23	1	-	12		-			-			
13	-	24	13	-	23	13	-	12	13	-	35		-			-
34	-	23	34	-	12	34	-	35	34	-	24		-			-
46	-	12	46	-	35	46	-	24	46	-	23		-			-
2	-	36	2	-	25	2	-	22	2	-	11		-			-
14	-	25	14	-	22	14	-	11	14	-	36		-			-
33	-	22	33	-	11	33	-	36	33	-	25		-			-
45	-	11	45	-	36	45	-	25	45	-	22		-			-
3	-	37	3	-	32	3	-	15	3	-	10		-			-
44	-	32	37	-	15	32	-	10	15	-	44		-			-
10	-	15	44	-	10	37	-	44	32	-	37		-			-
4	-	38	4	-	26	4	-	21	4	-	9		-			-
16	-	26	16	-	21	16	-	9	16	-	38		-			-
31	-	21	31	-	9	31	-	38	31	-	26		-			-
43	-	9	43	-	38	43	-	26	43	-	21		-			-
5	-	39	5	-	27	5	-	20	5	-	8		-			-
17	-	27	17	-	20	17	-	8	17	-	39		-			-
30	-	20	30	-	8	30	-	39	30	-	27		-			-
42	-	8	42	-	39	42	-	27	42	-	20		-			-
6	-	40	6	-	28	6	-	19	6	-	7		-			-
18	-	28	18	-	19	18	-	7	18	-	40		-			-
29	-	19	29	-	7	29	-	40	29	-	28		-			-
41	-	7	41	-	40	41	-	28	41	-	19		-			-
NAST Pairings - 48 Players	 (Six groups of 8, paired for even field partial RR)
Swiss			KOH
Round 1			Round 2			Round 3			Round 4			Round 5			Round 6
1	-	37	1	-	25	1	-	24	1	-	12		-			-	
13	-	25	13	-	24	13	-	12	13	-	37		-			-
36	-	24	36	-	12	36	-	37	36	-	25		-			-
48	-	12	48	-	37	48	-	25	48	-	24		-			-
2	-	38	2	-	26	2	-	23	2	-	11		-			-
14	-	26	14	-	23	14	-	11	14	-	38		-			-
35	-	23	35	-	11	35	-	38	35	-	26		-			-
47	-	11	47	-	38	47	-	26	47	-	23		-			-
3	-	39	3	-	27	3	-	22	3	-	10		-			-
15	-	27	15	-	22	15	-	10	15	-	39		-			-
34	-	22	34	-	10	34	-	39	34	-	27		-			-
46	-	10	46	-	39	46	-	27	46	-	22		-			-
4	-	40	4	-	28	4	-	21	4	-	9		-			-
16	-	28	16	-	21	16	-	9	16	-	40		-			-
33	-	21	33	-	9	33	-	40	33	-	28		-			-
45	-	9	45	-	40	45	-	28	45	-	21		-			-
5	-	41	5	-	29	5	-	20	5	-	8		-			-
17	-	29	17	-	20	17	-	8	17	-	41		-			-
32	-	20	32	-	8	32	-	41	32	-	29		-			-
44	-	8	44	-	41	44	-	29	44	-	20		-			-
6	-	42	6	-	30	6	-	19	6	-	7		-			-
18	-	30	18	-	19	18	-	7	18	-	42		-			-
31	-	19	31	-	7	31	-	42	31	-	30		-			-
43	-	7	43	-	42	43	-	30	43	-	19		-			-
EOF
# from http://www.bachster.com/scrabble/NAST/NASTPairings8rounds.html
$pairings_data_8 = <<'EOF';
NAST Pairings - 6 Players  	   	   	   	   	   	   	   	   	   	   	   	   	   	   	   	   	   	   	No Threepeat*
  	  	  	  	  	  	  	  	  	  	  	  	  	  	  	  	Swiss 	  	  	Swiss 	  	  	KOH
  	Round 1 	  	  	Round 2 	  	  	Round 3 	  	  	Round 4 	  	  	Round 5 	  	  	Round 6 	  	  	Round 7 	  	  	Round 8
1 	- 	6 	1 	- 	5 	1 	- 	4 	1 	- 	3 	1 	- 	2 	  	- 	  	  	- 	  	  	-
2 	- 	5 	6 	- 	4 	5 	- 	3 	4 	- 	2 	3 	- 	6 	  	- 	  	  	- 	  	  	-
3 	- 	4 	2 	- 	3 	6 	- 	2 	5 	- 	6 	4 	- 	5 	  	- 	  	  	- 	  	  	-
* For 7 Round events, allow threepeats
NAST Pairings - 8 Players
  	  	  	  	  	  	  	  	  	  	  	  	  	  	  	  	  	  	  	  	  	  	KOH
  	Round 1 	  	  	Round 2 	  	  	Round 3 	  	  	Round 4 	  	  	Round 5 	  	  	Round 6 	  	  	Round 7 	  	  	Round 8
1 	- 	8 	1 	- 	7 	1 	- 	6 	1 	- 	5 	1 	- 	4 	1 	- 	3 	1 	- 	2 	  	-
2 	- 	7 	8 	- 	6 	7 	- 	5 	6 	- 	4 	5 	- 	3 	4 	- 	2 	3 	- 	8 	  	-
3 	- 	6 	2 	- 	5 	8 	- 	4 	7 	- 	3 	6 	- 	2 	5 	- 	8 	4 	- 	7 	  	-
4 	- 	5 	3 	- 	4 	2 	- 	3 	8 	- 	2 	7 	- 	8 	6 	- 	7 	5 	- 	6 	  	-
NAST Pairings - 10 Players 	  	  	  	  	  	  	  	  	  	  	  	  	  	  	  	  	  	  	No Threepeat*
  	  	  	  	  	  	  	  	  	  	  	  	  	  	  	  	Swiss 	  	  	Swiss 	  	  	KOH
  	Round 1 	  	  	Round 2 	  	  	Round 3 	  	  	Round 4 	  	  	Round 5 	  	  	Round 6 	  	  	Round 7 	  	  	Round 8
1 	- 	10 	1 	- 	7 	1 	- 	6 	1 	- 	3 	1 	- 	2 	  	- 	  	  	- 	  	  	-
4 	- 	7 	4 	- 	6 	4 	- 	3 	4 	- 	2 	4 	- 	10 	  	- 	  	  	- 	  	  	-
5 	- 	6 	5 	- 	3 	5 	- 	2 	5 	- 	10 	5 	- 	7 	  	- 	  	  	- 	  	  	-
8 	- 	3 	8 	- 	2 	8 	- 	10 	8 	- 	7 	8 	- 	6 	  	- 	  	  	- 	  	  	-
9 	- 	2 	9 	- 	10 	9 	- 	7 	9 	- 	6 	9 	- 	3 	  	- 	  	  	- 	  	  	-
* For 7 Round events, allow threepeats
NAST Pairings - 12 Players
  	  	  	  	  	  	  	  	  	  	  	  	  	  	  	  	  	  	  	Swiss 	  	  	KOH
  	Round 1 	  	  	Round 2 	  	  	Round 3 	  	  	Round 4 	  	  	Round 5 	  	  	Round 6 	  	  	Round 7 	  	  	Round 8
1 	- 	11 	1 	- 	10 	1 	- 	7 	1 	- 	6 	1 	- 	3 	1 	- 	2 	  	- 	  	  	-
4 	- 	10 	4 	- 	7 	4 	- 	6 	4 	- 	3 	4 	- 	2 	4 	- 	11 	  	- 	  	  	-
5 	- 	7 	5 	- 	6 	5 	- 	3 	5 	- 	2 	5 	- 	11 	5 	- 	10 	  	- 	  	  	-
8 	- 	6 	8 	- 	3 	8 	- 	2 	8 	- 	11 	8 	- 	10 	8 	- 	7 	  	- 	  	  	-
9 	- 	3 	9 	- 	2 	9 	- 	11 	9 	- 	10 	9 	- 	7 	9 	- 	6 	  	- 	  	  	-
12 	- 	2 	12 	- 	11 	12 	- 	10 	12 	- 	7 	12 	- 	6 	12 	- 	3 	  	- 	  	  	-
NAST Pairings - 14 Players 	  	  	  	  	  	  	  	  	  	  	  	  	  	  	  	No Repeats
  	  	  	  	  	  	  	  	  	  	  	  	  	  	  	  	Swiss 	  	  	Swiss 	  	  	KOH
  	Round 1 	  	  	Round 2 	  	  	Round 3 	  	  	Round 4 	  	  	Round 5 	  	  	Round 6 	  	  	Round 7 	  	  	Round 8
1 	- 	11 	1 	- 	9 	1 	- 	6 	1 	- 	4 	1 	- 	2 	  	- 	  	  	- 	  	  	-
14 	- 	9 	11 	- 	6 	9 	- 	4 	6 	- 	14 	3 	- 	4 	  	- 	  	  	- 	  	  	-
4 	- 	6 	14 	- 	4 	11 	- 	14 	9 	- 	11 	5 	- 	6 	  	- 	  	  	- 	  	  	-
2 	- 	12 	2 	- 	10 	2 	- 	5 	2 	- 	3 	7 	- 	8 	  	- 	  	  	- 	  	  	-
7 	- 	10 	7 	- 	5 	7 	- 	3 	7 	- 	12 	9 	- 	10 	  	- 	  	  	- 	  	  	-
8 	- 	5 	8 	- 	3 	8 	- 	12 	8 	- 	10 	11 	- 	12 	  	- 	  	  	- 	  	  	-
13 	- 	3 	13 	- 	12 	13 	- 	10 	13 	- 	5 	13 	- 	14 	  	- 	  	  	- 	  	  	-
NAST Pairings - 16 Players 	  	  	  	  	  	  	  	  	  	  	  	  	  	  	  	No Repeats
  	  	  	  	  	  	  	  	  	  	  	  	  	  	  	  	Swiss 	  	  	Swiss 	  	  	KOH
  	Round 1 	  	  	Round 2 	  	  	Round 3 	  	  	Round 4 	  	  	Round 5 	  	  	Round 6 	  	  	Round 7 	  	  	Round 8
1 	- 	13 	1 	- 	9 	1 	- 	8 	1 	- 	4 	1 	- 	3 	  	- 	  	  	- 	  	  	-
5 	- 	9 	5 	- 	8 	5 	- 	4 	5 	- 	13 	2 	- 	4 	  	- 	  	  	- 	  	  	-
12 	- 	8 	12 	- 	4 	12 	- 	13 	12 	- 	9 	5 	- 	7 	  	- 	  	  	- 	  	  	-
16 	- 	4 	16 	- 	13 	16 	- 	9 	16 	- 	8 	6 	- 	8 	  	- 	  	  	- 	  	  	-
2 	- 	14 	2 	- 	10 	2 	- 	7 	2 	- 	3 	9 	- 	11 	  	- 	  	  	- 	  	  	-
6 	- 	10 	6 	- 	7 	6 	- 	3 	6 	- 	14 	10 	- 	12 	  	- 	  	  	- 	  	  	-
11 	- 	7 	11 	- 	3 	11 	- 	14 	11 	- 	10 	13 	- 	15 	  	- 	  	  	- 	  	  	-
15 	- 	3 	15 	- 	14 	15 	- 	10 	15 	- 	7 	14 	- 	16 	  	- 	  	  	- 	  	  	-
NAST Pairings - 18 Players 	  	  	  	  	  	  	  	  	  	  	  	  	  	  	  	No Repeats
  	  	  	  	  	  	  	  	  	  	  	  	  	  	  	  	Swiss 	  	  	Swiss 	  	  	KOH
  	Round 1 	  	  	Round 2 	  	  	Round 3 	  	  	Round 4 	  	  	Round 5 	  	  	Round 6 	  	  	Round 7 	  	  	Round 8
1 	- 	13 	1 	- 	12 	1 	- 	7 	1 	- 	6 	1 	- 	3 	  	- 	  	  	- 	  	  	-
18 	- 	12 	13 	- 	7 	12 	- 	6 	7 	- 	18 	2 	- 	4 	  	- 	  	  	- 	  	  	-
6 	- 	7 	18 	- 	6 	13 	- 	18 	12 	- 	13 	5 	- 	7 	  	- 	  	  	- 	  	  	-
2 	- 	14 	2 	- 	11 	2 	- 	8 	2 	- 	5 	6 	- 	8 	  	- 	  	  	- 	  	  	-
17 	- 	11 	14 	- 	8 	11 	- 	5 	8 	- 	17 	9 	- 	10 	  	- 	  	  	- 	  	  	-
5 	- 	8 	17 	- 	5 	14 	- 	17 	11 	- 	14 	11 	- 	13 	  	- 	  	  	- 	  	  	-
3 	- 	15 	3 	- 	10 	3 	- 	9 	3 	- 	4 	12 	- 	14 	  	- 	  	  	- 	  	  	-
16 	- 	10 	15 	- 	9 	10 	- 	4 	9 	- 	16 	15 	- 	17 	  	- 	  	  	- 	  	  	-
4 	- 	9 	16 	- 	4 	15 	- 	16 	10 	- 	15 	16 	- 	18 	  	- 	  	  	- 	  	  	-
NAST Pairings - 20 Players 	  	  	  	  	  	  	  	  	  	  	  	  	  	  	  	No Repeats
  	  	  	  	  	  	  	  	  	  	  	  	  	  	  	  	Swiss 	  	  	Swiss 	  	  	KOH
  	Round 1 	  	  	Round 2 	  	  	Round 3 	  	  	Round 4 	  	  	Round 5 	  	  	Round 6 	  	  	Round 7 	  	  	Round 8
1 	- 	15 	1 	- 	14 	1 	- 	7 	1 	- 	6 	1 	- 	3 	  	- 	  	  	- 	  	  	-
20 	- 	14 	15 	- 	7 	14 	- 	6 	7 	- 	20 	2 	- 	4 	  	- 	  	  	- 	  	  	-
6 	- 	7 	20 	- 	6 	15 	- 	20 	14 	- 	15 	5 	- 	7 	  	- 	  	  	- 	  	  	-
2 	- 	16 	2 	- 	13 	2 	- 	8 	2 	- 	5 	6 	- 	8 	  	- 	  	  	- 	  	  	-
19 	- 	13 	16 	- 	8 	13 	- 	5 	8 	- 	19 	9 	- 	12 	  	- 	  	  	- 	  	  	-
5 	- 	8 	19 	- 	5 	16 	- 	19 	13 	- 	16 	10 	- 	11 	  	- 	  	  	- 	  	  	-
3 	- 	17 	3 	- 	11 	3 	- 	10 	3 	- 	4 	13 	- 	15 	  	- 	  	  	- 	  	  	-
9 	- 	11 	9 	- 	10 	9 	- 	4 	9 	- 	17 	14 	- 	16 	  	- 	  	  	- 	  	  	-
12 	- 	10 	12 	- 	4 	12 	- 	17 	12 	- 	11 	17 	- 	19 	  	- 	  	  	- 	  	  	-
18 	- 	4 	18 	- 	17 	18 	- 	11 	18 	- 	10 	18 	- 	20 	  	- 	  	  	- 	  	  	-
NAST Pairings - 22 Players 	  	  	  	  	  	  	  	  	  	  	  	  	  	  	  	No Repeats
  	  	  	  	  	  	  	  	  	  	  	  	  	  	  	  	Swiss 	  	  	Swiss 	  	  	KOH
  	Round 1 	  	  	Round 2 	  	  	Round 3 	  	  	Round 4 	  	  	Round 5 	  	  	Round 6 	  	  	Round 7 	  	  	Round 8
1 	- 	17 	1 	- 	16 	1 	- 	7 	1 	- 	6 	1 	- 	3 	  	- 	  	  	- 	  	  	-
22 	- 	16 	17 	- 	7 	16 	- 	6 	7 	- 	22 	2 	- 	4 	  	- 	  	  	- 	  	  	-
6 	- 	7 	22 	- 	6 	17 	- 	22 	16 	- 	17 	5 	- 	7 	  	- 	  	  	- 	  	  	-
2 	- 	18 	2 	- 	12 	2 	- 	11 	2 	- 	5 	6 	- 	8 	  	- 	  	  	- 	  	  	-
8 	- 	12 	8 	- 	11 	8 	- 	5 	8 	- 	18 	9 	- 	12 	  	- 	  	  	- 	  	  	-
15 	- 	11 	15 	- 	5 	15 	- 	18 	15 	- 	12 	10 	- 	13 	  	- 	  	  	- 	  	  	-
21 	- 	5 	21 	- 	18 	21 	- 	12 	21 	- 	11 	11 	- 	14 	  	- 	  	  	- 	  	  	-
3 	- 	19 	3 	- 	13 	3 	- 	10 	3 	- 	4 	15 	- 	17 	  	- 	  	  	- 	  	  	-
9 	- 	13 	9 	- 	10 	9 	- 	4 	9 	- 	19 	16 	- 	18 	  	- 	  	  	- 	  	  	-
14 	- 	10 	14 	- 	4 	14 	- 	19 	14 	- 	13 	19 	- 	21 	  	- 	  	  	- 	  	  	-
20 	- 	4 	20 	- 	19 	20 	- 	13 	20 	- 	10 	20 	- 	22 	  	- 	  	  	- 	  	  	-
NAST Pairings - 24 Players 	  	  	  	  	  	  	  	  	  	  	  	  	  	  	  	No Repeats
  	  	  	  	  	  	  	  	  	  	  	  	  	  	  	  	Swiss 	  	  	Swiss 	  	  	KOH
  	Round 1 	  	  	Round 2 	  	  	Round 3 	  	  	Round 4 	  	  	Round 5 	  	  	Round 6 	  	  	Round 7 	  	  	Round 8
1 	- 	19 	1 	- 	13 	1 	- 	12 	1 	- 	6 	1 	- 	3 	  	- 	  	  	- 	  	  	-
7 	- 	13 	7 	- 	12 	7 	- 	6 	7 	- 	19 	2 	- 	4 	  	- 	  	  	- 	  	  	-
18 	- 	12 	18 	- 	6 	18 	- 	19 	18 	- 	13 	5 	- 	7 	  	- 	  	  	- 	  	  	-
24 	- 	6 	24 	- 	19 	24 	- 	13 	24 	- 	12 	6 	- 	8 	  	- 	  	  	- 	  	  	-
2 	- 	20 	2 	- 	14 	2 	- 	11 	2 	- 	5 	9 	- 	11 	  	- 	  	  	- 	  	  	-
8 	- 	14 	8 	- 	11 	8 	- 	5 	8 	- 	20 	10 	- 	12 	  	- 	  	  	- 	  	  	-
17 	- 	11 	17 	- 	5 	17 	- 	20 	17 	- 	14 	13 	- 	15 	  	- 	  	  	- 	  	  	-
23 	- 	5 	23 	- 	20 	23 	- 	14 	23 	- 	11 	14 	- 	16 	  	- 	  	  	- 	  	  	-
3 	- 	21 	3 	- 	15 	3 	- 	10 	3 	- 	4 	17 	- 	19 	  	- 	  	  	- 	  	  	-
9 	- 	15 	9 	- 	10 	9 	- 	4 	9 	- 	21 	18 	- 	20 	  	- 	  	  	- 	  	  	-
16 	- 	10 	16 	- 	4 	16 	- 	21 	16 	- 	15 	21 	- 	23 	  	- 	  	  	- 	  	  	-
22 	- 	4 	22 	- 	21 	22 	- 	15 	22 	- 	10 	22 	- 	24 	  	- 	  	  	- 	  	  	-
NAST Pairings - 26 Players 	  	  	  	  	  	  	  	  	  	  	  	  	  	  	  	No Repeats
  	  	  	  	  	  	  	  	  	  	  	  	  	  	  	  	Swiss 	  	  	Swiss 	  	  	KOH
  	Round 1 	  	  	Round 2 	  	  	Round 3 	  	  	Round 4 	  	  	Round 5 	  	  	Round 6 	  	  	Round 7 	  	  	Round 8
1 	- 	19 	1 	- 	18 	1 	- 	9 	1 	- 	8 	1 	- 	3 	  	- 	  	  	- 	  	  	-
26 	- 	18 	19 	- 	9 	18 	- 	8 	9 	- 	26 	2 	- 	4 	  	- 	  	  	- 	  	  	-
8 	- 	9 	26 	- 	8 	19 	- 	26 	18 	- 	19 	5 	- 	7 	  	- 	  	  	- 	  	  	-
2 	- 	20 	2 	- 	17 	2 	- 	10 	2 	- 	7 	6 	- 	8 	  	- 	  	  	- 	  	  	-
25 	- 	17 	20 	- 	10 	17 	- 	7 	10 	- 	25 	9 	- 	11 	  	- 	  	  	- 	  	  	-
7 	- 	10 	25 	- 	7 	20 	- 	25 	17 	- 	20 	10 	- 	12 	  	- 	  	  	- 	  	  	-
3 	- 	21 	3 	- 	16 	3 	- 	11 	3 	- 	6 	13 	- 	14 	  	- 	  	  	- 	  	  	-
24 	- 	16 	21 	- 	11 	16 	- 	6 	11 	- 	24 	15 	- 	17 	  	- 	  	  	- 	  	  	-
6 	- 	11 	24 	- 	6 	21 	- 	24 	16 	- 	21 	16 	- 	18 	  	- 	  	  	- 	  	  	-
4 	- 	22 	4 	- 	14 	4 	- 	13 	4 	- 	5 	19 	- 	21 	  	- 	  	  	- 	  	  	-
12 	- 	14 	12 	- 	13 	12 	- 	5 	12 	- 	22 	20 	- 	22 	  	- 	  	  	- 	  	  	-
15 	- 	13 	15 	- 	5 	15 	- 	22 	15 	- 	14 	23 	- 	25 	  	- 	  	  	- 	  	  	-
23 	- 	5 	23 	- 	22 	23 	- 	14 	23 	- 	13 	24 	- 	26 	  	- 	  	  	- 	  	  	-
NAST Pairings - 28 Players 	  	  	  	  	  	  	  	  	  	  	  	  	  	  	  	No Repeats
  	  	  	  	  	  	  	  	  	  	  	  	  	  	  	  	Swiss 	  	  	Swiss 	  	  	KOH
  	Round 1 	  	  	Round 2 	  	  	Round 3 	  	  	Round 4 	  	  	Round 5 	  	  	Round 6 	  	  	Round 7 	  	  	Round 8
1 	- 	21 	1 	- 	20 	1 	- 	9 	1 	- 	8 	1 	- 	3 	  	- 	  	  	- 	  	  	-
28 	- 	20 	21 	- 	9 	20 	- 	8 	9 	- 	28 	2 	- 	4 	  	- 	  	  	- 	  	  	-
8 	- 	9 	28 	- 	8 	21 	- 	28 	20 	- 	21 	5 	- 	7 	  	- 	  	  	- 	  	  	-
2 	- 	22 	2 	- 	15 	2 	- 	14 	2 	- 	7 	6 	- 	8 	  	- 	  	  	- 	  	  	-
10 	- 	15 	10 	- 	14 	10 	- 	7 	10 	- 	22 	9 	- 	11 	  	- 	  	  	- 	  	  	-
19 	- 	14 	19 	- 	7 	19 	- 	22 	19 	- 	15 	10 	- 	12 	  	- 	  	  	- 	  	  	-
27 	- 	7 	27 	- 	22 	27 	- 	15 	27 	- 	14 	13 	- 	15 	  	- 	  	  	- 	  	  	-
3 	- 	23 	3 	- 	18 	3 	- 	11 	3 	- 	6 	14 	- 	16 	  	- 	  	  	- 	  	  	-
26 	- 	18 	23 	- 	11 	18 	- 	6 	11 	- 	26 	17 	- 	19 	  	- 	  	  	- 	  	  	-
6 	- 	11 	26 	- 	6 	23 	- 	26 	18 	- 	23 	18 	- 	20 	  	- 	  	  	- 	  	  	-
4 	- 	24 	4 	- 	16 	4 	- 	13 	4 	- 	5 	21 	- 	23 	  	- 	  	  	- 	  	  	-
12 	- 	16 	12 	- 	13 	12 	- 	5 	12 	- 	24 	22 	- 	24 	  	- 	  	  	- 	  	  	-
17 	- 	13 	17 	- 	5 	17 	- 	24 	17 	- 	16 	25 	- 	27 	  	- 	  	  	- 	  	  	-
25 	- 	5 	25 	- 	24 	25 	- 	16 	25 	- 	13 	26 	- 	28 	  	- 	  	  	- 	  	  	-
NAST Pairings - 30 Players 	  	  	  	  	  	  	  	  	  	  	  	  	  	  	  	No Repeats
  	  	  	  	  	  	  	  	  	  	  	  	  	  	  	  	Swiss 	  	  	Swiss 	  	  	KOH
  	Round 1 	  	  	Round 2 	  	  	Round 3 	  	  	Round 4 	  	  	Round 5 	  	  	Round 6 	  	  	Round 7 	  	  	Round 8
1 	- 	21 	1 	- 	20 	1 	- 	11 	1 	- 	10 	1 	- 	3 	  	- 	  	  	- 	  	  	-
30 	- 	20 	21 	- 	11 	20 	- 	10 	11 	- 	30 	2 	- 	4 	  	- 	  	  	- 	  	  	-
10 	- 	11 	30 	- 	10 	21 	- 	30 	20 	- 	21 	5 	- 	7 	  	- 	  	  	- 	  	  	-
2 	- 	22 	2 	- 	19 	2 	- 	12 	2 	- 	9 	6 	- 	8 	  	- 	  	  	- 	  	  	-
29 	- 	19 	22 	- 	12 	19 	- 	9 	12 	- 	29 	9 	- 	11 	  	- 	  	  	- 	  	  	-
9 	- 	12 	29 	- 	9 	22 	- 	29 	19 	- 	22 	10 	- 	12 	  	- 	  	  	- 	  	  	-
3 	- 	23 	3 	- 	18 	3 	- 	13 	3 	- 	8 	13 	- 	16 	  	- 	  	  	- 	  	  	-
28 	- 	18 	23 	- 	13 	18 	- 	8 	13 	- 	28 	14 	- 	17 	  	- 	  	  	- 	  	  	-
8 	- 	13 	28 	- 	8 	23 	- 	28 	18 	- 	23 	15 	- 	18 	  	- 	  	  	- 	  	  	-
4 	- 	24 	4 	- 	17 	4 	- 	14 	4 	- 	7 	19 	- 	21 	  	- 	  	  	- 	  	  	-
27 	- 	17 	24 	- 	14 	17 	- 	7 	14 	- 	27 	20 	- 	22 	  	- 	  	  	- 	  	  	-
7 	- 	14 	27 	- 	7 	24 	- 	27 	17 	- 	24 	23 	- 	25 	  	- 	  	  	- 	  	  	-
5 	- 	25 	5 	- 	16 	5 	- 	15 	5 	- 	6 	24 	- 	26 	  	- 	  	  	- 	  	  	-
26 	- 	16 	25 	- 	15 	16 	- 	6 	15 	- 	26 	27 	- 	29 	  	- 	  	  	- 	  	  	-
6 	- 	15 	26 	- 	6 	25 	- 	26 	16 	- 	25 	28 	- 	30 	  	- 	  	  	- 	  	  	-
NAST Pairings - 32 Players 	  	  	  	  	  	  	  	  	  	  	  	  	  	  	  	No Repeats
  	  	  	  	  	  	  	  	  	  	  	  	  	  	  	  	Swiss 	  	  	Swiss 	  	  	KOH
  	Round 1 	  	  	Round 2 	  	  	Round 3 	  	  	Round 4 	  	  	Round 5 	  	  	Round 6 	  	  	Round 7 	  	  	Round 8
1 	- 	25 	1 	- 	17 	1 	- 	16 	1 	- 	8 	1 	- 	3 	  	- 	  	  	- 	  	  	-
9 	- 	17 	9 	- 	16 	9 	- 	8 	9 	- 	25 	2 	- 	4 	  	- 	  	  	- 	  	  	-
24 	- 	16 	24 	- 	8 	24 	- 	25 	24 	- 	17 	5 	- 	7 	  	- 	  	  	- 	  	  	-
32 	- 	8 	32 	- 	25 	32 	- 	17 	32 	- 	16 	6 	- 	8 	  	- 	  	  	- 	  	  	-
2 	- 	26 	2 	- 	18 	2 	- 	15 	2 	- 	7 	9 	- 	11 	  	- 	  	  	- 	  	  	-
10 	- 	18 	10 	- 	15 	10 	- 	7 	10 	- 	26 	10 	- 	12 	  	- 	  	  	- 	  	  	-
23 	- 	15 	23 	- 	7 	23 	- 	26 	23 	- 	18 	13 	- 	15 	  	- 	  	  	- 	  	  	-
31 	- 	7 	31 	- 	26 	31 	- 	18 	31 	- 	15 	14 	- 	16 	  	- 	  	  	- 	  	  	-
3 	- 	27 	3 	- 	19 	3 	- 	14 	3 	- 	6 	17 	- 	19 	  	- 	  	  	- 	  	  	-
11 	- 	19 	11 	- 	14 	11 	- 	6 	11 	- 	27 	18 	- 	20 	  	- 	  	  	- 	  	  	-
22 	- 	14 	22 	- 	6 	22 	- 	27 	22 	- 	19 	21 	- 	23 	  	- 	  	  	- 	  	  	-
30 	- 	6 	30 	- 	27 	30 	- 	19 	30 	- 	14 	22 	- 	24 	  	- 	  	  	- 	  	  	-
4 	- 	28 	4 	- 	20 	4 	- 	13 	4 	- 	5 	25 	- 	27 	  	- 	  	  	- 	  	  	-
12 	- 	20 	12 	- 	13 	12 	- 	5 	12 	- 	28 	26 	- 	28 	  	- 	  	  	- 	  	  	-
21 	- 	13 	21 	- 	5 	21 	- 	28 	21 	- 	20 	29 	- 	31 	  	- 	  	  	- 	  	  	-
29 	- 	5 	29 	- 	28 	29 	- 	20 	29 	- 	13 	30 	- 	32 	  	- 	  	  	- 	  	  	-
NAST Pairings - 34 Players 	  	  	  	  	  	  	  	  	  	  	  	  	  	  	  	No Repeats
  	  	  	  	  	  	  	  	  	  	  	  	  	  	  	  	Swiss 	  	  	Swiss 	  	  	KOH
  	Round 1 	  	  	Round 2 	  	  	Round 3 	  	  	Round 4 	  	  	Round 5 	  	  	Round 6 	  	  	Round 7 	  	  	Round 8
1 	- 	25 	1 	- 	24 	1 	- 	11 	1 	- 	10 	1 	- 	3 	  	- 	  	  	- 	  	  	-
34 	- 	24 	25 	- 	11 	24 	- 	10 	11 	- 	34 	2 	- 	4 	  	- 	  	  	- 	  	  	-
10 	- 	11 	34 	- 	10 	25 	- 	34 	24 	- 	25 	5 	- 	7 	  	- 	  	  	- 	  	  	-
2 	- 	26 	2 	- 	18 	2 	- 	17 	2 	- 	9 	6 	- 	8 	  	- 	  	  	- 	  	  	-
12 	- 	18 	12 	- 	17 	12 	- 	9 	12 	- 	26 	9 	- 	11 	  	- 	  	  	- 	  	  	-
23 	- 	17 	23 	- 	9 	23 	- 	26 	23 	- 	18 	10 	- 	12 	  	- 	  	  	- 	  	  	-
33 	- 	9 	33 	- 	26 	33 	- 	18 	33 	- 	17 	13 	- 	14 	  	- 	  	  	- 	  	  	-
3 	- 	27 	3 	- 	22 	3 	- 	13 	3 	- 	8 	15 	- 	16 	  	- 	  	  	- 	  	  	-
32 	- 	22 	27 	- 	13 	22 	- 	8 	13 	- 	32 	17 	- 	18 	  	- 	  	  	- 	  	  	-
8 	- 	13 	32 	- 	8 	27 	- 	32 	22 	- 	27 	19 	- 	20 	  	- 	  	  	- 	  	  	-
4 	- 	28 	4 	- 	19 	4 	- 	16 	4 	- 	7 	21 	- 	22 	  	- 	  	  	- 	  	  	-
14 	- 	19 	14 	- 	16 	14 	- 	7 	14 	- 	28 	23 	- 	25 	  	- 	  	  	- 	  	  	-
21 	- 	16 	21 	- 	7 	21 	- 	28 	21 	- 	19 	24 	- 	26 	  	- 	  	  	- 	  	  	-
31 	- 	7 	31 	- 	28 	31 	- 	19 	31 	- 	16 	27 	- 	29 	  	- 	  	  	- 	  	  	-
5 	- 	29 	5 	- 	20 	5 	- 	15 	5 	- 	6 	28 	- 	30 	  	- 	  	  	- 	  	  	-
30 	- 	20 	29 	- 	15 	20 	- 	6 	15 	- 	30 	31 	- 	33 	  	- 	  	  	- 	  	  	-
6 	- 	15 	30 	- 	6 	29 	- 	30 	20 	- 	29 	32 	- 	34 	  	- 	  	  	- 	  	  	-
NAST Pairings - 36 Players 	  	  	  	  	  	  	  	  	  	  	  	  	  	  	  	No Repeats
  	  	  	  	  	  	  	  	  	  	  	  	  	  	  	  	Swiss 	  	  	Swiss 	  	  	KOH
  	Round 1 	  	  	Round 2 	  	  	Round 3 	  	  	Round 4 	  	  	Round 5 	  	  	Round 6 	  	  	Round 7 	  	  	Round 8
1 	- 	25 	1 	- 	24 	1 	- 	13 	1 	- 	12 	1 	- 	3 	  	- 	  	  	- 	  	  	-
36 	- 	24 	25 	- 	13 	24 	- 	12 	13 	- 	36 	2 	- 	4 	  	- 	  	  	- 	  	  	-
12 	- 	13 	36 	- 	12 	25 	- 	36 	24 	- 	25 	5 	- 	7 	  	- 	  	  	- 	  	  	-
2 	- 	26 	2 	- 	23 	2 	- 	14 	2 	- 	11 	6 	- 	8 	  	- 	  	  	- 	  	  	-
35 	- 	23 	26 	- 	14 	23 	- 	11 	14 	- 	35 	9 	- 	11 	  	- 	  	  	- 	  	  	-
11 	- 	14 	35 	- 	11 	26 	- 	35 	23 	- 	26 	10 	- 	12 	  	- 	  	  	- 	  	  	-
3 	- 	27 	3 	- 	22 	3 	- 	15 	3 	- 	10 	13 	- 	15 	  	- 	  	  	- 	  	  	-
34 	- 	22 	27 	- 	15 	22 	- 	10 	15 	- 	34 	14 	- 	16 	  	- 	  	  	- 	  	  	-
10 	- 	15 	34 	- 	10 	27 	- 	34 	22 	- 	27 	17 	- 	19 	  	- 	  	  	- 	  	  	-
4 	- 	28 	4 	- 	21 	4 	- 	16 	4 	- 	9 	18 	- 	20 	  	- 	  	  	- 	  	  	-
33 	- 	21 	28 	- 	16 	21 	- 	9 	16 	- 	33 	21 	- 	23 	  	- 	  	  	- 	  	  	-
9 	- 	16 	33 	- 	9 	28 	- 	33 	21 	- 	28 	22 	- 	24 	  	- 	  	  	- 	  	  	-
5 	- 	29 	5 	- 	20 	5 	- 	17 	5 	- 	8 	25 	- 	27 	  	- 	  	  	- 	  	  	-
32 	- 	20 	29 	- 	17 	20 	- 	8 	17 	- 	32 	26 	- 	28 	  	- 	  	  	- 	  	  	-
8 	- 	17 	32 	- 	8 	29 	- 	32 	20 	- 	29 	29 	- 	31 	  	- 	  	  	- 	  	  	-
6 	- 	30 	6 	- 	19 	6 	- 	18 	6 	- 	7 	30 	- 	32 	  	- 	  	  	- 	  	  	-
31 	- 	19 	30 	- 	18 	19 	- 	7 	18 	- 	31 	33 	- 	35 	  	- 	  	  	- 	  	  	-
7 	- 	18 	31 	- 	7 	30 	- 	31 	19 	- 	30 	34 	- 	36 	  	- 	  	  	- 	  	  	-
NAST Pairings - 38 Players 	  	  	  	  	  	  	  	  	  	  	  	  	  	  	  	No Repeats
  	  	  	  	  	  	  	  	  	  	  	  	  	  	  	  	Swiss 	  	  	Swiss 	  	  	KOH
  	Round 1 	  	  	Round 2 	  	  	Round 3 	  	  	Round 4 	  	  	Round 5 	  	  	Round 6 	  	  	Round 7 	  	  	Round 8
1 	- 	27 	1 	- 	26 	1 	- 	13 	1 	- 	12 	1 	- 	3 	  	- 	  	  	- 	  	  	-
38 	- 	26 	27 	- 	13 	26 	- 	12 	13 	- 	38 	2 	- 	4 	  	- 	  	  	- 	  	  	-
12 	- 	13 	38 	- 	12 	27 	- 	38 	26 	- 	27 	5 	- 	7 	  	- 	  	  	- 	  	  	-
2 	- 	28 	2 	- 	25 	2 	- 	14 	2 	- 	11 	6 	- 	8 	  	- 	  	  	- 	  	  	-
37 	- 	25 	28 	- 	14 	25 	- 	11 	14 	- 	37 	9 	- 	11 	  	- 	  	  	- 	  	  	-
11 	- 	14 	37 	- 	11 	28 	- 	37 	25 	- 	28 	10 	- 	12 	  	- 	  	  	- 	  	  	-
3 	- 	29 	3 	- 	20 	3 	- 	19 	3 	- 	10 	13 	- 	15 	  	- 	  	  	- 	  	  	-
15 	- 	20 	15 	- 	19 	15 	- 	10 	15 	- 	29 	14 	- 	16 	  	- 	  	  	- 	  	  	-
24 	- 	19 	24 	- 	10 	24 	- 	29 	24 	- 	20 	17 	- 	20 	  	- 	  	  	- 	  	  	-
36 	- 	10 	36 	- 	29 	36 	- 	20 	36 	- 	19 	18 	- 	21 	  	- 	  	  	- 	  	  	-
4 	- 	30 	4 	- 	23 	4 	- 	16 	4 	- 	9 	19 	- 	22 	  	- 	  	  	- 	  	  	-
35 	- 	23 	30 	- 	16 	23 	- 	9 	16 	- 	35 	23 	- 	25 	  	- 	  	  	- 	  	  	-
9 	- 	16 	35 	- 	9 	30 	- 	35 	23 	- 	30 	24 	- 	26 	  	- 	  	  	- 	  	  	-
5 	- 	31 	5 	- 	22 	5 	- 	17 	5 	- 	8 	27 	- 	29 	  	- 	  	  	- 	  	  	-
34 	- 	22 	31 	- 	17 	22 	- 	8 	17 	- 	34 	28 	- 	30 	  	- 	  	  	- 	  	  	-
8 	- 	17 	34 	- 	8 	31 	- 	34 	22 	- 	31 	31 	- 	33 	  	- 	  	  	- 	  	  	-
6 	- 	32 	6 	- 	21 	6 	- 	18 	6 	- 	7 	32 	- 	34 	  	- 	  	  	- 	  	  	-
33 	- 	21 	32 	- 	18 	21 	- 	7 	18 	- 	33 	35 	- 	37 	  	- 	  	  	- 	  	  	-
7 	- 	18 	33 	- 	7 	32 	- 	33 	21 	- 	32 	36 	- 	38 	  	- 	  	  	- 	  	  	-
NAST Pairings - 40 Players 	  	  	  	  	  	  	  	  	  	  	  	  	  	  	  	No Repeats
  	  	  	  	  	  	  	  	  	  	  	  	  	  	  	  	Swiss 	  	  	Swiss 	  	  	KOH
  	Round 1 	  	  	Round 2 	  	  	Round 3 	  	  	Round 4 	  	  	Round 5 	  	  	Round 6 	  	  	Round 7 	  	  	Round 8
1 	- 	31 	1 	- 	21 	1 	- 	20 	1 	- 	10 	1 	- 	3 	  	- 	  	  	- 	  	  	-
11 	- 	21 	11 	- 	20 	11 	- 	10 	11 	- 	31 	2 	- 	4 	  	- 	  	  	- 	  	  	-
30 	- 	20 	30 	- 	10 	30 	- 	31 	30 	- 	21 	5 	- 	7 	  	- 	  	  	- 	  	  	-
40 	- 	10 	40 	- 	31 	40 	- 	21 	40 	- 	20 	6 	- 	8 	  	- 	  	  	- 	  	  	-
2 	- 	32 	2 	- 	22 	2 	- 	19 	2 	- 	9 	9 	- 	11 	  	- 	  	  	- 	  	  	-
12 	- 	22 	12 	- 	19 	12 	- 	9 	12 	- 	32 	10 	- 	12 	  	- 	  	  	- 	  	  	-
29 	- 	19 	29 	- 	9 	29 	- 	32 	29 	- 	22 	13 	- 	15 	  	- 	  	  	- 	  	  	-
39 	- 	9 	39 	- 	32 	39 	- 	22 	39 	- 	19 	14 	- 	16 	  	- 	  	  	- 	  	  	-
3 	- 	33 	3 	- 	23 	3 	- 	18 	3 	- 	8 	17 	- 	19 	  	- 	  	  	- 	  	  	-
13 	- 	23 	13 	- 	18 	13 	- 	8 	13 	- 	33 	18 	- 	20 	  	- 	  	  	- 	  	  	-
28 	- 	18 	28 	- 	8 	28 	- 	33 	28 	- 	23 	21 	- 	23 	  	- 	  	  	- 	  	  	-
38 	- 	8 	38 	- 	33 	38 	- 	23 	38 	- 	18 	22 	- 	24 	  	- 	  	  	- 	  	  	-
4 	- 	34 	4 	- 	24 	4 	- 	17 	4 	- 	7 	25 	- 	27 	  	- 	  	  	- 	  	  	-
14 	- 	24 	14 	- 	17 	14 	- 	7 	14 	- 	34 	26 	- 	28 	  	- 	  	  	- 	  	  	-
27 	- 	17 	27 	- 	7 	27 	- 	34 	27 	- 	24 	29 	- 	31 	  	- 	  	  	- 	  	  	-
37 	- 	7 	37 	- 	34 	37 	- 	24 	37 	- 	17 	30 	- 	32 	  	- 	  	  	- 	  	  	-
5 	- 	35 	5 	- 	25 	5 	- 	16 	5 	- 	6 	33 	- 	35 	  	- 	  	  	- 	  	  	-
15 	- 	25 	15 	- 	16 	15 	- 	6 	15 	- 	35 	34 	- 	36 	  	- 	  	  	- 	  	  	-
26 	- 	16 	26 	- 	6 	26 	- 	35 	26 	- 	25 	37 	- 	39 	  	- 	  	  	- 	  	  	-
36 	- 	6 	36 	- 	35 	36 	- 	25 	36 	- 	16 	38 	- 	40 	  	- 	  	  	- 	  	  	-
NAST Pairings - 42 Players 	  	  	  	  	  	  	  	  	  	  	  	  	  	  	  	No Repeats
  	  	  	  	  	  	  	  	  	  	  	  	  	  	  	  	Swiss 	  	  	Swiss 	  	  	KOH
  	Round 1 	  	  	Round 2 	  	  	Round 3 	  	  	Round 4 	  	  	Round 5 	  	  	Round 6 	  	  	Round 7 	  	  	Round 8
1 	- 	29 	1 	- 	28 	1 	- 	15 	1 	- 	14 	1 	- 	3 	  	- 	  	  	- 	  	  	-
42 	- 	28 	29 	- 	15 	28 	- 	14 	15 	- 	42 	2 	- 	4 	  	- 	  	  	- 	  	  	-
14 	- 	15 	42 	- 	14 	29 	- 	42 	28 	- 	29 	5 	- 	7 	  	- 	  	  	- 	  	  	-
2 	- 	30 	2 	- 	27 	2 	- 	16 	2 	- 	13 	6 	- 	8 	  	- 	  	  	- 	  	  	-
41 	- 	27 	30 	- 	16 	27 	- 	13 	16 	- 	41 	9 	- 	11 	  	- 	  	  	- 	  	  	-
13 	- 	16 	41 	- 	13 	30 	- 	41 	27 	- 	30 	10 	- 	12 	  	- 	  	  	- 	  	  	-
3 	- 	31 	3 	- 	26 	3 	- 	17 	3 	- 	12 	13 	- 	15 	  	- 	  	  	- 	  	  	-
40 	- 	26 	31 	- 	17 	26 	- 	12 	17 	- 	40 	14 	- 	16 	  	- 	  	  	- 	  	  	-
12 	- 	17 	40 	- 	12 	31 	- 	40 	26 	- 	31 	17 	- 	19 	  	- 	  	  	- 	  	  	-
4 	- 	32 	4 	- 	25 	4 	- 	18 	4 	- 	11 	18 	- 	20 	  	- 	  	  	- 	  	  	-
39 	- 	25 	32 	- 	18 	25 	- 	11 	18 	- 	39 	21 	- 	22 	  	- 	  	  	- 	  	  	-
11 	- 	18 	39 	- 	11 	32 	- 	39 	25 	- 	32 	23 	- 	25 	  	- 	  	  	- 	  	  	-
5 	- 	33 	5 	- 	24 	5 	- 	19 	5 	- 	10 	24 	- 	26 	  	- 	  	  	- 	  	  	-
38 	- 	24 	33 	- 	19 	24 	- 	10 	19 	- 	38 	27 	- 	29 	  	- 	  	  	- 	  	  	-
10 	- 	19 	38 	- 	10 	33 	- 	38 	24 	- 	33 	28 	- 	30 	  	- 	  	  	- 	  	  	-
6 	- 	34 	6 	- 	23 	6 	- 	20 	6 	- 	9 	31 	- 	33 	  	- 	  	  	- 	  	  	-
37 	- 	23 	34 	- 	20 	23 	- 	9 	20 	- 	37 	32 	- 	34 	  	- 	  	  	- 	  	  	-
9 	- 	20 	37 	- 	9 	34 	- 	37 	23 	- 	34 	35 	- 	37 	  	- 	  	  	- 	  	  	-
7 	- 	35 	7 	- 	22 	7 	- 	21 	7 	- 	8 	36 	- 	38 	  	- 	  	  	- 	  	  	-
36 	- 	22 	35 	- 	21 	22 	- 	8 	21 	- 	36 	39 	- 	41 	  	- 	  	  	- 	  	  	-
8 	- 	21 	36 	- 	8 	35 	- 	36 	22 	- 	35 	40 	- 	42 	  	- 	  	  	- 	  	  	-
NAST Pairings - 44 Players 	  	  	  	  	  	  	  	  	  	  	  	  	  	  	  	No Repeats
  	  	  	  	  	  	  	  	  	  	  	  	  	  	  	  	Swiss 	  	  	Swiss 	  	  	KOH
  	Round 1 	  	  	Round 2 	  	  	Round 3 	  	  	Round 4 	  	  	Round 5 	  	  	Round 6 	  	  	Round 7 	  	  	Round 8
1 	- 	31 	1 	- 	30 	1 	- 	15 	1 	- 	14 	1 	- 	3 	  	- 	  	  	- 	  	  	-
44 	- 	30 	31 	- 	15 	30 	- 	14 	15 	- 	44 	2 	- 	4 	  	- 	  	  	- 	  	  	-
14 	- 	15 	44 	- 	14 	31 	- 	44 	30 	- 	31 	5 	- 	7 	  	- 	  	  	- 	  	  	-
2 	- 	32 	2 	- 	29 	2 	- 	16 	2 	- 	13 	6 	- 	8 	  	- 	  	  	- 	  	  	-
43 	- 	29 	32 	- 	16 	29 	- 	13 	16 	- 	43 	9 	- 	11 	  	- 	  	  	- 	  	  	-
13 	- 	16 	43 	- 	13 	32 	- 	43 	29 	- 	32 	10 	- 	12 	  	- 	  	  	- 	  	  	-
3 	- 	33 	3 	- 	28 	3 	- 	17 	3 	- 	12 	13 	- 	15 	  	- 	  	  	- 	  	  	-
42 	- 	28 	33 	- 	17 	28 	- 	12 	17 	- 	42 	14 	- 	16 	  	- 	  	  	- 	  	  	-
12 	- 	17 	42 	- 	12 	33 	- 	42 	28 	- 	33 	17 	- 	19 	  	- 	  	  	- 	  	  	-
4 	- 	34 	4 	- 	23 	4 	- 	22 	4 	- 	11 	18 	- 	20 	  	- 	  	  	- 	  	  	-
18 	- 	23 	18 	- 	22 	18 	- 	11 	18 	- 	34 	21 	- 	23 	  	- 	  	  	- 	  	  	-
27 	- 	22 	27 	- 	11 	27 	- 	34 	27 	- 	23 	22 	- 	24 	  	- 	  	  	- 	  	  	-
41 	- 	11 	41 	- 	34 	41 	- 	23 	41 	- 	22 	25 	- 	27 	  	- 	  	  	- 	  	  	-
5 	- 	35 	5 	- 	26 	5 	- 	19 	5 	- 	10 	26 	- 	28 	  	- 	  	  	- 	  	  	-
40 	- 	26 	35 	- 	19 	26 	- 	10 	19 	- 	40 	29 	- 	31 	  	- 	  	  	- 	  	  	-
10 	- 	19 	40 	- 	10 	35 	- 	40 	26 	- 	35 	30 	- 	32 	  	- 	  	  	- 	  	  	-
6 	- 	36 	6 	- 	25 	6 	- 	20 	6 	- 	9 	33 	- 	35 	  	- 	  	  	- 	  	  	-
39 	- 	25 	36 	- 	20 	25 	- 	9 	20 	- 	39 	34 	- 	36 	  	- 	  	  	- 	  	  	-
9 	- 	20 	39 	- 	9 	36 	- 	39 	25 	- 	36 	37 	- 	39 	  	- 	  	  	- 	  	  	-
7 	- 	37 	7 	- 	24 	7 	- 	21 	7 	- 	8 	38 	- 	40 	  	- 	  	  	- 	  	  	-
38 	- 	24 	37 	- 	21 	24 	- 	8 	21 	- 	38 	41 	- 	43 	  	- 	  	  	- 	  	  	-
8 	- 	21 	38 	- 	8 	37 	- 	38 	24 	- 	37 	42 	- 	44 	  	- 	  	  	- 	  	  	-
NAST Pairings - 46 Players 	  	  	  	  	  	  	  	  	  	  	  	  	  	  	  	No Repeats
  	  	  	  	  	  	  	  	  	  	  	  	  	  	  	  	Swiss 	  	  	Swiss 	  	  	KOH
  	Round 1 	  	  	Round 2 	  	  	Round 3 	  	  	Round 4 	  	  	Round 5 	  	  	Round 6 	  	  	Round 7 	  	  	Round 8
1 	- 	35 	1 	- 	24 	1 	- 	23 	1 	- 	12 	1 	- 	3 	  	- 	  	  	- 	  	  	-
13 	- 	24 	13 	- 	23 	13 	- 	12 	13 	- 	35 	2 	- 	4 	  	- 	  	  	- 	  	  	-
34 	- 	23 	34 	- 	12 	34 	- 	35 	34 	- 	24 	5 	- 	7 	  	- 	  	  	- 	  	  	-
46 	- 	12 	46 	- 	35 	46 	- 	24 	46 	- 	23 	6 	- 	8 	  	- 	  	  	- 	  	  	-
2 	- 	36 	2 	- 	25 	2 	- 	22 	2 	- 	11 	9 	- 	11 	  	- 	  	  	- 	  	  	-
14 	- 	25 	14 	- 	22 	14 	- 	11 	14 	- 	36 	10 	- 	12 	  	- 	  	  	- 	  	  	-
33 	- 	22 	33 	- 	11 	33 	- 	36 	33 	- 	25 	13 	- 	15 	  	- 	  	  	- 	  	  	-
45 	- 	11 	45 	- 	36 	45 	- 	25 	45 	- 	22 	14 	- 	16 	  	- 	  	  	- 	  	  	-
3 	- 	37 	3 	- 	32 	3 	- 	15 	3 	- 	10 	17 	- 	19 	  	- 	  	  	- 	  	  	-
44 	- 	32 	37 	- 	15 	32 	- 	10 	15 	- 	44 	18 	- 	20 	  	- 	  	  	- 	  	  	-
10 	- 	15 	44 	- 	10 	37 	- 	44 	32 	- 	37 	21 	- 	24 	  	- 	  	  	- 	  	  	-
4 	- 	38 	4 	- 	26 	4 	- 	21 	4 	- 	9 	22 	- 	25 	  	- 	  	  	- 	  	  	-
16 	- 	26 	16 	- 	21 	16 	- 	9 	16 	- 	38 	23 	- 	26 	  	- 	  	  	- 	  	  	-
31 	- 	21 	31 	- 	9 	31 	- 	38 	31 	- 	26 	27 	- 	29 	  	- 	  	  	- 	  	  	-
43 	- 	9 	43 	- 	38 	43 	- 	26 	43 	- 	21 	28 	- 	30 	  	- 	  	  	- 	  	  	-
5 	- 	39 	5 	- 	27 	5 	- 	20 	5 	- 	8 	31 	- 	33 	  	- 	  	  	- 	  	  	-
17 	- 	27 	17 	- 	20 	17 	- 	8 	17 	- 	39 	32 	- 	34 	  	- 	  	  	- 	  	  	-
30 	- 	20 	30 	- 	8 	30 	- 	39 	30 	- 	27 	35 	- 	37 	  	- 	  	  	- 	  	  	-
42 	- 	8 	42 	- 	39 	42 	- 	27 	42 	- 	20 	36 	- 	38 	  	- 	  	  	- 	  	  	-
6 	- 	40 	6 	- 	28 	6 	- 	19 	6 	- 	7 	39 	- 	41 	  	- 	  	  	- 	  	  	-
18 	- 	28 	18 	- 	19 	18 	- 	7 	18 	- 	40 	40 	- 	42 	  	- 	  	  	- 	  	  	-
29 	- 	19 	29 	- 	7 	29 	- 	40 	29 	- 	28 	43 	- 	45 	  	- 	  	  	- 	  	  	-
41 	- 	7 	41 	- 	40 	41 	- 	28 	41 	- 	19 	44 	- 	46 	  	- 	  	  	- 	  	  	-
NAST Pairings - 48 Players 	  	  	  	  	  	  	  	  	  	  	  	  	  	  	  	No Repeats
  	  	  	  	  	  	  	  	  	  	  	  	  	  	  	  	Swiss 	  	  	Swiss 	  	  	KOH
  	Round 1 	  	  	Round 2 	  	  	Round 3 	  	  	Round 4 	  	  	Round 5 	  	  	Round 6 	  	  	Round 7 	  	  	Round 8
1 	- 	37 	1 	- 	25 	1 	- 	24 	1 	- 	12 	1 	- 	3 	  	- 	  	  	- 	  	  	-
13 	- 	25 	13 	- 	24 	13 	- 	12 	13 	- 	37 	2 	- 	4 	  	- 	  	  	- 	  	  	-
36 	- 	24 	36 	- 	12 	36 	- 	37 	36 	- 	25 	5 	- 	7 	  	- 	  	  	- 	  	  	-
48 	- 	12 	48 	- 	37 	48 	- 	25 	48 	- 	24 	6 	- 	8 	  	- 	  	  	- 	  	  	-
2 	- 	38 	2 	- 	26 	2 	- 	23 	2 	- 	11 	9 	- 	11 	  	- 	  	  	- 	  	  	-
14 	- 	26 	14 	- 	23 	14 	- 	11 	14 	- 	38 	10 	- 	12 	  	- 	  	  	- 	  	  	-
35 	- 	23 	35 	- 	11 	35 	- 	38 	35 	- 	26 	13 	- 	15 	  	- 	  	  	- 	  	  	-
47 	- 	11 	47 	- 	38 	47 	- 	26 	47 	- 	23 	14 	- 	16 	  	- 	  	  	- 	  	  	-
3 	- 	39 	3 	- 	27 	3 	- 	22 	3 	- 	10 	17 	- 	19 	  	- 	  	  	- 	  	  	-
15 	- 	27 	15 	- 	22 	15 	- 	10 	15 	- 	39 	18 	- 	20 	  	- 	  	  	- 	  	  	-
34 	- 	22 	34 	- 	10 	34 	- 	39 	34 	- 	27 	21 	- 	23 	  	- 	  	  	- 	  	  	-
46 	- 	10 	46 	- 	39 	46 	- 	27 	46 	- 	22 	22 	- 	24 	  	- 	  	  	- 	  	  	-
4 	- 	40 	4 	- 	28 	4 	- 	21 	4 	- 	9 	25 	- 	27 	  	- 	  	  	- 	  	  	-
16 	- 	28 	16 	- 	21 	16 	- 	9 	16 	- 	40 	26 	- 	28 	  	- 	  	  	- 	  	  	-
33 	- 	21 	33 	- 	9 	33 	- 	40 	33 	- 	28 	29 	- 	31 	  	- 	  	  	- 	  	  	-
45 	- 	9 	45 	- 	40 	45 	- 	28 	45 	- 	21 	30 	- 	32 	  	- 	  	  	- 	  	  	-
5 	- 	41 	5 	- 	29 	5 	- 	20 	5 	- 	8 	33 	- 	35 	  	- 	  	  	- 	  	  	-
17 	- 	29 	17 	- 	20 	17 	- 	8 	17 	- 	41 	34 	- 	36 	  	- 	  	  	- 	  	  	-
32 	- 	20 	32 	- 	8 	32 	- 	41 	32 	- 	29 	37 	- 	39 	  	- 	  	  	- 	  	  	-
44 	- 	8 	44 	- 	41 	44 	- 	29 	44 	- 	20 	38 	- 	40 	  	- 	  	  	- 	  	  	-
6 	- 	42 	6 	- 	30 	6 	- 	19 	6 	- 	7 	41 	- 	43 	  	- 	  	  	- 	  	  	-
18 	- 	30 	18 	- 	19 	18 	- 	7 	18 	- 	42 	42 	- 	44 	  	- 	  	  	- 	  	  	-
31 	- 	19 	31 	- 	7 	31 	- 	42 	31 	- 	30 	45 	- 	47 	  	- 	  	  	- 	  	  	-
43 	- 	7 	43 	- 	42 	43 	- 	30 	43 	- 	19 	46 	- 	48 	  	- 	  	  	- 	  	  	-
EOF

=back

=cut

1;
