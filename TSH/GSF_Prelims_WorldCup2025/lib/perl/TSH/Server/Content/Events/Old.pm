#!/usr/bin/perl

# Copyright (C) 2010 John J. Chew, III <jjchew@math.utoronto.ca>
# All Rights Reserved

package TSH::Server::Content::Events::Old;

use strict;
use warnings;

use HTTP::Message qw(EncodeEntities);
use TSH::Server qw(HTMLFooter HTMLHeader);
use CGI qw(:standard);
# use UNIVERSAL qw(isa);

our (@ISA) = qw(TSH::Server::Content);

# This node has no children.
# our $ContentDirectoryPattern = qr[old|new];

=pod

=head1 NAME

TSH::Server::Content::Events::Old - render TSH web content for the Old Events section 

=head1 SYNOPSIS

  my $renderer = new TSH::Server::Content($server, $request, '/events/old/blah');
  my $message = $renderer->Render();
  
=head1 ABSTRACT

This class renders web content for the Old Events section of the TSH web GUI.

=head1 DESCRIPTION

=over 4

=cut

sub AJAXError ($) {
  my $message = shift;
  $message =~ s/[\\"]/\$&/g;
  $message = qq(gAJAXError = "$message");
  return new HTTP::Message(
    'status-code' => 200,
    'body' => $message,
    );
  }

sub GetQueryPlayer ($$) {
  my $this = shift;
  my $arghp = shift;
  my $user_tourney = $this->{'user_tourney'};
  my $dp = $user_tourney->GetDivisionByName($arghp->{'d'}||'');
  return AJAXError("Player belongs to unknown division, please start over.") unless $dp;
  my $dname = $dp->Name();
  my $pn = $arghp->{'p'};
  return AJAXError("Player ID must be numeric, please start over.") if $pn =~ /\D/;
  my $p = $dp->Player($pn);
  return AJAXError("No such player in division, please start over.") unless $p;
  return $p;
  }

sub QueryJSON ($$) {
  my $this = shift;
  my $arghp = shift;
  return HTTP::Server::StaticContent($this->{'user_tourney'}->Config()->MakeHTMLPath('tourney'), 'js');
  }

sub QueryPlayer ($$) {
  my $this = shift;
  my $arghp = shift;
  my $user_tourney = $this->{'user_tourney'};
  my $dp = $user_tourney->GetDivisionByName($arghp->{'d'}||'')
    || ($user_tourney->Divisions())[0];
  my $dname = $dp->Name();
  my $pn = $arghp->{'p'} || 1;
  $pn = 1 if $pn =~ /\D/;
  my $pmax = $dp->CountPlayers();
  $pn = $pmax if $pn > $pmax;
  return $this->RenderJSONResponseHTML('', qq[ViewPlayer('$dname',$pn);]);
  }

sub QuerySet12 ($$) {
  my $this = shift;
  my $arghp = shift;
  my $user_tourney = $this->{'user_tourney'};
  my $dp = $user_tourney->GetDivisionByName($arghp->{'d'}||'');
  my $p = $this->GetQueryPlayer($arghp);
  return $p if UNIVERSAL::isa( $p, 'HTTP::Message');
  my $r = $arghp->{'r'};
  return AJAXError("Bad round number '$r'.") if $r =~ /\D/ || $r == 0;
  my $r0 = $r - 1;
  my $opp = $p->Opponent($r0);
  return AJAXError("Player does not have an opponent in round $r.") unless $opp;
  my $v = HTTP::Message::DecodeURL($arghp->{'v'}); $v = 'x' unless defined $v;
  $v =~ s/\s//g;
  return AJAXError("Illegal characters in 1st/2nd ($v), please start over and enter just 1 or 2.") if $v !~ /^[12]$/;
  $p->First($r0, $v); $opp->First($r0, 3-$v);
  $dp->Dirty(1); $dp->Synch(); $dp->Write(); $user_tourney->SaveJSON();
  warn $this->ClientAddress() . ": ".$p->FullID().".p12[$r]:=".$p->First($r0)."\n";
  return $this->ResponseOK();
  }

sub QuerySetName ($$) {
  my $this = shift;
  my $arghp = shift;
  my $user_tourney = $this->{'user_tourney'};
  my $dp = $user_tourney->GetDivisionByName($arghp->{'d'}||'');
  my $p = $this->GetQueryPlayer($arghp);
  return $p if UNIVERSAL::isa($p, 'HTTP::Message');
  my $v = HTTP::Message::DecodeURL($arghp->{'v'}); $v = 'x' unless defined $v;
  $v =~ s/^\s+//; $v =~ s/\s+$//; $v =~ s/\s{2,}/ /g; $v =~ s/\d$/$&,/;
  return AJAXError("Name must not be empty, please start over.") if $v !~ /\S/;
  return AJAXError("Illegal characters in name, please start over.") if $v =~ /[;]|[^ -~]/;
  $p->Name($v); $dp->Dirty(1); $dp->Synch(); $dp->Write(); $user_tourney->SaveJSON();
  warn $this->ClientAddress() . ": ".$p->FullID().".name:=".$p->Name()."\n";
  return $this->ResponseOK();
  }

sub QuerySetRating ($$) {
  my $this = shift;
  my $arghp = shift;
  my $user_tourney = $this->{'user_tourney'};
  my $dp = $user_tourney->GetDivisionByName($arghp->{'d'}||'');
  return AJAXError("Player belongs to unknown division, please start over.") unless $dp;
  my $dname = $dp->Name();
  my $pn = $arghp->{'p'};
  return AJAXError("Player ID must be numeric, please start over.") if $pn =~ /\D/;
  my $p = $dp->Player($pn);
  return AJAXError("No such player in division, please start over.") unless $p;
  my $v = $arghp->{'v'}; $v = 'x' unless defined $v;
  return AJAXError("Rating must be numeric, please start over.") if $v =~ /\D/;
  $p->Rating($v); $dp->Dirty(1); $dp->Synch(); $dp->Write(); $user_tourney->SaveJSON();
  warn $this->ClientAddress() . ": ".$p->FullID().".rating:=".$p->Rating()."\n";
  return $this->ResponseOK();
  }

sub QuerySetScores ($$) {
  my $this = shift;
  my $arghp = shift;
  my $user_tourney = $this->{'user_tourney'};
  my $dp = $user_tourney->GetDivisionByName($arghp->{'d'}||'');
  my $p = $this->GetQueryPlayer($arghp);
  return $p if UNIVERAL::isa($p, 'HTTP::Message');
  my $r = $arghp->{'r'};
  return AJAXError("Bad round number '$r'.") if $r =~ /\D/ || $r == 0;
  return AJAXError("Can't skip rounds when entering scores.") if $r > $p->CountScores()+1;
  my $r0 = $r - 1;
  my $opp = $p->Opponent($r0);
  return AJAXError("Player does not have an opponent in round $r.") unless $opp;
  my $v = HTTP::Message::DecodeURL($arghp->{'v'}); $v = '' unless defined $v;
  $v =~ s/^\s+//; $v =~ s/\s+$//;
  if ($v =~ /^-?$/) {
    return AJAXError('Please enter scores before submitting them.');
    }
  return AJAXError("Illegal characters in 1st/2nd ($v), please start over and enter just 1 or 2.") if $v =~ /[^-\s\d]/;
  my ($ms, $os, $excess) = split(/\s+/, $v);
  return AJAXError("Too many numbers in $v, please start over.") if defined $excess;
  if (!defined $os) {
    ($ms, $os) = $v =~ /^(-?\d+)-(-?\d+)$/;
    if (!defined $os) {
      return AJAXError("Can't parse two scores out of '$v'.") unless defined $os;
      }
    }
  $p->Score($r0, $ms); $opp->Score($r0, $os);
  $dp->Dirty(1); $dp->Synch(); $dp->Write(); $user_tourney->SaveJSON();
  warn $this->ClientAddress() . ": ".$p->FullID().".p12[$r]:=".$p->First($r0)."\n";
  return $this->ResponseOK();
  }

sub QueryValet ($$) {
  my $this = shift;
  my $arghp = shift;
  my $user_tourney = $this->{'user_tourney'};
  my $dp = $user_tourney->GetDivisionByName($arghp->{'d'}||'');
  my $p = $this->GetQueryPlayer($arghp);
  return $p if UNIVERSAL::isa($p, 'HTTP::Message');
  my $r = $arghp->{'r'} || 1;
  return AJAXError("Bad round number '$r'.") if $r =~ /\D/;
  my $dname = $dp->Name();
  my $pn = $p->ID();
  return $this->RenderJSONResponseHTML('', qq[ViewValet('$dname',$pn, $r)]);
  }

=item $response = $renderer->Render();

Generate the content needed to serve a request for '/events/old\b.*'.

=cut

my (%gQueryDispatch) = (
  'json' => \&QueryJSON,
  'player' => \&QueryPlayer,
  'set12' => \&QuerySet12,
  'setname' => \&QuerySetName,
  'setrating' => \&QuerySetRating,
  'setscores' => \&QuerySetScores,
  'valet' => \&QueryValet,
  );

sub Render ($) {
  my $this = shift;
  my $tourney = $this->{'server'}->Tournament();
  my $paramsp = $this->{'request'}->FormData();
  my $config = $tourney->Config(); # for error messages
# my $comma = $config->Terminology('comma_space');

  # we open the tournament the user is interested as a separate
  # tournament from the 'tournament' from which we obtained our
  # user interface configuration information, because there's
  # too much that can go wrong if the real tournament is 
  # misconfigured.
  my $html;
  my ($path, $query) = split(/\?/, ".$this->{'url'}"); # relative to /events/old
  my $user_config;
  my $user_tourney;
  eval {
    if (my $u = $this->{'server'}->UserTournament($path)) {
      $user_tourney = $u;
      $user_config = $user_tourney->Config();
#     warn "tourney $path was cached";
      }
    else {
      $user_tourney = new TSH::Tournament({'path'=>$path, 'silent' => 1});
      $this->{'server'}->UserTournament($path, $user_tourney);
      $user_tourney->LoadConfiguration();
      $user_config = $user_tourney->Config();
      $user_tourney->LoadDivisions();
      $user_config->DivisionsLoaded();
      $user_tourney->SaveJSON();
#     warn "tourney $path was not cached";
      }
    };
  if ($@) {
    $html = $this->{'server'}->HTMLHeader('Event', 'event', $user_tourney);
    $html .= $config->Terminology("OldEventsMenuOpenError", $path, $@);
    $html = HTMLFooter();
    return new HTTP::Message(
      'status-code' => 404,
      'body' => $html,
      );
    }
  $this->{'path'} = $path;
  $this->{'user_tourney'} = $user_tourney;
  # $config->Export(); # can't use this in multi-tournament environment
  my $error = '';
  my $viewer = 'ViewRosters();';
  if ($query) {
    my (%argv) = map { my (@s) = (split (/=/,"$_=",3))[0,1]; } split(/&/, $query);
    my $sub = $gQueryDispatch{lc ($argv{'a'}||'')};
    return &$sub($this, \%argv) if $sub;
    $error = $user_config->Terminology('UnknownQuery', $query);
    }
  return $this->RenderJSONResponseHTML($error, $viewer);
  }

sub RenderJSONResponseHTML ($$$) {
  my $this = shift;
  my $error = shift || '';
  my $viewer = shift;

  my $tourney = $this->{'server'}->Tournament();
  my $user_tourney = $this->{'user_tourney'};
  my $user_config = $user_tourney->Config();
  my $event_name = $user_config->Value('event_name') || "Unnamed Event";
  my $event_date = $user_config->Value('event_date') || "Unknown Date";
  my $t = $user_config->Terminology({
    'OldEventsMenuBegin' => [$this->{'path'}, $event_name, $event_date],
#   'OldEventsMenuTitle' => [$event_name, $event_date],
    map { $_ => []} (),
    });
  $error &&= "<p class=error>$error</p>\n";
  my $base_url = $this->{'request'}->URL();
  $base_url =~ s/[?#].*//;
  my $html = <<"EOF";
$error<p class=p1>$t->{'OldEventsMenuBegin'}</p>
<div id=gui_content>&nbsp;</div>
<script type="text/javascript" src="$base_url?a=json"></script>
<script type="text/javascript" src="/js/gui.js"></script>
<script type="text/javascript" src="/js/tsh.js"></script>
<script type="text/javascript">
Initialise(newt);
$viewer
</script>
EOF
  $html = $this->{'server'}->HTMLHeader('Event', 'event', $user_tourney) . $html . HTMLFooter();
  return new HTTP::Message(
    'status-code' => 200,
    'body' => $html,
    );
  }

sub RenderRoster ($$) {
  my $this = shift;
  my $user_tourney = shift;
# my $tourney = $this->{'server'}->Tournament();
  my (@dps) = $user_tourney->Divisions();
  my (@dnames) = map { $_->Name() } @dps;
  my $html = '<table class=roster>';
  if (@dps > 1) {
    }
  else { # one division
    my $dp = $dps[0];
    my $dname = $dp->Name();
    my (@ps) = map {
      my $id = $_->ID();
      my $pname = $_->Name();
      [
      '<td>'
	. popup_menu("id_${dname}_$id", [1..$dp->CountPlayers()], $id)
        . checkbox("on_${dname}_$id", $_->Active(), 'on', '')
	. $pname
	. '</td>',
	$pname,
	$dname,
	$id,
      ]
      } $dp->Players();
    for my $p (@ps) {
      $html .= '<tr>' . $p->[0] . '</tr>';
      }
    }
  $html .= '</table>';
  return $html;
  }

sub ResponseOK ($) {
  my $this = shift;
  return new HTTP::Message( 'status-code' => 200, 'body' => qq[gAJAXError='']);
  }

=back

=cut

1;
