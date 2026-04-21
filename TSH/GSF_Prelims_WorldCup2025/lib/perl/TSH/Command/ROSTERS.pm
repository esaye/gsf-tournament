#!/usr/bin/perl

# Copyright (C) 2008-2011 John J. Chew, III <jjchew@math.utoronto.ca>
# All Rights Reserved

package TSH::Command::ROSTERS;

use strict;
use warnings;

use TSH::Log;
use TSH::Utility;

our (@ISA) = qw(TSH::Command);

=pod

=head1 NAME

TSH::Command::ROSTERS - implement the C<tsh> ROSTERS command

=head1 SYNOPSIS

  my $command = new TSH::Command::ROSTERS;
  my $argsp = $command->ArgumentTypes();
  my $helptext = $command->Help();
  my (@names) = $command->Names();
  $command->Run($tournament, @parsed_arguments);
  
=head1 ABSTRACT

TSH::Command::ROSTERS is a subclass of TSH::Command.

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
Use this command to list player rosters showing player numbers, ratings and names for
all divisions in your tournament, for your pretournament reference.
EOF
  $this->{'names'} = [qw(rosters)];
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
  my $tournament = shift;
  my $processor = $this->Processor();
  my $config = $tournament->Config();
  my $q_show_teams = $config->Value('show_teams');
  my $q_localise_names = $config->Value('localise_names');
  my $q_show_ratings = $config->Value('rating_system') ne 'none';
  my $q_show_photos = $config->Value('show_roster_photos');
  $q_show_photos = $config->Value('player_photos') unless defined $q_show_photos;
  my $q_show_classes = $config->Value('show_roster_classes');
  my $q_alpha_rosters = $config->Value('alpha_rosters'); # deprecated
  my $q_roster_order = $config->Value('roster_order') || 'rank';
  my $q_school_bios = $config->Value('school_bios');
  my $i18n_Division = $config->Terminology('Division');
  my (@divisions) = $tournament->Divisions();
  if (defined $q_alpha_rosters) {
    $tournament->TellUser('walphar');
    $q_roster_order = 'alpha';
    }
  my %school_bios;
  if ($q_school_bios) {
    eval 'use NSA::SchoolBios qw(LoadBios)';
    if ($@) {
      $school_bios{'_error'} = 1;
      }
    else {
      (%school_bios) = map { $_->{'school'} => $_ } @{
	NSA::SchoolBios::LoadBios($config->MakeRootPath($q_school_bios))
	};
      }
    }

  my $logp = $this->{'log'} = new TSH::Log( $tournament, undef, 'rosters', undef,
    {'title' => $config->Terminology('Player_Rosters')});
  $this->{'divisions'} = \@divisions;
  my $width = 2;
  $width++ if $q_show_teams;
  $width++ if $q_show_photos;
  $width++ if $q_show_ratings;
  $width++ if $q_show_classes;
  $logp->ColumnAttributes([(qq(colspan=$width)) x @divisions]);
  $logp->ColumnClasses([(q(division)) x @divisions]);
  $logp->ColumnTitles(
    {
    'text' => [ map { (('')x($width-1),"$i18n_Division ".$_->Name()) } @divisions ],
    'html' => [ map { "$i18n_Division ".$_->Name() } @divisions ],
    }
    );
  $logp->ColumnAttributes([]);
  my (@classes) = qw(rank);
  push(@classes, 'rating') if $q_show_ratings;
  push(@classes, 'team') if $q_show_teams;
  push(@classes, 'class') if $q_show_classes;
  push(@classes, 'photo') if $q_show_photos;
  push(@classes, 'player');
  push(@classes, 'player', 'player') if $q_school_bios;
  $logp->ColumnClasses([(@classes) x @divisions]);
  my (@text_titles) = ('#');
  my (@html_titles) = ('#');

  push(@text_titles, $config->Terminology('Rtng')) if $q_show_ratings;
  push(@html_titles, $config->Terminology('Rating')) if $q_show_ratings;
  push(@text_titles, $config->Terminology('Team')) if $q_show_teams;
  push(@html_titles, $config->Terminology('Team')) if $q_show_teams;
  push(@text_titles, $config->Terminology('Class')) if $q_show_classes;
  push(@html_titles, $config->Terminology('Class')) if $q_show_classes;
  push(@text_titles, '') if $q_show_photos;
  push(@html_titles, $config->Terminology('Photo')) if $q_show_photos;
  if ($q_school_bios) {
    push(@text_titles, $config->Terminology('Team'));
    push(@html_titles, $config->Terminology('Team'));
    push(@text_titles, $config->Terminology('Player_1'));
    push(@html_titles, $config->Terminology('Player_1'));
    push(@text_titles, $config->Terminology('Player_2'));
    push(@html_titles, $config->Terminology('Player_2'));
    }
  else {
    push(@text_titles, $config->Terminology('Player'));
    push(@html_titles, $config->Terminology('Player'));
    }
  $logp->ColumnTitles(
    {
    'text' => [ (@text_titles) x @divisions],
    'html' => [ (@html_titles) x @divisions],
    });
  my @players;
  my $rows = 0;
  for my $dp (@divisions) {
    my (@dplayers) = $dp->Players();
    if ($q_roster_order =~ /alpha/i) {
      @dplayers = sort { $a->PrettyName({'localise'=>1}) cmp $b->PrettyName({'localise'=>1}) } @dplayers;
      }
    elsif ($q_roster_order =~ /class-team/i) {
      @dplayers = sort { ($a->Class()||'') cmp ($b->Class()||'') or ($a->Team()||'') cmp ($b->Team()||'') or $a->ID() <=> $b->ID() } @dplayers; 
      }
    elsif ($q_roster_order =~ /team/i) {
      @dplayers = sort { ($a->Team()||'') cmp ($b->Team()||'') or $a->ID() <=> $b->ID() } @dplayers; 
      }
    elsif ($q_roster_order =~ /rank/i) {
      @dplayers = sort { ($b->Rating()||0) <=> ($a->Rating()||0) or $a->ID() <=> $b->ID() } @dplayers; 
      }
    elsif ($q_roster_order =~ /seed/i) {
      @dplayers = sort { $a->ID() <=> $b->ID() } @dplayers; 
      }
    push(@players, \@dplayers);
    my $thisrows = scalar(@{$players[-1]});
    $rows = $thisrows if $rows < $thisrows;
    }
  my $nactive = 0;
  my $nrendered = 0;
  for my $row (1..$rows) {
    my $pn0 = $row - 1;
    my @html;
    my @text;
    for my $i (0..$#players) {
      if (my $p = $players[$i][$pn0]) {
	$nrendered++;
	if ($p->Active()) {
	  $nactive++;
	  my (@fields) = ($p->ID());
	  push(@fields, $p->Division()->RatingSystem()->RenderRating($p->Rating())) if $q_show_ratings;
	  push(@fields, $p->Team()) if $q_show_teams;
	  push(@fields, $p->Class()) if $q_show_classes;
	  push(@html, @fields);
	  push(@text, @fields);
	  if ($q_show_photos) {
	    my $url = $p->PhotoURL();
	    push(@text, '');
	    if ($url) {
	      push(@html, qq{<img src="$url" height=36 width=36>});
	      }
	    else {
	      push(@html, '');
	      }
	    }
	  push(@html, $p->TaggedHTMLName({'style'=>'print', 'noid' => 1, 'noteam' => 1, 'localise'=>$q_localise_names}));
	  push(@text, $p->TaggedName({'style'=>'print', 'noid' => 1, 'noteam' => 1, 'localise'=>$q_localise_names}));
	  if ($q_school_bios) {
	    if (my $sp = $school_bios{$p->Name()}) {
	      for my $key (qw(player1 player2)) {
		my $name = $sp->{$key} || '';
		while ($name =~ s/([a-z]+)(.*) ([A-Za-z])[-'A-Za-z]\S*/$1$2 $3./) { }
#		warn $name;
		push(@html, $name);
		push(@text, $name);
	        }
	      }
	    elsif (!$school_bios{'_error'}) {
	      warn "No such school in $q_school_bios: ".$p->Name();
	      }
	    }
	  }
	else {
	  my (@fields) = ('-');
	  push(@fields, '') if $q_show_ratings;
	  push(@fields, '') if $q_show_teams;
	  push(@fields, '') if $q_show_classes;
	  push(@html, @fields);
	  push(@text, @fields);
	  push(@text, '') if $q_show_photos;
	  push(@html, '') if $q_show_photos;
	  push(@html, '');
	  push(@text, '');
	  }
        }
      else {
	push(@html, ('') x $width);
	push(@text, ('') x $width);
        }
      }
    $logp->WriteRow(\@text, \@html);
    }
  $logp->Close();
  if (!$nrendered) {
    $tournament->TellUser('wdivsempty');
    }
  elsif (!$nactive) {
    $tournament->TellUser('wplyrsna');
    }
  }

=back

=cut

=head1 BUGS

None known.

=cut


1;
