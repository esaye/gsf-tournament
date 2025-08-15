#!/usr/bin/perl

# Copyright (C) 2013 John J. Chew, III <jjchew@math.utoronto.ca>
# All Rights Reserved

package TSH::Command::UpdatePLAYers;

use strict;
use warnings;

use WebUpdate;

our (@ISA) = qw(TSH::Command);

=pod

=head1 NAME

TSH::Command::UpdatePLAYers - implement the C<tsh> UpdatePLAYers command

=head1 SYNOPSIS

  my $command = new TSH::Command::UpdatePLAYers;
  my $argsp = $command->ArgumentTypes();
  my $helptext = $command->Help();
  my (@names) = $command->Names();
  $command->Run($tournament, @parsed_arguments);
  
=head1 ABSTRACT

TSH::Command::UpdatePLAYers is a subclass of TSH::Command.

=cut

=head1 DESCRIPTION

=over 4

=cut

my (%gCorrections) = (
  'RSH' => 'Horowitz, Risa',
  'Orourke, Tom' => 'O\'Rourke, Tom',
  'Kout, Trix' => 'Kout, Trx',
  'Green, Jc' => 'Green, JC',
  'Premore, Bj' => 'Premore, BJ',
  'Firstman, Db' => 'Firstman, DB',
  );

sub initialise ($$$$);
sub new ($);
sub Run ($$@);

sub BeginDivision ($$) {
  my $this = shift;
  my $dpsp = shift;
  my $dp = $dpsp->[0];
  unless ($dp) {
    $this->Processor()->Tournament()->TellUser('euplay2md');
    return 0;
    }
  if ($dp->MostScores()) {
    $dp->Tournament()->TellUser('ectscores', $dp->Name());
    return 0;
    }
  $dp->DeleteAllPlayers();
  return 1;
  }

sub EndDivision ($$) {
  my $this = shift;
  my $dpsp = shift;
  if (@$dpsp) {
    my $dp = $dpsp->[0];
    $dp->Synch();
    $dp->Write();
    }
  }

=item $this->FetchCTRosters($ctid, \@dps, $tourney, $wup);

Fetch roster data from a designated cross-tables event and store it
in the designated divisions.

=cut

sub FetchCTRosters ($$$$) {
  my $this = shift;
  my $ctid = shift;
  my $dpsp = shift;
  my $tournament = shift;
  my $wup = shift;

  if (my $content = $wup->GetFile("/entrants.php?u=$ctid&text=1")) {
    if ($content =~ /^</) {
      my $has_title = $content =~ s/[^\0]*<title>(.*)<\/title>[^\0]*/$1/i;
      warn $ctid;
      $tournament->TellUser('euplayget', $has_title ? $content : "unknown error");
      return 0;
      }
# if (1) { my $fh = TSH::Utility::OpenFile("<", 'test', 'roster.txt') || die; local($/) = undef; my $content = <$fh>; close $fh;
    $tournament->TellUser('igotct');
    $content =~ s/\015/\n/g;
#   print "Content: $content\n";
    $this->BeginDivision($dpsp) or return 0;
    my $at_start = 1;
    for my $line (split(/\n/, $content)) {
#     print "$line\n";
      if ($line =~ /^Division \d/) {
	if ($at_start) { 
	  $at_start = 0;
	  }
	else {
	  $this->EndDivision($dpsp);
	  shift @$dpsp;
	  $this->BeginDivision($dpsp) or return 0;
	  }
        }
      elsif ($line !~ /\S/) {
        }
#      if ($line !~ /\S/) {
#	if (@$dpsp) {
#	  $this->EndDivision($dpsp);
#	  }
#	shift @$dpsp;
#	$this->BeginDivision($dpsp) or return 0;
#        }
      else {
	$line =~ s/\s+\*\s*$/ 0/;
#	$line =~ s/[^a-zA-Z]*$/ 0/ unless $line =~ /\d$/;
 	$line =~ s/$/ 0/ unless $line =~ /\s\d/;
	my ($name, $rating) = $line =~ /^\s*(.*\S)\s+(\d+)/;
	die "Can't parse: $line" unless defined $name;
        $name =~ s/[A-Z]+(?!\d)/ucfirst lc $&/ge if $name !~ /[a-z]/;
	if (my $corrected = $gCorrections{$name}) {
	  $name = $corrected;
	  }
	elsif ($name && $name =~ /,/) {
	  $name =~ s/\b(Ma?c)([a-z])([a-z])/$1\u$2$3/g;
	  $name =~ s/\bMacAsimbar/Macasimbar/g;
	  $name =~ s/\bOlaugh/OLaugh/g;
	  $name =~ s/\bKc\b/KC/g;
	  $name =~ s/^(.*,.*?),?\s*(Ii|Iii|Iv|Vi|Vii)$/$1, \U$2/i;
	  $name =~ s/^(.*,.*?),?\s*(Jr)$/$1, Jr/;
	  }
	elsif ($name && $name =~ /(\S+) (\S*.*\S)/) {
#	  if ($rating && ! $line =~ /[a-z]/) {
	  my $a = $1;
	  my $b = $2;
	  $b =~ s/\s*\^\s*$//;
	  if ($line !~ /[a-z]/) {
	    $name = "$a, $b";
	    }
	  else {
	    $name = "$b, $a";
	    }
	  }
	elsif ($line =~ /^\s*0/) { # cross-tables bug
	  $name = "Player, Unknown";
	  $rating = 0;
	  }
	if (@$dpsp) {
	  $dpsp->[0]->AddPlayer('name' => $name, 'rating' => $rating);
	  }
	else {
	  $tournament->TellUser('elongct');
	  }
        }
      }
    $this->EndDivision($dpsp);
    $tournament->Config()->AssignClasses();
    $tournament->TellUser('iuplayok');
    }
  else {
    $tournament->TellUser('efetchct');
    }
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
Use this command to update your player roster from
the cross-tables.com web site.
EOF
  $this->{'names'} = [qw(updateplayers uplay)];
  $this->{'argtypes'} = [qw()];
# print "names=@$namesp argtypes=@$argtypesp\n";

  return $this;
  }

=item $divmap = $command->MakeCTDivmap(\@ctids, $tournament)

Parse the cross_tables_id configuration parameter value to map cross-tables
event numbers to lists of TSH divisions.

=cut

sub MakeCTDivmap ($$$) {
  my $this = shift;
  my $ctidp = shift;
  my $tourney = shift;

  my (@dps) = $tourney->Divisions();
  $ctidp = [$ctidp] unless ref $ctidp;

  my %divmap;
  for my $di (0..$#dps) {
    my $ctid = $ctidp->[$di > $#$ctidp ? -1 : $di];
    push(@{$divmap{$ctid}}, $dps[$di]);
    }
  return \%divmap;
  }

sub new ($) { return TSH::Utility::new(@_); }

=item $command->Run($tournament, @parsed_args)

Should run the command in the context of the given
tournament with the specified parsed arguments.

=cut

sub Run ($$@) {
  my $this = shift;
  my $tournament = shift;

  my $ctid = $tournament->Config()->Value('cross_tables_id');
  unless ($ctid) {
    $tournament->TellUser('enoctid');
    return 0;
    }
  my $site = 'cross-tables.com';
  my $wup = new WebUpdate(
    'server' => $site,
    'basepath' => '',
    'localpath' => '',
    'secure' => 1,
    );
  $tournament->TellUser('iconnct', $site);

  my $ctDivmap = $this->MakeCTDivmap($ctid, $tournament);
  while (my ($ctid, $dpsp) = each %$ctDivmap) {
    $this->FetchCTRosters($ctid, $dpsp, $tournament, $wup);
    }

  }

=back

=cut

1;
