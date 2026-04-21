#!/usr/bin/perl

# Copyright (C) 2007-2008 John J. Chew, III <jjchew@math.utoronto.ca>
# All Rights Reserved

package TSH::Command::RoundRATings;

use strict;
use warnings;

use TSH::Log;
use TSH::Utility qw(Debug DebugOn FormatHTMLHalfInteger FormatHTMLInteger FormatHTMLSignedInteger);

# DebugOn('SP');

our (@ISA) = qw(TSH::Command);

=pod

=head1 NAME

TSH::Command::RoundRATings - implement the C<tsh> RoundRATings command

=head1 SYNOPSIS

  my $command = new TSH::Command::RoundRATings;
  my $argsp = $command->ArgumentTypes();
  my $helptext = $command->Help();
  my (@names) = $command->Names();
  $command->Run($tournament, @parsed_arguments);
  
=head1 ABSTRACT

TSH::Command::RoundRATings is a subclass of TSH::Command.

=cut

=head1 DESCRIPTION

=over 4

=cut

sub initialise ($@);
sub new ($);
sub RenderAll ($$$$);
sub RenderPlayer ($$$;$);
sub RenderTable ($$$$;$);
sub Run ($$@);
sub SetupOptions ($$$);

my @pairing_bars;

my (%field_info) = (
  # class: CSS class(es)
  # text_key, html_key: i18n terminology keys
  # render: combined renderer for HTML or text
  # html_render: sub to render for HTMl
  # text_render: sub to render for text
  'class' => { 'class' => 'class', 'text_key' => 'Cl', 'html_key' => 'Class',
    'render' => sub {
      my $p = shift @_;
      my $myconfigp = shift @_;
      return $p->Class() || '-';
      } },
  'drat' => { 'class' => 'rating difr', 'text_key' => sub { $_[0]{'difrt'}}, 'html_key' => sub { $_[0]{'difrh'}},
    'html_render' => sub {
      my $p = shift @_;
      my $myconfigp = shift @_;
      my $r0 = $myconfigp->{'r0'};
      my $rating = $p->Rating();
      my $newr = $r0 >= 0 ? $p->NewRating($r0) : $rating;
      return $rating ? $p->Division()->RatingSystem()->RenderRatingDifference($newr, $rating, {'style' => 'html'}) : '&nbsp;';
      },
    'text_render' => sub {
      my $p = shift @_;
      my $myconfigp = shift @_;
      my $r0 = $myconfigp->{'r0'};
      my $rating = $p->Rating();
      my $newr = $r0 >= 0 ? $p->NewRating($r0) : $rating;
      return $rating ? $p->Division()->RatingSystem()->RenderRatingDifference($newr, $rating, {'style' => 'text'}) : ' ';
      } },
  'mood' => { 'class' => 'mood', 'text_key' => 'Mood', 'html_key' => 'Mood',
    'render' => sub {
      my $p = shift @_;
      my $myconfigp = shift @_;
      my $r0 = $myconfigp->{'r0'};
      my $mood = $p->RoundMood($r0);
      return $mood;
      },
    },
  'name' => { 'class' => 'name', 'text_key' => 'Player', 'html_key' => 'Player',
    'html_render' => sub {
      my $p = shift @_;
      my $myconfigp = shift @_;
      my $config = $myconfigp->{'config'};
      my $q_localise_names = $config->Value('localise_names');
      return $config->Value('standings_hotlink') 
         ? "<a href=\"" . $p->Division()->Name()
	     . ( sprintf (($config->Value('standings_hotlink_target') 
		       || "-scorecard.html#%d"),  $p->ID() ) )
             . "\">" . $p->TaggedHTMLName({'print'=>1, 'localise'=>$q_localise_names}) . "</a>"
           :  $p->TaggedHTMLName({'print'=>1, 'localise'=>$q_localise_names});
      },
    'text_render' => sub {
      my $p = shift @_;
      my $myconfigp = shift @_;
      my $q_localise_names = $myconfigp->{'config'}->Value('localise_names');
      return $p->TaggedName({'localise'=>$q_localise_names});
      } },
  'last' => { 'class' => 'last', 'text_key' => 'Last_G', 'html_key' => 'Last_Game',
    'render' => sub {
      my $p = shift @_;
      my $myconfigp = shift @_;
      my $config = $myconfigp->{'config'};
      my $r0 = $myconfigp->{'r0'};
      my $s = '';
      my $opp = $p->Opponent($r0);
      if ($opp) {
	my $oname = $myconfigp->{'showlastplayername'}
	  ? $opp->TaggedName() : $opp->FullID();
	my $ms = $p->Score($r0);
	if (defined $ms) {
	  my $os = $p->OpponentScore($r0);
	  $os = 0 unless defined $os; # possible if pairing data bad
	  my $p12 = $p->First($r0);
	  $s = 
	    ($myconfigp->{'trackfirsts'} ? substr('B12??', $p12,1) : '')
	    .($myconfigp->{'spreadentry'} 
	      ? '' : ($ms > $os ? 'W' : $ms < $os ? 'L' : 'T'));
	  $s .= ':' if $s;
	  $s .=($myconfigp->{'spreadentry'} 
	    ? sprintf("%+d:", $ms-$os) : "$ms-$os:") unless $myconfigp->{'no_scores'};
	  $s .= "$oname";
	  }
	else {
	  $s = $config->Terminology('pending') . ":$oname";
	  }
	}
      else {
	if (defined $p->OpponentID($r0)) {
	  $s = $config->Terminology('bye');
	  }
	else {
	  $s = $config->Terminology('unpaired');
	  }
	}
      return $s;
      } },
  'next' => { 'class' => 'next', 'text_key' => '', 'html_key' => sub { $_[1]->{'dp'}->LastPairedRound0() > $_[1]->{'r0'} ? 'Next_Game' : undef},
    'html_render' => sub {
      my $p = shift @_;
      my $myconfigp = shift @_;
      my $config = $myconfigp->{'config'};
      my $r0 = $myconfigp->{'r0'};
      if (my $max_rounds = $config->Value('max_rounds')) {
	if ($r0+1 >= $max_rounds) {
	  return undef;
	  }
	}
      my $oid = $p->Opponent($r0+1);
      if (!defined $oid) { return undef; }
      return $p->Division()->FormatPairing($r0+1, $p->ID(), {'style' => $config->Value('next_round_style') || 'nextrat'});
      # TODO: dead code if the preceding line is acceptable in testing
      my $opp = $p->Opponent($r0+1) || return $config->Terminology('bye');
      my $s = $opp->FullID();
      if ($config->Value('seats')) {
	$s .= '@' . $p->Seat($r0+1);
	}
      return $s;
      },
    'text_render' => sub {
      return undef;
      } },
  'nrat' => { 'class' => 'rating newr', 'text_key' => sub { $_[0]{'newrt'}}, 'html_key' => sub { $_[0]{'newrh'} }, 
    'html_render' => sub {
      my $p = shift @_;
      my $myconfigp = shift @_;
      my $r0 = $myconfigp->{'r0'};
      my (%options) = ('style' => 'html');
      $options{'alpha'} = $myconfigp->{'alpha'} if $myconfigp->{'alpha'};
      return $p->Division()->RatingSystem()->RenderRating($r0 >= 0 ? $p->NewRating($r0) : $p->Rating(), \%options);
      },
    'text_render' => sub {
      my $p = shift @_;
      my $myconfigp = shift @_;
      my $r0 = $myconfigp->{'r0'};
      my (%options) = ('style' => 'text');
      $options{'alpha'} = $myconfigp->{'alpha'} if $myconfigp->{'alpha'};
      return $p->Division()->RatingSystem()->RenderRating($r0 >= 0 ? $p->NewRating($r0) : $p->Rating(), \%options);
      },
      },
  'orat' => { 'class' => 'rating oldr', 'text_key' => sub { $_[0]{'oldrt'}}, 'html_key' => sub { $_[0]{'oldrh'}}, 
    'html_render' => sub {
      my $p = shift @_;
      my $myconfigp = shift @_;
      my $r0 = $myconfigp->{'r0'};
      my (%options) = ('style' => 'html');
      $options{'alpha'} = $myconfigp->{'alpha'} if $myconfigp->{'alpha'};
      return $p->Division()->RatingSystem()->RenderRating($p->Rating(), \%options);
      },
    'text_render' => sub {
      my $p = shift @_;
      my $myconfigp = shift @_;
      my $r0 = $myconfigp->{'r0'};
      my (%options) = ('style' => 'text');
      $options{'alpha'} = $myconfigp->{'alpha'} if $myconfigp->{'alpha'};
      return $p->Division()->RatingSystem()->RenderRating($p->Rating(), \%options);
      },
      },
  'pairing_bars' => { 'class' => 'rank',
    'variant_title' => sub {
        my $dp = shift;
	my $myconfigp = shift;
	return ${$dp}{tournament}->{config}->Terminology('Pairs', $myconfigp->{'pairings_round'}+1)
      },
    'html_render' => sub {},
    'text_render' => sub {
      my $p = shift @_;
      my $myconfigp = shift @_;
      my $r0 = $myconfigp->{'r0'};
      my $pairings_round = $myconfigp->{'pairings_round'};
	my $retval = '';
	foreach my $pairing_bar (@pairing_bars)
	  {
	    Debug 'PB', "Stripping from a pairing bar:  $pairing_bar\n";
	    $retval .= (substr $pairing_bar, 0, 1, "");
	  }
      $retval =~ s/ +$//;
      # First, draw an hbar in any empty spaces to the left of an 'open' or 'close'
      # corner.
      if ( $retval =~ /[\+\=]/ ) {
        my $corner = $-[0];   # @- LAST_MATCH_START
        my $subst = substr $retval, 0, $corner; 
        $subst =~ s/ /$myconfigp->{'config'}->GraphicCharacterHBar()/ge;
        substr $retval, 0, $corner, $subst;
      }
      $retval =~ s/\+/$myconfigp->{'config'}->GraphicCharacterUpperRightCorner()/ge;
      $retval =~ s/\=/$myconfigp->{'config'}->GraphicCharacterLowerRightCorner()/ge;
      $retval =~ s/\|/$myconfigp->{'config'}->GraphicCharacterVBar()/ge;

      my $maxp_opp = $p->{pairings}[ $pairings_round ];
#     my $repeats = $maxp_opp ? $p->Repeats( $maxp_opp ) - 1 : 0;
      #
#     $p->Byes( $pairings_round );
#     # GVC: Somehow the byes value isn't updated at startup unless we add
#     # the above dummy call
#     # JJC: I've added a call to CountByes below, which needs to be called
#     # whenever current bye counts are needed
      my $repeats = defined $maxp_opp 
        ? ( $maxp_opp 
	  ? ( $p->Repeats( $maxp_opp ) - 1 ) 
	  : $p->Byes( $pairings_round ) ) 
        : 0 ;

      return $retval . ( ($repeats == 0) ? "" : $repeats) 
	             . ( "*" x $p->CountBackToBack($pairings_round) ) ;
      } },
  'prat' => { 'class' => 'rating perf', 'text_key' => 'PerfRat', 'html_key' => 'Performance_Rating',
    'render' => sub {
      my $p = shift @_;
      my $myconfigp = shift @_;
      my $r0 = $myconfigp->{'r0'};
      my $perfr = $p->GetOrSetEtcVectorMember('perfr', $r0) // 0;
      return $p->Division()->RatingSystem()->RenderPerformanceRating($perfr, {});
      } },
  'rank' => { 'class' => 'rank', 'text_key' => 'Rnk', 'html_key' => 'Rank', 
    'render' => sub {
      my $p = shift @_;
      my $myconfigp = shift @_;
      my $r0 = $myconfigp->{'r0'};
      my $rank = $myconfigp->{'is_capped'}
        ? $p->RoundCappedRank($r0) : $p->RoundRank($r0);
      $rank += $myconfigp->{'rankoffset'};
      return $rank;
      } },
  'scoresum' => { 'class' => 'sum', 'text_key' => 'ScrSum', 'html_key' => 'ScoreSum', 
    'render' => sub {
      my $p = shift @_;
      my $myconfigp = shift @_;
      my $r0 = $myconfigp->{'r0'};
      return $p->RoundSum($r0);
      } },
  'spread' => { 'class' => 'spread', 'text_key' => 'Sprd', 'html_key' => 'Spread', 
    'html_render' => sub {
      my $p = shift @_;
      my $myconfigp = shift @_;
      my $r0 = $myconfigp->{'r0'};
      my $spread = $myconfigp->{'is_capped'} ? $p->RoundCappedSpread($r0) :
        $p->RoundSpread($r0);
      return $myconfigp->{'positive_scores'} ? FormatHTMLInteger($spread)
        : FormatHTMLSignedInteger($spread);
      }, 
    'text_render' => sub {
      my $p = shift @_;
      my $myconfigp = shift @_;
      my $r0 = $myconfigp->{'r0'};
      my $spread = sprintf(
	$myconfigp->{'positive_scores'} ? '%d' : "%+d", $myconfigp->{'is_capped'}
	? $p->RoundCappedSpread($r0) : $p->RoundSpread($r0));
      return $spread;
      } },
  'tspread' => { 'class' => 'spread', 'text_key' => 'Sprd', 'html_key' => 'Spread', 
    'html_render' => sub {
      my $p = shift @_;
      my $myconfigp = shift @_;
      my $r0 = $myconfigp->{'r0'};
      my $spread = $p->{'tspread'};
      return FormatHTMLSignedInteger($spread);
      },
    'text_render' => sub {
      my $p = shift @_;
      my $myconfigp = shift @_;
      my $r0 = $myconfigp->{'r0'};
      my $spread = $p->{'tspread'};
      return sprintf("%+d",$spread);
      } },
  'team' => { 'class' => 'team', 'text_key' => 'Team', 'html_key' => 'Team',
    'render' => sub {
      my $p = shift @_;
      my $myconfigp = shift @_;
      return $p->Team() || '-';
      } },
  'thaipoints' => { 'class' => 'thai', 'text_key' => 'thaipts', 'html_key' => 'thaipoints', 
    'render' => sub {
      my $p = shift @_;
      my $myconfigp = shift @_;
      my $r0 = $myconfigp->{'r0'};
      return 2*$p->RoundWins($r0)+($p->GetOrSetEtcScalar('handicap')||0);
      } },
  'twl' => { 'class' => 'wl', 'text_key' => 'W_L', 'html_key' => 'Won_Lost', 
    'html_render' => sub {
      my $p = shift @_;
      my $myconfigp = shift @_;
      my $r0 = $myconfigp->{'r0'};
      my $w = $p->{'twins'};
      my $l = $p->{'tlosses'};
      return FormatHTMLHalfInteger($w) . '&ndash;' . FormatHTMLHalfInteger($l);
      },
    'text_render' => sub {
      my $p = shift @_;
      my $myconfigp = shift @_;
      my $r0 = $myconfigp->{'r0'};
      my $w = $p->{'twins'};
      my $l = $p->{'tlosses'};
      return sprintf("%.1f-%.1f", $w, $l);
      } },
  'wl' => { 'class' => 'wl', 'text_key' => 'W_L', 'html_key' => 'Won_Lost', 
    'html_render' => sub {
      my $p = shift @_;
      my $myconfigp = shift @_;
      my $r0 = $myconfigp->{'r0'};
      my $w = $p->RoundWins($r0);
      my $l = $p->RoundLosses($r0);
      return FormatHTMLHalfInteger($w) . '&ndash;' . FormatHTMLHalfInteger($l);
      },
    'text_render' => sub {
      my $p = shift @_;
      my $myconfigp = shift @_;
      my $r0 = $myconfigp->{'r0'};
      my $w = $p->RoundWins($r0);
      my $l = $p->RoundLosses($r0);
      return sprintf("%.1f-%.1f", $w, $l);
      } },
  );

=item $parserp->initialise()

Used internally to (re)initialise the object.

=cut

sub initialise ($@) {
  my $this = shift;

  $this->SUPER::initialise(@_);
  $this->{'help'} = <<'EOF';
Use this command to display ratings estimates based on standings
in a given round or rounds within a division.  If you specify
just one round, the results will be displayed on the screen.
If you specify a range of rounds (e.g., 4-7), the results will
not be shown on your screen but report files will be updated.
EOF
  $this->{'names'} = [qw(rrat roundratings)];
  $this->{'argtypes'} = [qw(RoundRange Division OptionalRound)];

  return $this;
  }

sub new ($) { return TSH::Utility::new(@_); }

sub RenderAll ($$$$) {
  my $dp = shift;
  my $firstr1 = shift;
  my $lastr1 = shift;
  my $optionsp = shift;
  my $lastr0 = $lastr1 - 1;
  my $tournament = $dp->Tournament();
  $dp->CountPlayers() or return 0;
  $dp->CheckRoundHasResults($lastr0) or return 0;

  for my $r1 ($firstr1..$lastr1-1) {
    my $r0 = $r1 - 1;
    $tournament->TellUser('irratok', $r1);
#   warn $r0;
    $dp->ComputeRatings($r0) unless $optionsp->{'no_ratings'};
    $dp->ComputePerformanceRatings($r0) if $optionsp->{'show_perfrat'};
    RenderTable $dp, $r0, $optionsp, 1;
    }
  $dp->ComputeRatings($lastr0, $optionsp->{'noconsole'}) if $lastr0 >= 0;
  $dp->ComputePerformanceRatings($lastr0) if $optionsp->{'show_perfrat'};

  RenderTable $dp, $lastr0, $optionsp, $optionsp->{'noconsole'};
  }

sub RenderPairingBars ($$) {
  my $players_ptr = shift;
  my $pairings_round = shift;

  my @players = map { ${$_}{name} ne "SHOW, NO" ? $_ : () } @{$players_ptr};
     @players = map { ${$_}{name} ne "SHOW, NOB" ? $_ : () } @players;
     @players = map { ${_}->Active() ? $_ : () } @players;

  my $current_rank0 = 0;  # 0-based rank
  @pairing_bars = ();
  foreach my $current_rank0 (0..$#players)
    {
      my $player = $players[$current_rank0];
      next unless ${$player}{pairings}[ $pairings_round ];
      my $pairing_bar = " " x $current_rank0 . "+";
      my $found_me = 0;
      my $bar_closed = 0;
      Debug 'PB', "Building a bar for $player->{id} Rank $current_rank0 Opp ${$player}{pairings}[ $pairings_round ]\n";
      foreach my $opp (@players) {
	next unless ($found_me || $opp->{id} == $player->{id});
	$found_me = 1;
	if (${$opp}{id} == ${$player}{id}) {
	  Debug 'PB', "Found me\n";
	  next;
	}
	if (${$opp}{id} != ${$player}{pairings}[ $pairings_round ]) {
	  Debug 'PB', "Adding a bar for opp  ${$opp}{id}\n";
	  $pairing_bar .= "|";
	  next;
	}
        Debug 'PB', "Closing the bar\n";
	$pairing_bar .= "=" . (" " x scalar @players);
	$bar_closed = 1;
	last;
      }
      if ($bar_closed) {
	# If the bar wasn't closed, then we've been considering a player who is
	# matched with a higher rank, so has already been done.  No need to push a bar
	# this time
	Debug 'PB', $pairing_bar . "\n";
	push @pairing_bars, $pairing_bar;
      }	
    }

    foreach my $bar_index (0..$#pairing_bars) {
      my $bar_start = index $pairing_bars[$bar_index], '+';
      my $bar_end   = index $pairing_bars[$bar_index], '=', $bar_start + 1;
      # Now see if we can fit this into one of the lower-numbered bars
      foreach my $inner_bar_index (0..$bar_index-1) {
	if ( substr( $pairing_bars[$inner_bar_index], $bar_start, $bar_end-$bar_start+1 )
	     eq " " x ($bar_end-$bar_start+1) ) {
	  # Is blank, splice in
	  substr( $pairing_bars[$inner_bar_index], 
		  $bar_start, 
		  $bar_end-$bar_start+1,
		  substr ($pairing_bars[$bar_index], $bar_start, $bar_end-$bar_start+1 )  );
	  Debug 'PB', "Compacted bar:\n" . $pairing_bars[$inner_bar_index] . "\n";
	  $pairing_bars[$bar_index] = "x" x (scalar @players + 1);
	  last;
	}
      }
    }
    # Remove unneeded bars
    @pairing_bars = grep /\+/, @pairing_bars;
    Debug 'PB', ((join "\n", @pairing_bars) . "\n");
  }

=item RenderPlayer($logp, $pp, \%myconfig);

Render a row of a ratings table.

=cut

sub RenderPlayer ($$$;$) {
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

  my $bracketseed_round = (($config->{'pairing_system'} || '') eq 'bracket'
    and ($config->Value('bracket_noncon_pairings') || '') eq 'nasc'
    ) ? 21 : -1;

  my @html_fields;
  my @text_fields;

  for my $field (@{$myconfigp->{'fields'}}) {
    my $f1 = $field;
    if ($bracketseed_round >= 0 && $p->GetOrSetEtcVectorMember('bracketseed', $bracketseed_round)) {
      $f1 =~ s/^(?:wl|spread)$/t$&/;
      }
    my $fip = $field_info{$f1};
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

=item RenderTable($dp, $r0, $optionsp, $noconsole, $pairings_round)

Render the rows of the ratings table. This code is independent of
rating system.

=cut

# try to keep in synch with, and eventually merge with TeamStandings::RenderTable
sub RenderTable ($$$$;$) {
  my $dp = shift;
  my $r0 = shift;
  my $optionsp = shift;
  my $noconsole = shift;
  my $pairings_round = shift;
  my $tournament = $dp->Tournament();
  my $config = $tournament->Config();
  if ($optionsp->{'no_ratings'}) {
    $optionsp->{'oldrh'} = $optionsp->{'newrh'} = $optionsp->{'difrh'} = undef;
    }
  my (%myconfig) = (%$optionsp);
  $myconfig{'config'} = $config;
  $myconfig{'dp'} = $dp;
  $myconfig{'has_classes'} = $dp->Classes() || defined $dp->Player(1)->Class();
  $myconfig{'has_sum'} = $config->Value('sum_before_spread');
  $myconfig{'has_moods'} = $config->Value('player_moods');
  $myconfig{'is_capped'} = $config->HasSpreadCaps();
  $myconfig{'series'} = $config->Series();
  $myconfig{'no_scores'} = ($config->Value('scores')||'') =~ /^WLT?$/i;
  $myconfig{'noshowlast'} = $config->Value('no_show_last') || $r0 < 0;
  $myconfig{'show_inactive'} = $config->Value('show_inactive');
  $myconfig{'show_perfrat'} = $optionsp->{'show_perfrat'};
  $myconfig{'pairing_bars'} = $config->Value('pairing_bars');
  $dp->CountByes() if $myconfig{pairing_bars}; 
  $myconfig{'pairingsystem'} = $config->Value('pairing_system') || 'none';
  $myconfig{'pairings_round'} = ($pairings_round || ${$dp}{maxp}+1);
  $myconfig{'pairings_round'}--;
  $myconfig{'r0'} = $r0;
  $myconfig{'rankoffset'} = $config->Value('rank_offset') || 0;
  $myconfig{'ratingpagebreak'} = $config->Value('rating_page_break');
  $myconfig{'showlastplayername'} = $config->Value('show_last_player_name');
  $myconfig{'spreadentry'} = $config->Value('entry') eq 'spread';
  $myconfig{'thaipoints'} = $config->Value('thai_points');
  $myconfig{'trackfirsts'} = $config->Value('track_firsts');
  $optionsp->{'order'} ||= 'rating';
  $optionsp->{'refresh'} = $config->Value('standings_refresh');
  # 'refresh' has to go here because sometimes RenderTable is invoked 
  # directly so Run/SetupOptions doesn't happen

  $myconfig{'fields'} = $config->Value('rating_fields') || do {
    my (@fields) = qw(rank);
    push(@fields, 'wl') unless $myconfig{'no_wl'};
    push(@fields, 'scoresum') if $myconfig{'has_sum'};
    push(@fields, 'spread') unless $myconfig{'no_scores'};
    push(@fields, 'thaipoints') if $myconfig{'thaipoints'};
    push(@fields, 'orat') if $myconfig{'oldrh'};
    push(@fields, 'prat') if $myconfig{'show_perfrat'};
    push(@fields, 'nrat') if $myconfig{'newrh'};
    push(@fields, 'drat') if $myconfig{'difrh'};
    push(@fields, 'class') if $myconfig{'has_classes'};
    push(@fields, 'name');
    push(@fields, 'mood') if $myconfig{'has_moods'};
    push(@fields, 'last') unless $myconfig{'noshowlast'};
    push(@fields, 'next') if $dp->LastPairedRound0() > $r0;
    push(@fields, 'pairing_bars') if $myconfig{'pairing_bars'} && $dp->LastPairedRound0() > $r0;
    \@fields;
    };

  if ($config->Value('alpha_rating_file') and (defined $config->Value('alpha_rating_minimum') and (defined $config->Value('alpha_rating_maximum')))) {
    my $fn = File::Spec->catfile($config->MakeLibPath('terms'), $config->Value('alpha_rating_file'));
    if (my $fh = TSH::Utility::OpenFile('<', $fn)) {
      local($/) = undef;
      $myconfig{'alpha'}{'values'} = [split(/[\012\015]+/, <$fh>)];
      close $fh;
      $myconfig{'alpha'}{'max'} = $config->Value('alpha_rating_maximum');
      $myconfig{'alpha'}{'min'} = $config->Value('alpha_rating_minimum');
      }
    else {
      $tournament->TellUser('ealrat', $fn, $!);
      }
    }

  my $logp = new TSH::Log($tournament, $dp, 
    ($optionsp->{'filename'} || 'ratings'),
    $r0+1,
    {
      'noconsole' => $noconsole,
      %$optionsp,
    },
    );
  my (@classes);
  my @html_titles;
  my @text_titles;
  for my $field (@{$myconfig{'fields'}}) {
    my $fip = $field_info{$field};
    unless ($fip) {
      warn "Unknown field '$field' in config rating_fields, ignoring";
      next;
      }
    push(@classes, $fip->{'class'});
    if ($fip->{'variant_title'} ){
       push(@text_titles, $fip->{'variant_title'}($dp, \%myconfig));
      }
    else
      {
	my $key = $fip->{'html_key'};
	$key = &$key($optionsp, \%myconfig) if ref($key) eq 'CODE';
	push(@html_titles, $config->Terminology($key)) if (defined $key) && length($key);
	$key = $fip->{'text_key'};
	$key = &$key($optionsp, \%myconfig) if ref($key) eq 'CODE';
	push(@text_titles, $config->Terminology($key)) if (defined $key) && length($key);
      }
    }
  $logp->ColumnClasses(\@classes);
  $logp->ColumnTitles({
    'text' => \@text_titles,
    'html' => \@html_titles,
    });
  $myconfig{'text_titles'} = \@text_titles;
  $myconfig{'html_titles'} = \@html_titles;
  my @player_groups;
  if ($myconfig{'has_classes'} && $optionsp->{'byclass'}) {
    my %byclass;
    for my $p ($dp->Players()) {
      my $class = $p->Class();
      $class = 'none' unless defined $class;
      push(@{$byclass{$class}}, $p);
      }
    for my $class (sort keys %byclass) {
      push(@player_groups, $byclass{$class});
      }
    }
  else {
    $player_groups[0] = [$dp->Players()];
    }
  {
    my $output_row = 0;
    for my $i (0..$#player_groups) {
      my $psp = $player_groups[$i];
      if ($i > 0) {
	my (@blank) = ('') x @text_titles;
	$logp->WriteRow(\@blank, \@blank);
	}
      my @ps;
      if ($myconfig{show_perfrat}) {
	@ps = sort {
	  $b->GetOrSetEtcVectorMember('perfr', $r0)
	    <=>
	    $a->GetOrSetEtcVectorMember('perfr', $r0)
	  or $a->Rating() <=> $b->Rating()
	  or $a->ID() <=> $b->ID()
	  } @$psp;
	}
      elsif ($myconfig{'is_capped'}) {
	$dp->ComputeCappedRanks($r0, {'show_inactive'=>$myconfig{'show_inactive'}});
	if ($optionsp->{'order'} eq 'handicap') {
	  @ps = TSH::Player::SortByHandicap($r0, @$psp);
	  }
	else {
	  @ps = TSH::Player::SortByCappedStanding($r0, @$psp);
	  }
	}
      else {
	$dp->ComputeRanks($r0, {'show_inactive'=>$myconfig{'show_inactive'}});
	if ($myconfig{'pairingsystem'} eq 'bracket') {
	  @ps = TSH::Player::SortByBracket($r0, @$psp);
	  }
	elsif ($optionsp->{'order'} eq 'handicap') {
	  @ps = TSH::Player::SortByHandicap($r0, @$psp);
	  }
	else {
	  @ps = TSH::Player::SortByStanding($r0, @$psp);
	  }
	}
      $myconfig{'pairing_bars'} && RenderPairingBars (\@ps, $myconfig{'pairings_round'});
      $dp->ComputeMoods($r0) if $myconfig{'has_moods'};
      for my $p (@ps) {
	next unless $p->Active() || $myconfig{'show_inactive'};
	RenderPlayer $logp, $p, \%myconfig, $output_row++;
	}
      }
    }
  my $origfn = $logp->Filename();
  $logp->Close();

  my $copyfn = $origfn;
  $copyfn =~ s/-\d+\././;
  TSH::Utility::UpdateFile(
    $config->MakeHTMLPath($origfn), $config->MakeHTMLPath($copyfn));
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
  my $optionsp = SetupOptions($config, $dp, $this->{'noconsole'});

  RenderAll($dp, $firstr1, $lastr1, $optionsp);
  return 0;
  }

sub SetupOptions ($$$) {
  my $config = shift;
  my $dp = shift;
  my $noconsole = shift;

  my (%options_by_rating_system) = (
    'nsa' => {
      'titlename' => 'Ratings',
      'oldrh'=>'Old_Rating',
      'oldrt'=>'Old_R',
      'newrh'=>'New_Rating',
      'newrt'=>'New_R',
      'difrh'=>'Rating_Change',
      'difrt'=>'Rating_Ch',
      },
    'none' => {
      'titlename' => 'Rankings',
      },
    );
  
  my (%options) = %{$options_by_rating_system{lc $dp->RatingSystemName()}
    || $options_by_rating_system{'nsa'}};

  if (($config->Value('pairing_system')||'') eq 'none') {
#   $options{'no_ratings'} = 1;
    $options{'no_wl'} = 1;
    $options{'noshowlast'} = 1;
    $options{'positive_scores'} = 1;
    }
  $options{'noconsole'} = $noconsole;

  return \%options;
  }

=back

=cut

1;
