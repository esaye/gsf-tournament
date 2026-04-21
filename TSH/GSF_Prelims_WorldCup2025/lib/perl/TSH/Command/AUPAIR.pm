#!/usr/bin/perl

# Copyright (C) 2005-2013 John J. Chew, III <jjchew@math.utoronto.ca>
# All Rights Reserved

package TSH::Command::AUPAIR;

use strict;
use warnings;

use TSH::Utility;
use Ratings::WESPA;
# use Ratings::Player;

our (@ISA) = qw(TSH::Command);

=pod

=head1 NAME

TSH::Command::AUPAIR - implement the C<tsh> AUPAIR command

=head1 SYNOPSIS

  my $command = new TSH::Command::AUPAIR;
  my $argsp = $command->ArgumentTypes();
  my $helptext = $command->Help();
  my (@names) = $command->Names();
  $command->Run($tournament, @parsed_arguments);
  
=head1 ABSTRACT

TSH::Command::AUPAIR is a subclass of TSH::Command.

=cut

=head1 DESCRIPTION

=over 4

=cut

sub initialise ($$$$);
sub new ($);
sub NormaliseDate ($);
# sub NormalisePlace ($);
sub Run ($$@);

=item $parserp->initialise()

Used internally to (re)initialise the object.

=cut

sub initialise ($$$$) {
  my $this = shift;
  my $path = shift;
  my $namesp = shift;
  my $argtypesp = shift;

  $this->{'help'} = <<'EOF';
Use this command to create a AUPAIR .TOU file,
to submit to a rating system requiring that input format.
EOF
  $this->{'names'} = [qw(aupair)];
  $this->{'argtypes'} = [qw(OptionalDivisions)];
# print "names=@$namesp argtypes=@$argtypesp\n";

  return $this;
  }

sub new ($) { return TSH::Utility::new(@_); }

my (%months) = (
  'Jan' =>       1,
  'January' =>   1,
  'Feb' =>       2,
  'February' =>  2,
  'Mar' =>       3,
  'March' =>     3,
  'Apr' =>       4,
  'April' =>     4,
  'May' =>       5,
  'Jun' =>       6,
  'June' =>      6,
  'Jul' =>       7,
  'July' =>      7,
  'Aug' =>       8,
  'August' =>    8,
  'Sep' =>       9,
  'Sept' =>      9,
  'September' => 9,
  'Oct' =>       10,
  'October' =>   10,
  'Nov' =>       11,
  'November' =>  11,
  'Dec' =>       12,
  'December' =>  12,
  );

sub NormaliseDate ($) {
  my $date = shift @_;
  my $orig = $date;
  my ($yyyy, $mm, $dd);
  if ($date =~ s/\b([2-9]\d\d\d)\b//) { 
    $yyyy = $1;
    if ($date =~ s/\b(Jan|January|Feb|February|Mar|March|Apr|April|May|Jun|June|Jul|July|Aug|August|Sep|Sept|September|Oct|October|Nov|November|Dec|December)\b(.*)/$2/) {
      $mm = $months{$1};
      if ($date =~ s/(\d+)\D*$//) {
	$dd = $1;
        }
      else {
	warn "Can't find day in date '$date'";
	return $date;
        }
      }
    elsif ($date =~ s!-(\d+)-(\d+)!!) {
      $mm = $1;
      $dd = $2;
      }
    elsif ($date =~ s!(\d+)/(\d+)/!!) {
      $mm = $1;
      $dd = $2;
      if ($mm > 12) { ($mm, $dd) = ($dd, $mm) }
      elsif ($dd <= 12) { warn "Guessing mm/dd/yyyy format - next time, use yyyy-mm-dd.\n"; }
      }
    }
  else { 
    warn "Can't find year in date '$date'";
    return $date;
    }
  return sprintf("%02d.%02d.%04d", $dd||00, $mm||00, $yyyy);
  }

=item $command->Run($tournament, @parsed_args)

Should run the command in the context of the given
tournament with the specified parsed arguments.

=cut

# TODO: split this up into smaller subs for maintainability

sub Run ($$@) { 
  my $this = shift;
  my $tournament = shift;
  my $config = $tournament->Config();
  my $aupair_bye_ties = !$config->Value('no_aupair_bye_ties');
  my $event_date = $config->Value('event_date');
  my $event_name = $config->Value('event_name');
  unless (@_) { (@_) = $tournament->Divisions(); }
  unless ($event_date) { $tournament->TellUser('eneededate'); return; }
  unless ($event_name) { $tournament->TellUser('eneedename'); return; }
  $event_date = NormaliseDate $event_date;
# $event_place = NormalisePlace $event_place;
  my $fn = $config->MakeRootPath(@_ > 1 
    ? "AUPAIR.TOU" : uc($_[0]->Name()) . '.TOU');
  my $fh = TSH::Utility::OpenFile(">", $fn);
  unless ($fh) {
    TSH::Utility::Error("Can't create $fn: $!");
    return;
    }
  binmode $fh;
  for my $dn (0..$#_) {
    my $dp = $_[$dn];
    my $dname = $dp->Name();
    my $nrounds = $dp->MostScores();
    if ($nrounds != $dp->LeastScores()) {
      TSH::Utility::Error "Not all results are in yet in round $nrounds.";
      return;
      }
    print $fh "*M$event_date $event_name\015\012" unless $dn;
    print $fh "*$dname\015\012";
    print $fh "                                      0\015\012"; # fake high word

    my $wespa = ($config->Value('rating_list')||'') =~ /wespa|naspa/;
    my $invert_names = ($config->Value('realm')||'') !~ /^nga$/;
    my %rating_hash;
    my $rating_system;
    if ($wespa) { 
      $rating_system = $dp->RatingSystem(); 
      my $rating_list = $dp->RatingList();
      my $fn = $config->MakeLibPath("ratings/$rating_list/current.txt");
      $rating_system->LoadFileToHash($fn, \%rating_hash, 'create');
      }
    my (@players);
    my (@tsh_pid_to_aupair) = (0);
    {
      for my $p ($dp->Players()) {
#	warn $p->TaggedName() . ' ' . $p->GamesPlayed();
	if ($p->GamesPlayed()) {
	  push(@players, $p);
	  push(@tsh_pid_to_aupair, scalar(@players));
	  if ($wespa) {
	    my $key = $p->Name();
	    $key = uc Ratings::WESPA::Canonicalise($key);
	    $key =~ s/,//g;
	    if ($p->Rating()) {
	      if (!$rating_hash{$key}) {
		print $p->Name() . " has a rating in your .t file, but is not listed in the WESPA rating list as $key. Please check the spelling and correct it, or set the rating to 0.\n";
	        }
	      }
	    else {
	      if ($rating_hash{$key}) {
		print $p->Name() . " has no rating in your .t file, but there is a listing in the WESPA rating list by that name. Please check the spelling and correct it, advise Bob Jackman that there is a new player from ".($p->Team()||'(country unknown to TSH)')." with the same name as an old one, or set the rating to a nonzero value.\n";
	        }
	      else {
		print "It looks like ".$p->Name()." is new to the WESPA rating system. When submitting your data to Bob Jackman, please confirm that this is true, and give the player's country (".($p->Team()||'unknown to TSH').") for identification purposes.\n";
	        }
	      }
	    }
	  }
	else {
	  push(@tsh_pid_to_aupair, 0);
	  }
	}
    }

    for my $p (@players) {
      my $name = $p->Name();
      $name = Ratings::WESPA::Canonicalise($name) if $wespa;
      next unless $tsh_pid_to_aupair[$p->ID()];
      my ($surname, $given) = split(/, */, $name, 2);
      if (!$invert_names) {
	$name = "$surname $given";
        }
      elsif (defined $given) {
	# TSH stores player names internally as "$surname, $given".
	# The raw WESPA rating list lists player names in their common order (John Chew, Cheah Siu Hean).
	# The processed WESPA rating list in lib/ratings/wespa/current.txt uses TSH name format.
	# For exporting to WESPA however, we need to reconstitute WESPA raw format.
	# This ugly kludge does so.
	if ($given =~ /^\S+ \S+$/ and $surname =~ /^(?:ANG|CHANG|CHEAH|CHEN|CHEONG|CHEW|CHIA|CHIM|CHING|CHOO|CHOW|CHUAH|GAN|GOH|H'NG|HO|KER|KHOO|KOH|KONG|KUM|KWOK|LAU|LEE|LIEW|LIM|LOH|LOOI|LUM|MAK|NG|ONG|PEH|POH|PUI|PUTRI|QUEK|SHIM|TAN|TOH|WONG|YEAP|YEO|YEOH|YEW|YIP|YONG|YOON|YUB)$/i and
	  # but Chinese names erroneously appear in the WESPA list in first-last order (E.g., Yi En Gan)
	  $name !~ /^(?:GAN, YI EN|POH, YING MING)$/i 
	) {
	  $name = "$surname $given";
	  }
	else {
	  $name = "$given $surname";
	  }
        }
      elsif ($name !~ /^(?:Quackle|Akkarapol|Kaia|Winter)$/i && $config->Value('realm') ne 'sgp') {
	$tournament->TellUser('enocomma', $name);
	return 0;
        }
      printf $fh "%-20.20s", $name;
      for my $r (1..$nrounds) {
	my $r0 = $r - 1;
	if (defined $p->Opponent($r0)) {
	  if (my $oppid = $tsh_pid_to_aupair[$p->OpponentID($r0)]) {
	    printf $fh ($p->First($r0)==1) ? " %1s%3d%+4d" : " %1s%3d%4d", 
	      ('1','2',' ')[$p->Score($r0) <=> ($p->OpponentScore($r0)||0)],
	      $p->Score($r0),
	      $oppid;
	    }
	  else {
	    $tournament->TellUser('eaupunk', $p->TaggedName(), $p->OpponentID($r0), $r0+1);
	    return;
	    }
	  }
	elsif ($aupair_bye_ties) {
	  # Barry Harridge 2007-09-04:
	  # The RATINGS.EXE which Bob is using has no explicit way
	  # of coping with byes.  The source code is lost so there
	  # is no way of fixing it (but we now use a Perl program for
	  # Australian ratings).
	  # We overcome that limitation by representing a bye for
	  # player A as a tied game of A playing A with an arbitrary
	  # score. This should give a rating change of zero since his
	  # opponent has the same rating as himself.
	  #
	  # 2013-03-28 Edward Okulicz
	  # Q1. In the file linked above, REDACTED has recorded a
	  #     350-point tie against themselves in round 1. Why was this?
	  # A1. That's a draw as well. It's a deprecated way of doing
	  #     it, but sometimes it occurs in files.
	  # Q2. How should I record a forfeit loss, or the rarer
          #     unplayed/unscored game (not rated, no wins, losses or
          #     spread assigned)?
	  # A2.
	  # 1000   X where the player number is X should do a draw
	  # 0000   X for a forfeit loss.
	  # 2001   X for a winning bye (1 point). I don't see any
	  #        reason you couldn't make it 2075  X - wouldn't open in
	  #        AuPair but that doesn't strike me as important.

	  my $ms = $p->Score($r0);
	  my $aupair_id = $tsh_pid_to_aupair[$p->ID()];
	  if ($ms > 0) {
	    printf $fh " %1s%03d%+4d", 2, 1, $aupair_id;
	    }
	  elsif ($ms == 0) {
#	    printf $fh " %1s%03d%4d", 1, 350, $aupair_id; # obsoleted 2013-03-28
 	    printf $fh " %1s%03d%4d", 1, 0, $aupair_id;
	    }
	  else {
	    printf $fh " %1s%03d%4d", 0, 0, $aupair_id;
	    }
	  }
        } # for $r0
      print $fh "\015\012";
      } # for my $p
    }
  print $fh "*** END OF FILE ***\015\012";
  close $fh;
  $tournament->TellUser('idone');
  }

=back

=cut

=head1 BUGS

Makes extensive inappropriate use of Player.pm internals.

Currently only exports one division at a time.

=cut

1;
