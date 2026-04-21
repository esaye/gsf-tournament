#!/usr/bin/perl

# Copyright (C) 2009 John J. Chew, III <jjchew@math.utoronto.ca>
# All Rights Reserved

package TSH::Command::EXPORTRATINGS;

use strict;
use warnings;

use TSH::Log;
use TSH::Utility;
use File::Spec;

our (@ISA) = qw(TSH::Command);

=pod

=head1 NAME

TSH::Command::EXPORTRATINGS - implement the C<tsh> EXPORTRATINGS command

=head1 SYNOPSIS

  my $command = new TSH::Command::EXPORTRATINGS;
  my $argsp = $command->ArgumentTypes();
  my $helptext = $command->Help();
  my (@names) = $command->Names();
  $command->Run($tournament, @parsed_arguments);
  
=head1 ABSTRACT

TSH::Command::EXPORTRATINGS is a subclass of TSH::Command.

=cut

=head1 DESCRIPTION

=over 4

=cut

sub initialise ($$$$);
sub new ($);
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
Use this command to export a new rating list including the results of this event.
EOF
  $this->{'names'} = [qw(exportratings)];
  $this->{'argtypes'} = [qw()];
# print "names=@$namesp argtypes=@$argtypesp\n";

  return $this;
  }

sub new ($) { return TSH::Utility::new(@_); }

=item $command->Run($tournament, @parsed_args)

Should run the command in the context of the given
tournament with the specified parsed arguments.

=cut

sub Run ($$@) { 
  my $this = shift;
  my $tournament = $this->{'x_tournament'} = shift;
# my $processor = $this->Processor();
  my $config = $tournament->Config();

  $tournament->LoadRatings() or return 0;
  $this->Processor()->Flush();
  # store data that needs to be updated in the following hash
  my %new_data;
  my %metadata;
  my $timestamp = $config->Value('event_date');
  if ($timestamp !~ /^\d\d\d\d-\d\d-\d\d$/) {
    $timestamp = 0;
    }
  for my $dp ($tournament->Divisions()) { 
#   $dp->ComputeRatings($config->Value('max_rounds')-1);
    $dp->ComputeRatings($dp->MostScores()-1);
  # copied to here
    my $rating_list = $dp->RatingList();
    my $rating_system = $dp->RatingSystem();
    my $input_filename = $dp->GetInputRatingFilename();

    {
      my $old_rating_system = $metadata{$rating_list}{'rating_system'};
      if ((defined $old_rating_system) and $old_rating_system ne $rating_system) {
	warn "Assertion failed: rating list $rating_list has multiple rating systems";
	}
      $metadata{$rating_list}{'rating_system'} = $rating_system;
    }

    {
      my $old_input_filename = $metadata{$rating_list}{'input_filename'};
      if ((defined $old_input_filename) and $old_input_filename ne $input_filename) {
	warn "Assertion failed: rating list has multiple input filenames";
	}
      $metadata{$rating_list}{'input_filename'} = $input_filename;
    }

    for my $p ($dp->Players()) { 
      my (@names) 
        = $rating_system->CanonicaliseName($rating_list, uc $p->Name());
      my (@ratings) = split(/\+/, $p->NewRating(-1));
      my $games = $p->GamesPlayed();
#     local($") = '!'; print "G:@names:@ratings:@games\n";
      my $rating_term_count = $rating_system->RatingTermCount();
      for my $i (0..$#names) {
	my $key = $names[$i];
	$key =~ s/,//;
	$new_data{$rating_list}{$key} = { 
	  'games' => $games,
	  'rating' => join('+', @ratings[$i*$rating_term_count..
	    ($i+1)*$rating_term_count-1]),
	  'timestamp' => $timestamp,
	  };
        }
      }
    }
  while (my ($rating_list, $rl_new_data) = each %new_data) {
    $this->UpdateRatingList($rating_list, $rl_new_data, $metadata{$rating_list});
    }
  }

# why is this not in lib/perl/Ratings.pm?
sub UpdateRatingList ($$$$) {
  my $this = shift;
  my $rating_list = shift;
  my $rl_new_data = shift;
  my $metadatap = shift;
  my $rating_system = $metadatap->{'rating_system'};
  my $ofn = $metadatap->{'input_filename'};
  my $is_glixo = TSH::Utility::IsASafely($rating_system, 'Ratings::Glixo');

  my $tournament = $this->{'x_tournament'};
  my $config = $tournament->Config();
  my $rating_date = $is_glixo && $config->Value('event_date');
  my $series = $config->Series();
  my $previous_session_id;

  my ($ofh, $nfh, $nfn);
  # if we are a session in a multisession series
  if ($series) {
    $nfn = $config->MakeLibPath(File::Spec->catfile('ratings', $series->SeriesID(), 
      $config->RootDirectoryBasename() . '.txt'));
    }
  else {
    $nfn = $config->MakeLibPath("ratings/$rating_list/new.txt");
    }
  if (!open $ofh, '<:encoding(utf8)', $ofn) {
    $tournament->TellUser('euseropen', $nfn, $!);
    next;
    }
  if (!open $nfh, '>:encoding(utf8)', $nfn) {
    $tournament->TellUser('euseropen', $nfn, $!);
    next;
    }
  if ($series) {
    my $next_session_id = $series->NextSessionID();
    print $nfh "#next $next_session_id\n" if $next_session_id;
    print $nfh "#prev $previous_session_id\n" if $previous_session_id;
    }
  my (@fields) = $is_glixo 
    ? qw(name primary deviation rating_date)
    : qw(name rating rank expiry games);
  my @extra;
  while (<$ofh>) {
    chomp;
    if ($. == 1 && !/\d/) {
      @fields = split(/\t/);
      print $nfh "$_\n";
      next;
      }
    my %data;
    @data{@fields} = split(/\t/);
    $data{'name'} =~ s/,//;
    if (my $p = $rl_new_data->{uc $data{'name'}}) {
      if ($is_glixo) {
	my $rating = $p->{'rating'};
	my ($primary, $deviation) = split(/\+/, $rating);
	$data{'primary'} = $primary;
	$data{'deviation'} = $deviation;
	$data{'rating_date'} = $rating_date;
#	print "OLD:$data{'name'}:$data{'primary'}+$data{'deviation'}:$data{'rating_date'}\n";
	}
      else {
	$data{'rating'} = $p->{'rating'};
	$data{'games'} += $p->{'games'};
#	print "OLD:$data{'name'}:$p->{'rating'}:$p->{'games'}\n";
	}
      print $nfh join("\t", @data{@fields}), "\n";
      delete $rl_new_data->{uc $data{'name'}};
      }
    else {
      print $nfh "$_\n";
      }
    }
  for my $key (sort keys %$rl_new_data) {
    my $p = $rl_new_data->{$key};
    my %data;
#   warn $key;
    if ($is_glixo) {
      my $rating = $p->{'rating'};
      my ($primary, $deviation) = split(/\+/, $rating);
      $data{'primary'} = $primary;
      $data{'deviation'} = $deviation;
      (%data) = (
	'name' => $key,
	'primary' => $primary,
	'deviation' => $deviation,
	'rating_date' => $rating_date,
	);
#     print "NEW:$key:$data{'name'}:$data{'primary'}+$data{'deviation'}:$data{'rating_date'}\n";
      }
    else {
      (%data) = (
	'name' => $key,
	'rating' => $p->{'rating'},
	'rank' => 0,
	'expiry' => $p->{'expiry'} || 0,
	'games' => $p->{'games'},
	);
#     print "NEW:$key:$p->{'rating'}:$p->{'games'}\n";
      }
    print $nfh join("\t", @data{@fields}), "\n";
    }
  close $nfh;
  close $ofh;
  $tournament->TellUser('iexratok', $nfn);
  }

=back

=cut

=head1 BUGS

None known.

=cut


1;

