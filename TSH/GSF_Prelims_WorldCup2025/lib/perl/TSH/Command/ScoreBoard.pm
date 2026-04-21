#!/usr/bin/perl

# Copyright (C) 2008 John J. Chew, III <jjchew@math.utoronto.ca>
# All Rights Reserved

package TSH::Command::ScoreBoard;

use strict;
use warnings;

use TSH::Log;
use TSH::Utility qw(Debug DebugOn FormatHTMLHalfInteger FormatHTMLSignedInteger Ordinal);

# DebugOn('SP');

our (@ISA) = qw(TSH::Command);

=pod

=head1 NAME

TSH::Command::ScoreBoard - implement the C<tsh> ScoreBoard command

=head1 SYNOPSIS

  my $command = new TSH::Command::ScoreBoard;
  my $argsp = $command->ArgumentTypes();
  my $helptext = $command->Help();
  my (@names) = $command->Names();
  $command->Run($tournament, @parsed_arguments);
  
=head1 ABSTRACT

TSH::Command::ScoreBoard is a subclass of TSH::Command.

=cut

=head1 DESCRIPTION

=over 4

=cut

sub AddTDataPerson ($$);
sub FormatPlayerPhotoName($$;$);
sub HeadShot ($$;$);
sub initialise ($$$$);
sub InTheMoney ($$);
sub new ($);
sub OutOfTheMoney ($$$);
sub RenderBoard ($$);
sub RenderPlayer ($$$$$);
sub RenderPlayerRoundRecord ($$$);
sub RenderTable ($$$);
sub Run ($$@);
sub SetThresholdAttribute($$$$);
sub TagName ($$;$);

=item $command->FormatPlayerPhotoName($logp, $player[, $optionsp]);

Used internally to render a headshot and name for a player:
the current player, an opponent, or maybe a bye.

=cut

sub FormatPlayerPhotoName($$;$) {
  my $this = shift;
  my $p = shift;
  my $optionsp = shift;
  
  if (TSH::Utility::IsASafely($p, 'TSH::Player')) {
    return $this->HeadShot($p,$optionsp->{'size'}) . $this->TagName($p, $optionsp);
    }
  else {
    return '<div class=nohead>$p</div>';
    }
  }

=item $html = $this->HeadShot($player[, $size])

Used internally to generate an IMG tag for a player headshot.

=cut

sub HeadShot ($$;$) {
  my $this = shift;
  my $p = shift;
  my $photo_size = shift || $this->{'photo_size'};
  my $config = $this->Processor()->Tournament()->Config();
  if ($config->Value('player_photos')) {
    my $aspect = $config->Value('player_photo_aspect_ratio') || 1;
    my $s = sprintf(q(<div class=head><img class=head src="%s" alt="[head shot]" height="%d" width="%d">), $p->PhotoURL(), $photo_size, int(0.5+$aspect*$photo_size));
    if ($config->Value('scoreboard_teams')) {
      $s .= q(<span class=team><img src="http://www.worldplayerschampionship.com/images/flags/)
	.lc($p->Team()).sprintf(q(.gif" width=%d alt=""></span>), $photo_size/3);
      }
    $s .= "</div>";
    return $s;
    }
  else {
    return "&nbsp;";
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
Use this command to update a scoreboard suitable for displaying on a
second monitor or web kiosk.
You must specify a division, and may omit (beginning at the end) the remaining
optional arguments: first rank, last rank, pixel width of player photos, 
seconds between refreshes.
EOF
  $this->{'names'} = [qw(sb scoreboard)];
  $this->{'argtypes'} = [qw(Division OptionalInteger OptionalInteger OptionalInteger OptionalInteger)];
# print "names=@$namesp argtypes=@$argtypesp\n";
  $this->{'table_format'} = undef;
  $this->{'c_no_boards'} = undef;
  $this->{'c_has_tables'} = undef;
  $this->{'dp'} = undef;
  $this->{'first_rank'} = undef;
  $this->{'last_rank'} = undef;
  $this->{'photo_size'} = undef;
  $this->{'r0'} = undef;
  $this->{'r1'} = undef;
  $this->{'refresh'} = undef;

  return $this;
  }

sub InTheMoney ($$) {
  my $this = shift;
  my $p = shift;
  my $dp = $p->Division();
  my $r0 = $this->{'r0'};
  my $config = $dp->Tournament()->Config();
  my $crank;
  if ($this->{'is_capped'}) {
    $crank = $p->RoundCappedRank($r0);
    }
  else {
    $crank = $p->RoundRank($r0);
    }
  my $is_in_money = 0;
  if (my $prize_bands = $config->Value('prize_bands')) {
    my $prize_band;
    if (ref($prize_bands) eq 'HASH') { $prize_band = $prize_bands->{$dp->Name()}; }
    elsif (ref($prize_bands) eq 'ARRAY') { $prize_band = $prize_bands; }
    if ($prize_band) {
      if ($crank <= $prize_band->[-1]) {
	$is_in_money = 1;
	}
      }
    }
  return $is_in_money;
  }

sub new ($) { return TSH::Utility::new(@_); }

sub RenderBoard ($$) {
  my $this = shift;
  my $b = shift;
  my $board = '';
  if ($b) {
    if ($this->{'c_has_tables'}) {
      $board = $this->{'dp'}->BoardTable($b) if $this->{'c_has_tables'};
# warn "has tables $b->$board";
      }
    elsif (!$this->{'c_no_boards'}) {
      $board = $b;
      }
    $board = " \@$board" if length($board||'');
    }
  return $board;
  }

=item $command->RenderPlayer($logp, $player, $lastp, $outofthemoney);

Used internally to render a player.

=cut

sub RenderPlayer ($$$$$) {
  my $this = shift;
  my $logp = shift;
  my $p = shift;
  my $lastp = shift;
  my $outofthemoney = shift;
  my $r0 = $this->{'r0'};
  my $r1 = $this->{'r1'};
  my $seed = $this->{'seeds'}[$p->ID()-1];
  my $html = '';
  my $dp = $p->Division();
  my $config = $dp->Tournament()->Config();
  {
    my ($crank, $lrank, $spread);
    if ($this->{'is_capped'}) {
      $crank = $p->RoundCappedRank($r0);
      $lrank = $r0 > 0 ? $p->RoundCappedRank($r0 - 1) : $seed;
      $spread = $p->RoundCappedSpread($r0);
      }
    else {
      $crank = $p->RoundRank($r0);
      $lrank = $r0 > 0 ? $p->RoundRank($r0 - 1) : $seed;
      $spread = $p->RoundSpread($r0);
      }
    my $is_in_money = $this->InTheMoney($p) ? ' money' : '';
    my $is_out_of_money = $outofthemoney ? ' nomoney' : '';
#   warn $p->Name() . " $is_in_money $is_out_of_money";
    my $wins = $p->RoundWins($r0);
    my $losses = $p->RoundLosses($r0);
    my $is_block_leader = '';
    if ($this->{'first_rank'} == 1 && !defined $lastp) {
      $html .= qq(<div class="wlb$is_in_money$is_out_of_money"><div class=w>P<br>R<br>I<br>Z<br>E</div></div>);
      $is_block_leader = 1;
      }
    elsif (!$is_in_money) {
      my $lastw = (defined $lastp) ? $lastp->RoundWins($r0) : -1;
#     my $lastl = $lastp->RoundLosses($r0);
      if ($lastw != $wins 
#       || $lastl != $losses
	|| $this->InTheMoney($lastp)
	) {
	$html .= qq(<div class="wlb$is_in_money$is_out_of_money"><div class=w>).join('<br>', FormatHTMLHalfInteger($wins) =~ /(\d|&frac12;)/g).'</div>'
	# .'<div class=l>'.FormatHTMLHalfInteger($losses).'</div>'
	. '</div>';
	$is_block_leader = 1;
	}
      }
    $is_block_leader = " leader" if $is_block_leader;
    $html .= qq(<div class="sbp$is_in_money$is_out_of_money$is_block_leader")
#     . ' style="max-width:' . int(2.5*$this->{'photo_size'}) . 'px"'
      . '>';
    $html .= '<div class=me>';
    $html .= "<div class=rank>"
      . Ordinal($crank)
      . "</div>";
    $html .=
      "<div class=old>was<br>"
      . Ordinal($lrank)
      ."</div>\n" if defined $p->Score($r0) && defined $lrank;
    $html .=
      "<div class=\"handicap\"><span class=label>HP</span><br><span class=value>"
      . (2*$wins+($p->GetOrSetEtcScalar('handicap')||0))
      ."</span></div>\n" if $this->{'thai_points'};
    my $currency_symbol = $config->Value('currency_symbol') || '$';
    $html .= "<div class=money>$currency_symbol</div>" if $is_in_money;
    $html .= "<div class=wl>"
	. FormatHTMLHalfInteger($wins)
	. "&ndash;"
	. FormatHTMLHalfInteger ($losses) 
	. ' ' 
	. FormatHTMLSignedInteger($spread)
      . "</div>";
  }
  $html .= $this->FormatPlayerPhotoName($p,{'size'=>$this->{'photo_size'},'id'=>1});
  # rating information
  { 
    my $oldr = $p->Rating();
    my $newr = $r0 < 0 ? $oldr : $p->NewRating($r0);
    $newr = $oldr unless defined $newr;
    my $delta = FormatHTMLSignedInteger($newr-$oldr);
    $html .= "<div class=newr>$newr</div>\n";
    if ($oldr) {
      $html .= "<div class=oldr>=$oldr<br>$delta</div>\n";
      }
    else {
      $html .= "<div class=oldr>was<br>unrated</div>\n";
      }
  }
  $html .= "</div>\n"; # me
  $html .= "<div class=opp>\n"; # opp
  { # last game
    my $last = '';
    my $oppid = $p->OpponentID($r0);
    if ($oppid) {
      my $op = $p->Opponent($r0);
      my $os = $op->Score($r0);
      if (defined $os) {
	my $ms = $p->Score($r0);
	my $spread = FormatHTMLSignedInteger($ms - $os);
	$last .= "<div class=gs>$ms&minus;$os=$spread</div>";
	}
      else {
	$last .= "<div class=gsn>no score yet</div>";
	}
      my $first = $p->First($r0);
      $first = $first == 1 ? '1st' : $first == 2 ? '2nd' : '';
      my $board = $this->RenderBoard($p->Board($r0));

# die "no board for $p->{id}" unless defined $board;	
      $last .= "<div class=where>$first$board vs.</div>\n";
      $last .= "<div class=hs>" 
	.$this->FormatPlayerPhotoName($op,{'size'=>int($this->{'photo_size'}/2)}) 
	. "</div>";
      }
    else { # bye
      my $ms = $p->Score($r0);
      $ms = (defined $ms) ? sprintf("%+d", $ms) : '';
      $last .= "<div class=bye>bye $ms</div>";
      }
    if ($last) {
      $html .= "<div class=last><div class=title>Last:</div>$last</div>\n";
      }
  }
  { # next game
    my $next = '';
    my $oppid = $p->OpponentID($r0+1);
    if ($oppid) {
      my $op = $p->Opponent($r0+1);
      my $first = $p->First($r0+1);
      my $repeats = $p->CountRoundRepeats($op, $r0+1);
      my $board = $this->RenderBoard($p->Board($r0+1));
      $first = $first == 1 ? '1st' : $first == 2 ? '2nd' : '';
      if ($repeats > 1) {
	$next .= "<div class=repeats>"
	  .($repeats==2?"repeat":$repeats."peat")
	  ."</div>";
	}
      $next .= "<div class=where>$first$board vs.</div>\n";
      $next .= "<div class=hs>" 
	.$this->FormatPlayerPhotoName($op,{'size'=>int($this->{'photo_size'}/2)}) 
	. "</div>";
      }
    elsif (defined $oppid) {
      $next .= "<div class=bye>bye</div>";
      }
    if ($next) {
      $html .= "<div class=next><div class=title>Next:</div>$next</div>\n";
      }
  }
  { # record
    my $record = '';
    my $nscores = $p->CountScores();
    if ($nscores > 1) {
      my $maxw = 12;
      if ($nscores > $maxw) {
	$maxw = int(($nscores+$maxw-1)/$maxw);
	$maxw = int(($nscores+$maxw-1)/$maxw); # doubled line, sic
	my $r0 = 0;
	$record .= '<div class=rdss>';
	while ($r0 < $nscores) {
	  my $lastr0 = $r0 + $maxw-1;
	  $lastr0 = $nscores-1 if $lastr0 > $nscores-1;
	  $record .= '<div class=rds>';
	  for my $i0 ($r0..$lastr0) {
	    $record .= $this->RenderPlayerRoundRecord($p, $i0);
	    }
	  $record .= '</div>';
	  $r0 = $lastr0 + 1;
	  }
	$record .= '</div>';
	}
      else {
	for my $r0 (0..$nscores-1) {
	  $record .= $this->RenderPlayerRoundRecord($p, $r0);
	  }
	}
      }
    if ($record) {
      $html .= "<div class=record><div class=title>Rec<br>ord</div>$record</div>\n";
      }
  }
  $html .= '</div>'; # opp
  $html .= '</div>'; # sbp
  $logp->Write('', $html);
  return;
  # record of wins and losses
  # record of firsts and seconds
  # player number
  } 

=item $command->RenderPlayerRoundRecord($p);

Used internally to render a player's record for one round.

=cut

sub RenderPlayerRoundRecord ($$$) {
  my $this = shift;
  my $p = shift;
  my $r0 = shift;
  my $record = ''; 

  my $ms = $p->Score($r0);
  $record .= "<div class=rd>";
  if ($p->Opponent($r0)) {
    my $os = $p->OpponentScore($r0);
    if (defined $os) {
      $record .= $ms > $os ? "<div class=win>W</div>"
	: $ms < $os ? "<div class=loss>L</div>"
	: "<div class=tie>T</div>";

      }
    else {
      $record .= "<div class=unknown>?</div>";
      }
    }
  elsif (defined $ms) {
    $record .= $ms > 0 ? "<div class=bye>B</div>"
      : $ms < 0 ? "<div class=forfeit>F</div>"
      : "<div class=missed>&ndash;</div>";
    }
  my $p12 = $p->First($r0);
  if ($p12 && $p12 =~ /^[12]$/) {
    $record .= "<div class=p$p12>$p12</div>";
    }
  else {
    $record .= "<div class=p0>&ndash;</div>";
    }
  $record .= "</div>";
  return $record;
  }

=item $command->RenderTable($logp, \@players);

Used internally to render the table.

=cut

sub RenderTable ($$$) {
  my $this = shift;
  my $logp = shift;
  my $psp = shift;
  $logp->Write('', '<div id=sbs>');
  my $first_out_of_the_money = $this->{'dp'}->FirstOutOfTheMoney($psp, $this->{'r0'});
  for my $i (0..$#$psp) {
    my $p = $psp->[$i];
    my $out_of_the_money = $p->RoundRank($this->{'r0'}) > $first_out_of_the_money;
#   if ($out_of_the_money) { warn "$i is out of the money"; } else { warn "$i is not"; }
    $this->RenderPlayer($logp, $p, $i ? $psp->[$i-1] : undef, $out_of_the_money);
    }
  $logp->Write('', '</div><br clear=all>');
  $logp->Write('', <<'EOF');
<script language="JavaScript" type="text/javascript"><!--
  function fix_sizes () {
  var p = document.getElementById('sbs').firstChild
  var maxh, minh;
  maxh = minh = p.offsetHeight;
  while (p = p.nextSibling) {
//  if (p.className != 'sbp' && p.className != 'sbp money') { continue; }
    if (maxh < p.offsetHeight) { maxh = p.offsetHeight; }
    if (minh > p.offsetHeight) { minh = p.offsetHeight; }
    }
  p = document.getElementById('sbs').firstChild;
  p.style.height = maxh;
  while (p = p.nextSibling) {
//  if (p.className != 'sbp' && p.className != 'sbp money') { continue; }
    p.style.height = maxh;
    }
  }
  setTimeout('fix_sizes()', 1000);
--></script>
EOF
  }

=item $command->Run($tournament, @parsed_args);

Should run the command in the context of the given
tournament with the specified parsed arguments.

=cut

sub Run ($$@) { 
  my $this = shift;
  my $tournament = shift;
  my $dp = $this->{'dp'} = shift;
  my ($rank1, $rank2, $photo_size, $refresh) = @_;
  my $config = $tournament->Config();
  # This should all be in a sub called RunInit();
  $this->{'first_rank'} = ($rank1 || 1);
  $this->{'last_rank'} = ($rank2 || $dp->CountPlayers());
  $this->{'photo_size'} = ($photo_size || 32);
  $this->{'refresh'} = ($refresh || 10);
  $this->{'thai_points'} = $config->Value('thai_points');
  $this->{'table_format'} = {
    'head' => { 
      'attributes' => [ [], [] ],
      'classes' => [ [], [] ],
      'titles' => [ [], [] ],
      },
    'data' => { 
      'attributes' => [ [], [] ],
      'classes' => [ [], [] ],
      },
    };
  $this->{'table_data'} = {
    'attributes' => [ [], [] ],
    'contents' => [ [], [] ],
    };
  my $r1 = $this->{'r1'} = $dp->MostScores();
  my $r0 = $this->{'r0'} = $r1 - 1;
  my $c_spreadentry = $config->Value('entry') eq 'spread';
  my $c_trackfirsts = $config->Value('track_firsts');
  $this->{'has_classes'} = $dp->Classes();
  my $c_no_boards = $this->{'c_no_boards'} = $config->Value('no_boards');
  my $c_has_tables = $this->{'c_has_tables'} = $dp->HasTables();
  my $c_is_capped = $this->{'is_capped'} = $config->HasSpreadCaps();

  my $logp = new TSH::Log($tournament, $dp, 
    'scoreboard-'.$this->{'first_rank'} . '-' . $this->{'last_rank'}, undef,
    {'noconsole' => 1, 'notext' => 1,  'refresh' => $this->{'refresh'},
    'titlename' => 'scoreboard',});
  $logp->Write('', '<tr><td></td></tr></table>');

  if ($c_is_capped) {
    $dp->ComputeCappedRanks($r0);
    $dp->ComputeCappedRanks($r0-1) if $r0 > 0;
    }
  else {
    $dp->ComputeRanks($r0);
    $dp->ComputeRanks($r0-1) if $r0 > 0;
    }
  $dp->ComputeRatings($r0) if $r0 > 0;
  $dp->ComputeSeeds();
  my (@ps) = ($dp->Players());
  TSH::Player::SpliceInactive(@ps, 0, 0);
  if ($c_is_capped) {
    @ps = TSH::Player::SortByCappedStanding($r0, @ps);
    }
  else {
    @ps = TSH::Player::SortByStanding($r0, @ps);
    }
  if ($this->{'last_rank'} && $this->{'last_rank'} < @ps) {
    splice(@ps, $this->{'last_rank'});
    }
  if ($this->{'first_rank'} && $this->{'first_rank'} <= @ps) {
    splice(@ps, 0, $this->{'first_rank'}-1);
    }
  $this->RenderTable($logp, \@ps);
  $logp->Write('', '<table><tr><td></td></tr>');

  $logp->Close();
  return 0;
  }

=item $command->SetThresholdAttribute($subrow, $value, $threshold);

Used internally to set the HTML attribute of the last stored content
according to its value and a threshold.

=cut

sub SetThresholdAttribute($$$$) {
  my $this = shift;
  my $subrow = shift;
  my $value = shift;
  my $threshold = shift;
  return unless $threshold;

  my $attributesp = $this->{'table_data'}{'attributes'}[$subrow];
  my $i = $#{$this->{'table_data'}{'contents'}->[$subrow]};
  $attributesp->[$i] .= ' ' if $attributesp->[$i];
  $attributesp->[$i] .= 'bgcolor="#' . (
    (!$value) ? 'ffffff' :
    $value >= $threshold ? '80ff80' : $value > 0 ? 'c0ffc0' :
    $value <= -$threshold ? 'ff8080' : 'ffc0c0'
    ) . '"';
  }

=item $html = $cmd->TagName($p, [$optionsp])

Used internally to tag a player's given name and surname.

=cut

sub TagName ($$;$) {
  my $this = shift;
  my $p = shift;
  my $optionsp = shift || {};
  my $name = $p->Name();
  my $is_chinese = $p->Team() =~ /^(?:MYS|SGP|TWN)$/ && $name =~ / .* /;
  my $is_thai = $p->{'xthai'};
  unless (defined $is_thai) {
    if ($p->Team() eq 'THA') {
      my ($surname, $given) = $p->Name() =~ /^(.*), (.*)$/;
      if (defined $given) {
        my (@matches) = $p->Division()->Tournament()->FindPlayer(',', $given, undef, 'quiet');
	if (@matches == 1) { $is_thai = 1; }
	else { $is_thai = 0; }
	}
      else { $is_thai = 0; }
      }
    else { $is_thai = 0; }
    $p->{'xthai'} = $is_thai;
    }
  if ($name =~ /^(.*), (.*)$/) {
    my $given = $2;
    my $surname = $1;
    if ($is_thai) {
      $surname = '';
      }
    elsif ($is_chinese) {
      ($surname, $given) = ($given, $surname);
      }
    if ($surname =~ /^(.*)-(.*)$/) {
      my $surname1 = $1;
      my $surname2 = $2;
      if (length($surname2) < length($surname1) + length($given)) {
	$given = "$given $surname1-";
	$surname = "$surname2";
	}
      }
    else {
#      $surname =~ s!Apissoghomian!Apisso-<br>ghomian!;
      }
#   else {
#      $surname =~ s!Apissoghomian!<span class=narrow>$&</span>!;
#     }
    if ($optionsp->{'id'}) {
      my $class = $this->{'has_classes'} ? '/' . $p->Class() : '';
      if (length($surname) > length($given)) {
	$given .= " (#". $p->ID()."$class)";
	}
      else {
	$surname .= " (#". $p->ID()."$class)";
	}
      }
    $name = "<div class=name>"
      . "<span class=given>$given</span>"
      . "<span class=surname>$surname</span>"
      . "</div>";
#   $name = "<div class=name><span class=surname>$surname</span>"
#     . "<span class=given>$given</span></div>";
    }
  else { # school scrabble tagging
    my (@names) = split(/\s+/, $name);
    my $split;
    my $half = length("@names")/2;
    for my $i (0..$#names) {
      if (length("@names[0..$i]") > $half) {
	if (abs(length("@names[0..$i]")-$half) > 
	  abs(length("@names[0..$i-1]")-$half)) {
	  $split = $i;
	  }
	else {
	  $split = $i+1;
	  }
	last;
        }
      }
    if (@names > 1 && $split == 0) { $split = 1; }
    $name = "<div class=name><span class=given>@names[0..$split-1]</span><span class=surname>@names[$split..$#names]</span></div>";
    }
  return $name;
  }

=back

=cut

=head2 BUGS

None known.

=cut

# sherrie's imac: 1920 x 1200

1;
