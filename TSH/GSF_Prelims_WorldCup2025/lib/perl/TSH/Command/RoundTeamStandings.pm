#!/usr/bin/perl

# Copyright (C) 2022 John J. Chew, III <poslfit@gmail.com>
# All Rights Reserved

package TSH::Command::RoundTeamStandings;

use strict;
use warnings;

use TSH::Log;
# use TSH::Utility qw(Debug DebugOn);
use TSH::Utility qw(FormatHTMLHalfInteger FormatHTMLSignedInteger);

# DebugOn('SP');

our (@ISA) = qw(TSH::Command);

=pod

=head1 NAME

TSH::Command::RoundTeamStandings - implement the C<tsh> RoundTeamStandings command

=head1 SYNOPSIS

  my $command = new TSH::Command::RoundTeamStandings;
  my $argsp = $command->ArgumentTypes();
  my $helptext = $command->Help();
  my (@names) = $command->Names();
  $command->Run($tournament, @parsed_arguments);
  
=head1 ABSTRACT

TSH::Command::RoundTeamStandings is a subclass of TSH::Command.

=cut

=head1 DESCRIPTION

=over 4

=cut

sub CompareSquads ($$);
sub CompareTeams ($$);
sub initialise ($$$$);
sub new ($);
sub RankTeam ($$);
sub RenderTable ($);
sub Run ($$@);
sub SquadKey ($);
sub TeamKey ($);

my (%field_info) = (
  'mean_rank' => { 'class' => 'mean_rank', 'text_key' => 'meanrk', 'html_key' => 'meanrank', 
    'render' => sub {
      my $p = shift @_;
      my $count = $p->{'count'};
      return sprintf("%6.2f", $count && $p->{'ranksum'}/$count);
      } },
  'mean_spread' => { 'class' => 'mean_spread', 'text_key' => 'meansprd', 'html_key' => 'meanspread', 
    'html_render' => sub {
      my $p = shift @_;
      my $count = $p->{'count'};
      return sprintf("%+.1f", $count && $p->{'spread'}/$count);
      }, 
    'text_render' => sub {
      my $p = shift @_;
      my $count = $p->{'count'};
      return sprintf("%+7.1f", $count && $p->{'spread'}/$count);
      } },
  'mean_wl' => { 'class' => 'mean_wl', 'text_key' => 'mean-wl', 'html_key' => 'mean_w-l', 
    'html_render' => sub {
      my $p = shift @_;
      my $count = $p->{'count'};
      return sprintf("%.2f&ndash;%.2f", $count && $p->{'wins'}/$count,
	$count && $p->{'losses'}/$count);
      },
    'text_render' => sub {
      my $p = shift @_;
      my $count = $p->{'count'};
      return sprintf("%.2f-%.2f", $count && $p->{'wins'}/$count,
	$count && $p->{'losses'}/$count);
      } },
  'rank' => { 'class' => 'rank', 'text_key' => 'Rnk', 'html_key' => 'Rank', 
    'render' => sub {
      my $p = shift @_;
      return $p->{'rank'};
      } },
  'ranks' => { 'class' => 'ranks', 'text_key' => 'Ranks', 'html_key' => 'Ranks', 
    'render' => sub {
      my $p = shift @_;
      return $p->{'rankstring'} if $p->{'rankstring'};
      return join(' ', sort { $a <=> $b } @{$p->{'ranks'}});
      } },
  'spread' => { 'class' => 'spread', 'text_key' => 'Spread', 'html_key' => 'Spread', 
    'html_render' => sub {
      my $p = shift @_;
      my $myconfigp = shift @_;
      my $r0 = $myconfigp->{'r0'};
      return $myconfigp->{'positive_scores'} ?  FormatHTMLInteger($p->{'spread'})
	: FormatHTMLSignedInteger($p->{'spread'});
      }, 
    'text_render' => sub {
      my $p = shift @_;
      my $myconfigp = shift @_;
      my $r0 = $myconfigp->{'r0'};
      return sprintf($myconfigp->{'positive_scores'} ?
	'%d' : "%+d", $p->{'spread'});
      } },
  'squad_player_wl' => { 'class' => 'squad spwl wl', 'text_key' => 'Player_W_L', 'html_key' => 'Player_Won_Lost', 
    'html_render' => sub {
      my $p = shift @_;
      return FormatHTMLHalfInteger($p->{'xspwins'}) .
        '&ndash;' . FormatHTMLHalfInteger($p->{'xsplosses'});
      },
    'text_render' => sub {
      my $p = shift @_;
      return sprintf("%.1f-%.1f", $p->{'xspwins'}, $p->{'xsplosses'});
      } },
  'squad_spread' => { 'class' => 'squad spread', 'text_key' => 'Sprd', 'html_key' => 'Spread', 
    'html_render' => sub {
      my $p = shift @_;
      my $myconfigp = shift @_;
      my $r0 = $myconfigp->{'r0'};
      return $myconfigp->{'positive_scores'} ?  FormatHTMLInteger($p->{'xsspread'})
	: FormatHTMLSignedInteger($p->{'xsspread'});
      }, 
    'text_render' => sub {
      my $p = shift @_;
      my $myconfigp = shift @_;
      my $r0 = $myconfigp->{'r0'};
      return sprintf($myconfigp->{'positive_scores'} ?
	'%d' : "%+d", $p->{'xsspread'});
      } },
  'squad_team_wl' => { 'class' => 'squad stwl wl', 'text_key' => 'Squad_W_L', 'html_key' => 'Squad_Won_Lost', 
    'html_render' => sub {
      my $p = shift @_;
      return FormatHTMLHalfInteger($p->{'xstwins'}) .
        '&ndash;' . FormatHTMLHalfInteger($p->{'xstlosses'});
      },
    'text_render' => sub {
      my $p = shift @_;
      return sprintf("%.1f-%.1f", $p->{'xstwins'}, $p->{'xstlosses'});
      } },
  'team' => { 'class' => 'team', 'text_key' => 'Team', 'html_key' => 'Team', 
    'render' => sub {
      my $p = shift @_;
      return $p->{'name'};
      } },
  'wl' => { 'class' => 'wl', 'text_key' => 'W_L', 'html_key' => 'Won_Lost', 
    'html_render' => sub {
      my $p = shift @_;
      return FormatHTMLHalfInteger($p->{'wins'}) .
        '&ndash;' . FormatHTMLHalfInteger($p->{'losses'});
      },
    'text_render' => sub {
      my $p = shift @_;
      return sprintf("%.1f-%.1f", $p->{'wins'}, $p->{'losses'});
      } },
  'wpvso' => { 'class' => 'wpvso', 'text_key' => 'W%VsO', 'html_key' => 'Winning_%_vs._Others', 
    'render' => sub {
      my $p = shift @_;
      my $count = $p->{'xcount'};
      return sprintf("%6.2f", $count && 100*$p->{'xwins'}/$count);
      } },
  );

sub CalculateQuotaMeans($$) {
  my $teamsp = shift;
  my $quotasp = shift;
  
  my $quotaDenominator = 2; # WESPAC 2017
  $quotaDenominator = 1; # since then
  
  for my $team (keys %$teamsp) {
    my $teamp = $teamsp->{$team};
    my (@ranks) = sort { $a <=> $b } @{$teamp->{'ranks'}};
    if (my $quota = $quotasp->{$team}) {
      if (@ranks > $quota) {
#	warn "Capping $team at $quota.\n";
	my $sum = 0;
	for my $i (0..$quota-1) {
	  $sum += $ranks[$i];
	  }
	$teamp->{'ranksum'} = $sum;
	$teamp->{'rankstring'} = "@ranks[0..$quota-1] QUOTA @ranks[$quota..$#ranks]";
	$teamp->{'count'} = $quota;
        }
      elsif (@ranks < $quota/$quotaDenominator) {
#	warn "@ranks not greater than $quota/$quotaDenominator";
	push(@ranks, (999) x ($quota - @ranks));
	$teamp->{'rankstring'} = "@ranks";
	$teamp->{'ranksum'} = 999;
	$teamp->{'count'} = 1;
        }
      }
    else {
      warn "No quota for team $team.\n";
      }
    }
  }

sub CompareSquads ($$) {
  my $a = shift;
  my $b = shift;
  return $b->{'xstwins'} <=> $a->{'xstwins'}
    || $a->{'xstlosses'} <=> $b->{'xstlosses'}
    || $b->{'xspwins'} <=> $a->{'xspwins'}
    || $a->{'xsplosses'} <=> $b->{'xsplosses'}
    || $b->{'xsspread'} <=> $a->{'xsspread'};
  }

sub CompareTeams ($$) {
  my $a = shift;
  my $b = shift;
  my $ac = $a->{'count'};
  my $bc = $b->{'count'};
  return $a->{'ranksum'}/$ac <=> $b->{'ranksum'}/$bc
    || $b->{'wins'}/$bc <=> $a->{'wins'}/$ac
    || $a->{'losses'}/$ac <=> $b->{'losses'}/$bc
    || $b->{'spread'}/$bc <=> $a->{'spread'}/$ac;
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
Use this command to display team standings in a specified round 
or range of rounds (e.g., 4-7).
EOF
  $this->{'names'} = [qw(rts roundteamstandings)];
  $this->{'argtypes'} = [qw(RoundRange Division)];
# print "names=@$namesp argtypes=@$argtypesp\n";

  return $this;
  }

sub new ($) { return TSH::Utility::new(@_); }

sub RankTeam ($$) {
  my $teamp = shift;
  my $rank0 = shift;
  $teamp->{'rank'} = $rank0+1;
  }

sub RenderTeam ($$$$) {
  my $logp = shift;
  my $p = shift;
  my $myconfigp = shift;
  my $output_row = shift;

  my $r0 = $myconfigp->{'r0'};
  my $config = $myconfigp->{'config'};

  if ($myconfigp->{'ratingpagebreak'} 
    && $output_row 
    && ($output_row) % $myconfigp->{'ratingpagebreak'} == 0) { 
    $logp->PageBreak();
    $logp->ColumnTitles( {
      'text' => $myconfigp->{'text_titles'},
      'html' => $myconfigp->{'html_titles'},
      }) if 0;
    }

  my @html_fields;
  my @text_fields;

  for my $field (@{$myconfigp->{'fields'}}) {
    my $fip = $field_info{$field};
    my $render = $fip->{'render'};
    my $html_render = $fip->{'html_render'} || $render;
    my $text_render = $fip->{'text_render'} || $render;
    my $s = &$text_render($p, $myconfigp);
    push(@text_fields, $s) if (defined $s) && length($s);
    $s = &$html_render($p, $myconfigp);
    push(@html_fields, $s) if (defined $s) && length($s);
    }
  $logp->WriteRow(\@text_fields, \@html_fields);
  }

# see RoundRATings::RenderTable()
sub RenderTable ($) {
  my $myconfigp = shift;

  my $config = $myconfigp->{'config'};
  my $dp = $myconfigp->{'dp'};
  my $r0 = $myconfigp->{'r0'};

  my (@fields);
  if ($myconfigp->{'team_standings_fields'}) {
    (@fields) = (@{$myconfigp->{'team_standings_fields'}});
    }
  elsif ($myconfigp->{'has_squads'}) {
    push(@fields, 'rank');
    push(@fields, 'squad_team_wl', 'squad_player_wl') unless $myconfigp->{'no_wl'};
    push(@fields, 'squad_spread') unless $myconfigp->{'no_scores'};
    push(@fields, 'team');
    }
  else {
    push(@fields, 'rank');
    push(@fields, 'wl') unless $myconfigp->{'no_wl'};
    push(@fields, 'spread') unless $myconfigp->{'no_scores'};
    push(@fields, 'mean_wl') unless $myconfigp->{'no_wl'};
    push(@fields, 'mean_spread') unless $myconfigp->{'no_scores'};
    push(@fields, 'wpvso');
    push(@fields, 'team');
    push(@fields, 'mean_rank');
    push(@fields, 'ranks');
    }
  $myconfigp->{'fields'} = \@fields;
 
  my %teams;
# my $rankround0 = $dp->LeastScores()-1; # used to rank based on this round
  $dp->CountTeamRecords($r0, $r0, \%teams);
  if ($myconfigp->{'has_squads'}) {
    TSH::Utility::DoRanked([values %teams], \&CompareSquads, \&SquadKey, \&RankTeam);
    }
  else {
    if (my $quotas = $config->Value('team_quotas')) {
      CalculateQuotaMeans(\%teams, $quotas);
      }
    TSH::Utility::DoRanked([values %teams], \&CompareTeams, \&TeamKey, \&RankTeam);
    }

  my $logp = new TSH::Log($dp->Tournament(), $dp, 'teams', $r0+1);
  my (@classes, @html_titles, @text_titles);

  for my $field (@fields) {
    my $fip = $field_info{$field};
    unless ($fip) {
      warn "Unknown field '$field' in config team_standings_fields, ignoring";
      next;
      }
    push(@classes, $fip->{'class'});
    if ($fip->{'variant_title'} ){
       push(@text_titles, $fip->{'variant_title'}($dp, $myconfigp));
      }
    else
      {
	my $key = $fip->{'html_key'};
	$key = &$key($myconfigp) if ref($key) eq 'CODE';
	push(@html_titles, $config->Terminology($key)) if (defined $key) && length($key);
	$key = $fip->{'text_key'};
	$key = &$key($myconfigp) if ref($key) eq 'CODE';
	push(@text_titles, $config->Terminology($key)) if (defined $key) && length($key);
      }
    }

  $logp->ColumnClasses(\@classes);
  $logp->ColumnTitles({
    'text' => \@text_titles,
    'html' => \@html_titles,
    });
  $myconfigp->{'text_titles'} = \@text_titles;
  $myconfigp->{'html_titles'} = \@html_titles;

  my $output_row = 0;
  for my $teamdata (sort { $a->{'rank'} <=> $b->{'rank'} 
    || $a->{'name'} cmp $b->{'name'} } values %teams) {
    $teamdata->{'xcount'} ||= 0;
    RenderTeam $logp, $teamdata, $myconfigp, $output_row++;
    }
  $logp->Close();
  }

=item $command->Run($tournament, @parsed_args)

Should run the command in the context of the given
tournament with the specified parsed arguments.

=cut

sub Run ($$@) { 
  my $this = shift;
  my $tournament = shift;
  my ($firstr1, $lastr1, $dp) = @_;

  my $config = $tournament->Config();
  my %myconfig;
  my $pairing_system = $config->Value('pairing_system') || '';

  $myconfig{'config'} = $config;
  $myconfig{'dp'} = $dp;
  $myconfig{'has_squads'} = $config->Value('squads');
  $myconfig{'no_scores'} = ($config->Value('scores')||'') =~ /^WLT?$/i;
  $myconfig{'fields'} = $config->Value('team_standings_fields');
  $myconfig{'ratingpagebreak'} = $config->Value('team_standings_page_break');

  if ($pairing_system eq 'none') {
    $myconfig{'no_wl'} = 1;
    $myconfig{'positive_scores'} = 1;
    }

  for my $round ($firstr1..$lastr1) {
    $myconfig{'r0'} = $round - 1;
    RenderTable \%myconfig;
    }
  }

sub SquadKey ($) {
  my $a = shift;
  return join(';', @$a{qw(xstwins xstlosses xspwins xsplosses xsspread)});
  }

sub TeamKey ($) {
  my $a = shift;
  return join(';', @$a{qw(count ranksum wins losses spread)});
  }

=back

=cut

=head1 BUGS

None known

=cut

1;

