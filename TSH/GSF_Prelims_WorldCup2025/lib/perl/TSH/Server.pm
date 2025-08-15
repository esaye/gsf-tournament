#!/usr/bin/perl

# Copyright (C) 2006 John J. Chew, III <jjchew@math.utoronto.ca>
# All Rights Reserved

package TSH::Server;

use strict;
use warnings;

use File::Spec;
use HTTP::Message qw(EncodeEntities);
use HTTP::Server;
use TSH::Config;
use TSH::Command::RoundRATings;
use TSH::Command::ShowPairings;
use TSH::Server::Content;
use TSH::Server::Content::Widget;
use Net::Domain qw(hostfqdn);

our (@ISA) = qw(HTTP::Server Exporter);
our (@EXPORT_OK) = qw(HTMLFooter HTMLHeader);

=pod

=head1 NAME

TSH::Server - provide web access to the tsh process

=head1 SYNOPSIS

  my $server = new TSH::Server($port) || die;
  $server->Start() or die;
  while ($server->Run()) {}
  $server->Stop();
  
=head1 ABSTRACT

This subclass of HTTP::Server provides single-threaded access to
the tsh process.

=head1 DESCRIPTION

=over 4

=cut

sub new ($$;$);
sub ConfigItem ($$);
sub Render ($$);
sub ContentConfig ($$;$);
sub ContentDivision ($$$$);
sub ContentDocumentation ($$$$$);
sub ContentReport ($$$$$$);
sub ContentRoot ($$);
sub ContentSelfServiceScoring ($$);
sub ContentStaticReport ($$$$$);
sub HTMLFooter ();
sub HTMLHeader ($$$;$);
sub RenderSSSForm ($$);
sub SaveConfigChanges ($$$);
sub Start ($);
sub Tournament ($);
sub ValidatePlayerEntry ($$);

=item $server = new TSH::Server($port, $tournament, \%options);

Create a new TSH::Server object.  

C<port>: port to listen on for new connections.

C<tournament>: TSH tournament object associated with server.

=cut

sub new ($$;$) {
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $port = shift;
  my $tournament = shift;
  my (%options) = %{shift || {}};
  my $config = $tournament->Config();
  my $this = $class->SUPER::new(
    'port' => $port,
#   'content' => \&TSH::Server::Content,
    'version' => "tsh/$main::gkVersion",
    %options,
    );
  $this->{'tournament'} = $tournament;
  bless($this, $class);
  $this->SetHTTPServerContentHandler(sub { $this->Render(@_); }); # a closure
  $this->{'commands'}{'rrat'} = new TSH::Command::RoundRATings('noconsole' => 1);
  $this->{'commands'}{'sp'} = new TSH::Command::ShowPairings('noconsole' => 1);
  return $this;
  }

=item $error = $sp->ConfigCheck();

Checks to see if the currently loaded configuration can be used to
run tsh in server mode, returns an error message if not.

=cut

sub ConfigCheck ($) {
  my $this = shift;
  my $config = $this->Tournament()->Config();
  my @problems;
  unless ($config->Value('max_rounds')) {
    push(@problems, "The mandatory max_rounds option has not been specified.");
    }
  if (@problems) {
    if (@problems == 1) {
      return "You must correct this configuration before you can proceed. "
        . $problems[0];
      }
    else { die; }
    }
  else { return ''; }
  }

=item $html = $server->TSH::Server::ConfigItem($name);

Returns a line of $html code for use in ContentConfig or ContentProfile.

=cut

sub ConfigItem ($$) {
  my $this = shift;
  my $name = shift;
  my $tourney = $this->Tournament();
  my $config = $tourney && $tourney->Config();
  my $value = eval "\$config::$name";
  my $help = TSH::Config::UserOptionHelp($name);
  my $jstype = $config->UserOptionJSType($name);
  my $related = TSH::Config::UserOptionRelated($name);
  my $type = TSH::Config::UserOptionType($name);
  if ($type eq 'internal') { return ''; }
  my $html = "<tr><td class=name>$name</td>";
  my $jsvalue = JavaScript::Serializable::ToJavaScriptAny($value);
  $related = $related ? ' tsh_widget_related="[' . join(',', map { qq('$_') } @$related) . ']"' : '';
  $jsvalue = '' if $jsvalue eq 'undefined';

  if (!defined $type) {
    $html .= "<td>unknown config item</td>";
    }
  $html .= <<"EOF";
<td><div class=tshwc tsh_widget_name="$name" tsh_widget_type="$jstype" tsh_widget_value="$jsvalue"$related></div></td>
EOF
  
# if (my $widget = new TSH::Server::Content::Widget('name' => $name,
#   'type' => $type, 'value' => $value, 'tourney' => $tourney)) {
#   $html .= '<td>' . $widget->RenderHTML() . '</td>';
#   }
# else {
#   $html .= "<td>unknown config type: $type</td>";
#   }
  if ($help) {
    $html .= "<td class=help>$help</td>";
    }
  $html .= "</tr>";
  return $html;
  }

=item $response = $server->Render($request);

Generate the content needed to serve an HTTP request.
See HTTP::Server for details.

=cut

sub Render ($$) {
  my $this = shift;
  my $request = shift;
  my $client = shift;
  my $url = $request->URL();

  my $renderer = new TSH::Server::Content($this, $request, $url, $client);
  return $renderer->Render();
  }

my %category_data;
BEGIN {
  %category_data = (
    'basic' => {
      'order' => 1,
      'title' => 'ConfigCategoryTitleBasic',
      'description' => 'ConfigCategoryDescBasic',
      },
    'identification' => {
      'order' => 2,
      'title' => 'ConfigCategoryTitleIdentification',
      'description' => 'ConfigCategoryDescIdentification',
      },
    'directories' => {
      'order' => 3,
      'title' => 'ConfigCategoryTitleDirectories',
      'description' => 'ConfigCategoryDescDirectories',
      },
    'formatting' => {
      'order' => 4,
      'title' => 'ConfigCategoryTitleFormatting',
      'description' => 'ConfigCategoryDescFormatting',
      },
    'pairing' => {
      'order' => 5,
      'title' => 'ConfigCategoryTitlePairing',
      'description' => 'ConfigCategoryDescPairing',
      },
    'ui' => {
      'order' => 6,
      'title' => 'ConfigCategoryTitleUI',
      'description' => 'ConfigCategoryDescUI',
      },
    'miscellaneous' => {
      'order' => 7,
      'title' => 'ConfigCategoryTitleMiscellaneous',
      'description' => 'ConfigCategoryDescMiscellaneous',
      },
    'regional' => {
      'order' => 8,
      'title' => 'ConfigCategoryTitleRegional',
      'description' => 'ConfigCategoryDescRegional',
      },
    'advanced' => {
      'order' => 10,
      'title' => 'ConfigCategoryTitleAdvanced',
      'description' => 'ConfigCategoryDescAdvanced',
      },
    'deprecated' => {
      'order' => 20,
      'title' => 'ConfigCategoryTitleDeprecated',
      'description' => 'ConfigCategoryDescDeprecated',
      },
    );
  }

=item $response = $server->ContentConfig($request, $url, 'event'|'profile', [, $error]);

Generate the content needed to serve a request for '/config/index.html' or '/profile/index.html'.

=cut

sub ContentConfig ($$;$) {
  my $this = shift;
  my $request = shift;
  my $url = shift;
  my $source = shift;
  my $error = shift; $error = ref($error) ? $error->{'error'} : '';
  my $formp = $request->FormData();
  my $tournament = $this->Tournament();
  my $sourceObject = $source eq 'config' ? $tournament->Config() 
    : $source eq 'profile' ? $tournament->Profile()
    : Carp::confess "Unknown source '$source'";
  my $config = $tournament->Config();
  my $t = $config->Terminology({map { $_ => [] } 
    qw(ConfigEditorTitle ConfigEditorValidationFailed ProfileEditorTitle)});
  my $html = $this->HTMLHeader($source eq 'config' ? 'NavBarHeadConfigure' : 'NavBarHeadProfile', 'event', {
  'onload' => 'SetupTSHWidgets()',
  'extra' => <<'EOF',
<script type="text/javascript" src="/js/tsh.js"></script>
<script type="text/javascript">
var tshConfig;
function SaveChanges () {
  var messages = tshConfig.Validate({});
  if (messages.length) { 
    alert("$t->{'ConfigEditorValidationFailed'} "+messages.join(' '));
    return; 
    }
  error(tshConfig.ReadInputString());
  }
function SetupTSHWidgets () {
  tshConfig = new TSHWidgetRegistry();
  tshConfig.LoadWidgetsByClass('tshwc');
  tshConfig.Validate({});
  }
</script>
EOF
  }
    ) . "<h1>$t->{$source eq 'config' ? 'ConfigEditorTitle' : 'ProfileEditorTitle'}</h1>";
  if ($formp->{'post'}) {
    $html .= $this->SaveConfigChanges($formp, $source);
    $error = $this->ConfigCheck();
    }
  if ($error) {
    $html .= "<div class=failure>$error</div>";
    }
  $html .= "<p class=p1>" . $config->Terminology($source eq 'config' ? 'ConfigEditorIntro' : 'ProfileEditorIntro', '???') . "</p>\n";
  $html .= <<"EOF";
<form method="post" action="/$source/" enctype="application/x-www-form-urlencoded">
EOF
  my %options_by_category;
  for my $key ($sourceObject->UserOptions()) {
    my $category = TSH::Config::UserOptionCategory($key);
    $options_by_category{$category}{$key}++;
    }
  for my $category (sort 
    { $category_data{$a}->{'order'} <=> $category_data{$b}->{'order'} }
    keys %options_by_category) {
    my $catdp = $category_data{$category} || die "Unknown category: $category";
    my $catname = $config->Terminology($catdp->{'title'}) || $category;
    my $description = $config->Terminology($catdp->{'description'}) || '?';
    my $subhtml = '';
    for my $key (sort keys %{$options_by_category{$category}}) { 
      $subhtml .= $this->ConfigItem($key); 
      }
    $html .= <<"EOF" if length($subhtml);
<h2>$catname</h2>
<p class=description>$description</p>
<table class=config align=center width="100%">
<tr><th>Option Name</th><th>Value</th><th>Description</th></tr>
$subhtml
</table>
EOF
    }
   
  $html .= <<"EOF";
</table>
<p class=p2><input type=button value=\"Save Changes\" onclick="SaveChanges()"></p>
</form>
EOF
  # autopair
  $html .= HTMLFooter();
  return new HTTP::Message(
    'status-code' => 200,
    'body' => $html,
    );
  }

=item $response = $server->ContentDivision($request, $url, $division);

Generate the content needed to serve a request for '/division/DIVNAME'.

=cut

sub ContentDivision ($$$$) {
  # TODO: do some sort of caching here?
  my $this = shift;
  my $request = shift;
  my $url = shift;
  my $div = TSH::Division::CanonicaliseName(shift);
  my $html = $this->HTMLHeader('NavBarHeadMain', 'event');
  my $tournament = $this->Tournament();
  my $config = $tournament->Config();
  my (@dps) = $tournament->Divisions();
  my $dp = $tournament->GetDivisionByName($div) || $dps[0];
  my $max_rounds = $dp->MaxRound0() + 1;
  $div = $dp->Name();
  $html .= "<div class=divlist>";
  $html .= "<span class=label>Division:</span>";
  for my $adp ($tournament->Divisions()) {
    my $adiv = $adp->Name();
    if ($div eq $adiv) {
      $html .= qq(<span class=here>$adiv</span>);
      }
    else {
      $html .= qq(<span class=there><a href="/division/$adiv/">$adiv</a></span>); 
      }
    }
  $html .= "</div>";
  $html .= qq(<form method="post" action="/division/$div" enctype="application/x-www-form-urlencoded">);
  $html .= qq(<table class=dedit cellspacing=0>);
  {
    my $start = "<td colspan=2 rowspan=3 class=reports>Reports</td>";
    my (@data) = (
      'Alpha Pair', 'alpha-pairings',
      'Rank Pair', 'pairings',
      'Standings', 'ratings',
      );
    while (@data) {
      my $label = shift @data;
      my $type = shift @data;
      $html .= "<tr>$start";
      $start = '';
      for my $round (1..$max_rounds) {
	$html .= sprintf(qq(<th class=report><a target="report" href="/%s-%s-%d.html">%s</a></th>), $div, $type, $round, $label); 
	}
      $html .= "</tr>";
      }
  }
  $html .= "<tr>"
    . qq(<th class=id>ID</th>)
    . qq(<th class=name>Name</th>);
  for my $round (1..$max_rounds) {
    $html .= qq(<th class=round>Round $round</th>); 
    }
  $html .= "</tr>";
  my (@players) = $dp->Players();
  my $pfmt = '%0' . length(scalar(@players)) . 'd';
  for my $pp (@players) {
    my $id = $pp->ID();
    my $name = $pp->Name();
    $html .= sprintf(qq(<tr><td class=id>$pfmt</td><td class=name>%s</td>),
      $id, $name);
    for my $round (1..$max_rounds) {
      my $round0 = $round - 1;
      my $ms = $pp->Score($round0);
      my $p12 = '';
      if ($config->Value('track_firsts')) {
	$p12 = ('','1st vs. ','2nd vs. ','draw vs. ','')[$pp->First($round0)||0];
        }
      my $oid = $pp->OpponentID($round0);
      my $on = '';
      if ($oid) { 
	$oid = sprintf($pfmt, $oid);
	my $op = $pp->Opponent($round0);
	if ($op) {
	  $on = $pp->Opponent($round0)->Initials();
	  }
        }
      else { $oid = '-'; }
      my $os = $pp->OpponentScore($round0);
      my $scores;
      if ((defined $ms) && (defined $os)) {
	$scores = "$ms&ndash;$os";
        }
      elsif ($oid ne '-') {
	$scores = ((defined $ms) ? $ms : '?') . '-' . 
	  ((defined $os) ? $os : '?');
        }
      elsif (defined $ms) {
	$scores = sprintf("%+d", $ms);
	$oid = 'bye';
        }
      else {
	$on = '??';
	$scores = '?';
        }
      $html .= qq(<td class=round><div class=opp>$p12$oid$on</div><div class=score>$scores</div></td>);
      }
    $html .= qq(</tr>);
    }
  $html .= qq(</table>);
  $html .= qq(</form>);
  $html .= HTMLFooter();
  return new HTTP::Message(
    'status-code' => 200,
    'body' => $html,
    );
  }

=item $response = $server->ContentDocumentationFramed($request,$url,$fname,$fext);

Generate the content needed to serve a request for a documentation file.

=cut

sub ContentDocumentationFramed ($$$$$) {
  my $this = shift;
  my $request = shift;
  my $url = shift;
  my $fname = shift;
  my $fext = shift;

  my $formp = $request->FormData();
  my $html = $this->HTMLHeader('NavBarHeadHelp', 'event');
  $html .= <<"EOF";
<iframe style="min-height: 100%; height: 100%; width: 100%" src="/docraw/$fname.$fext" frameborder=0>
<a href="/docraw/$fname.$fext">click here if your browser does not support iframes</a>.
</iframe>
EOF
  $html .= HTMLFooter();
  return new HTTP::Message(
    'status-code' => 200,
    'body' => $html,
    );
  }

=item $response = $server->ContentDocumentationUnFramed($request,$url,$fname,$fext);

Generate the content needed to serve a request for a documentation file.

=cut

sub ContentDocumentationUnframed ($$$$$) {
  my $this = shift;
  my $request = shift;
  my $url = shift;
  my $fname = shift;
  my $fext = shift;

  return HTTP::Server::StaticContent("doc/$fname", $fext, $request);
  }

=item $response = $server->ContentJavaScript($request,$url,$fname,$fext);

Generate the content needed to serve a request for a documentation file.

=cut

sub ContentJavaScript ($$$$$) {
  my $this = shift;
  my $request = shift;
  my $url = shift;
  my $fname = shift;
  my $fext = shift;

  return HTTP::Server::StaticContent("lib/js/$fname", $fext, $request);
  }

=item $response = $server->ContentLibraryFile($request,$url,$fname,$fext);

Generate the content needed to serve a request for a documentation file.

=cut

sub ContentLibraryFile ($$$$$) {
  my $this = shift;
  my $request = shift;
  my $url = shift;
  my $fname = shift;
  my $fext = shift;

  return HTTP::Server::StaticContent("lib/$fname", $fext, $request);
  }

=item $response = $server->ContentPhoto($request,$url,$fname,$fext);

Generate the content needed to serve a request for a documentation file.

=cut

sub ContentPhoto ($$$$$) {
  my $this = shift;
  my $request = shift;
  my $url = shift;
  my $fname = shift;
  my $fext = shift;

  return HTTP::Server::StaticContent("lib/pix/$fname", $fext, $request);
  }

=item $response = $server->ContentPrimaryRoot($request);

Generate the content needed to serve a request for '/'.

=cut

sub ContentPrimaryRoot ($$) {
  my $this = shift;
  my $request = shift;
  my $tournament = $this->Tournament();
  my $t = $tournament->Config()->Terminology({ map { $_ => [] } 
    qw(MainMenuTitle MainMenuWelcome MainMenuFirst MainMenuEvent MainMenuHelp MainMenuTerms)});
  my $html = $this->HTMLHeader('NavBarHeadMain', 'main');
  $html .= <<"EOF";
<h1>$t->{'MainMenuTitle'}</h1>
<p class=p1>$t->{'MainMenuWelcome'}</p>
<ul>
<li>$t->{'MainMenuFirst'}</li>
<li>$t->{'MainMenuEvent'}</li>
<li>$t->{'MainMenuHelp'}</li>
</ul>
<p class=p1>$t->{'MainMenuTerms'}</p>
EOF
  $html .= HTMLFooter();
  return new HTTP::Message(
    'status-code' => 200,
    'body' => $html,
    );
  }

=item $response = $server->ContentReport($request, $url,$division, $type, $round);

Generate the content needed to serve a request for 
'/DIVNAME-pairings-ROUND.html'
or
'/DIVNAME-alpha-pairings-ROUND.html'
.

=cut

sub ContentReport ($$$$$$) {
  my $this = shift;
  my $request = shift;
  my $url = shift;
  my $dname = TSH::Division::CanonicaliseName(shift);
  my $type = shift;
  my $round = shift;
  my $html = $this->HTMLHeader('NavBarHeadMain', 'event');
  my $tournament = $this->Tournament();
  my $dp = $tournament->GetDivisionByName($dname);
  if ($type =~ /^(?:alpha-)?pairings$/) {
    $this->{'commands'}{'sp'}->Run($tournament, $round, $dp);
    }
  elsif ($type eq 'ratings') {
    $this->{'commands'}{'rrat'}->Run($tournament, $round, $round, $dp);
    }
  my $basefn = $tournament->Config()->MakeHTMLPath(sprintf("%s-%s-%03d",
    $dname, $type, $round));
  if (-r "$basefn.html") {
    return HTTP::Server::StaticContent($basefn, 'html', $request);
    }
  else {
    return new HTTP::Message( 'status-code' => 404, 'body' => "The report you asked for is unavailable." );
    }
  }

=item $response = $server->ContentRoot($request);

Generate the content needed to serve a request for '/'.

=cut

sub ContentRoot ($$) {
  my $this = shift;
  my $request = shift;
  my $tournament = $this->Tournament();
  if ($tournament->Config()->Value('primary_gui')) {
    return $this->ContentPrimaryRoot($request);
    }
  elsif ($tournament->CountDivisions() == 0) 
    { return $this->ContentConfig($request); }
  else { 
    return $this->ContentDivision($request, '/ignored',
      ($tournament->Divisions())[0]->Name()); 
    }
  }

=item $response = $server->ContentSelfServiceScoring($request);

Generate the content needed to serve a request for '/cgi/sss'.

=cut

sub ContentSelfServiceScoring ($$) {
  my $this = shift;
  my $request = shift;
  my $formp = $request->FormData();
  my $html = $this->HTMLHeader('NavBarHeadValet', 'event') . "<h1>Self-Service Scoring</h1>";
  if ($formp->{'validate'}) {
    $html .= $this->ValidatePlayerEntry($request);
    }
  else {
    $html .= $this->RenderSSSForm({'request' => $request});
    }
  $html .= <<"EOF";
</table>
</form>
EOF
  $html .= HTMLFooter();
  return new HTTP::Message(
    'status-code' => 200,
    'body' => $html,
    );
  }

sub ContentShutdown ($) {
  my $this = shift;
  $this->Shutdown();
  return new HTTP::Message(
    'status-code' => 200,
    'body' => '<html><head></head><body><p>Close this window to return to the <cite>tsh</cite> command line.</p></body></html>',
    )
  }

=item $response = $server->ContentStaticReport($request,$url,$fname,$fext);

Generate the content needed to serve a request for a 
report that tsh has already generated.

=cut

sub ContentStaticReport ($$$$$) {
  my $this = shift;
  my $request = shift;
  my $url = shift;
  my $fname = shift;
  my $fext = shift;

  return HTTP::Server::StaticContent($this->Tournament()->Config()->MakeHTMLPath($fname), $fext, $request);
  }

=item $html = TSH::Server::HTMLFooter();

Return an HTML footer.

=cut

sub HTMLFooter () {
  return "</body></html>";
  }

=item $html = $s->HTMLHeader($section, $type);

Return an HTML header suitable for displaying in section $section.

=cut

# @navbardata is a list of references to hashes, each of which
# contains information about a possible navbar item to display.
# Hash structure:
#
# label => terminology key for this item's label

my (@navbardata);
BEGIN {
  (@navbardata) = (
#   {'label' => 'NavBarHeadMain', 'url' => '/', 'types' => ['main','events', 'event'], 'active' => 0},
    {'label' => 'NavBarHeadProfile', 'hover' => 'NavBarHeadProfileHover', 'url' => '/profile/', 'types' => ['main','events', 'event'], 'active' => 1},
    {'label' => 'NavBarHeadEvents', 'hover' => 'NavBarHeadEventsHover', 'url' => '/events/', 'types' => ['main','events', 'event'], 'active' => 1},
    {'label' => 'NavBarHeadConfigure', 'hover' => 'NavBarHeadConfigureHover', 'url' => '/config/', 'types' => ['events', 'event'], 'active' => 1},
    {'label' => 'NavBarHeadReports', 'hover' => 'NavBarHeadReportsHover', 'url' => '/report/', 'types' => ['events', 'event'], 'active' => 0},
    {'label' => 'NavBarHeadSSS', 'hover' => 'NavBarHeadSSSHover', 'url' => '/cgi/sss', 'types' => ['events', 'event'], 'active' => 0},
    {'label' => 'NavBarHeadValet', 'hover' => 'NavBarHeadValetHover', 'url' => '#', 'types' => ['event'], 'onclick' => 'ViewValet(); return false', 'active' => 1},
    {'label' => 'NavBarHeadHelp', 'hover' => 'NavBarHeadHelpHover', 'url' => '/doc/', 'types' => ['main', 'events', 'event'], 'active' => 1},
    {'label' => 'NavBarHeadTutorial', 'hover' => 'NavBarHeadTutorialHover', 'url' => '/doc/tutorial.html', 'types' => ['main', 'events', 'event'], 'active' => 0},
    {'label' => 'NavBarHeadQuit', 'hover' => 'NavBarHeadQuitHover', 'url' => '/shutdown/index.html', 'types' => ['main', 'events', 'event'], 'active' => 1},
    );
  for my $d (@navbardata) {
    $d->{'types'} = { map { $_ => 1 } @{$d->{'types'}} };
    }
  }

sub HTMLHeader ($$$;$) {
  my $this = shift;
  my $section = shift;
  my $type = shift;
  my $options = shift;
# my $tourney = shift;
  my $tourney = $this->Tournament();
  my $config = $tourney && $tourney->Config();
  my $onload = $options->{'onload'} ? qq( onload="$options->{'onload'}") : '';
  my $extra = $options->{'extra'} ? qq(\n$options->{'extra'}) : '';
  my $html = <<"EOF";
<!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.01//EN">
<html>
<head>
<meta name="viewport" content="width=device-width; user-scalable=false" />
<title>tsh $main::gkVersion</title>
<link rel=stylesheet href="/tsh.css">
<script type="text/javascript" src="/js/tsh-widget.js"></script>$extra
<script type="text/javascript">
function TSHValidateInteger(el) {
  var value = el.value;
  var selectionStart = el.selectionStart;
  var selectionEnd = el.selectionEnd;
  if (value.length == 0) {
    el.value = '0';
    el.select();
    return false;
    }
  var sign = '';
  if (value.substring(0,1) == '-') {
    sign = '-';
    value = value.substring(1);
    }
  if (value.length == 0) {
    el.value = '0';
    el.select();
    return false;
    }
  value = sign + value.replace(/[^0-9]/g,'');
  if (value != el.value) {
    selectionStart += value.length - el.value.length;
    selectionEnd += value.length - el.value.length;
    el.value = value;
    el.setSelectionRange(selectionStart, selectionEnd);
    }
  return false;
  }
</script>
</head>
<body class=gui$onload>
EOF
  $html .= qq(<div class="navbar noprint">);
  $html .= "<span class=label>tsh $::gkVersion</span>";
  $html .= "<span class=colon>:</span> <span class=event>"
    . ($config->Value('event_name') || 'Unnamed Event')
    . ' (' . ($config->Value('event_date') || 'Unknown Date') . ')'
    . "</span> "
    if $config && $type ne 'main';
# $html .= qq(<a href="notyet">change event</a>);
  $html .= "<div class=seclist>";
  for my $nbd (@navbardata) {
    next unless $nbd->{'types'}{$type};
    my $hover = $config 
      ? ' title="'.$config->Terminology($nbd->{'hover'}).'"' || ''
      : '';
    my $label = $config ? $config->Terminology($nbd->{'label'}) : 
      do { my $label = $nbd->{'label'}; $label =~ s/^NavBarHead//; $label };
    $label = 'Return to <cite>tsh</cite> command line' if $label eq 'Quit' && $this->Tournament()->Virtual();
    if ($nbd->{'label'} eq $section) 
      { $html .= "<span class=here$hover>$label</span>"; }
    elsif ($nbd->{'active'})
      { my $onclick = $nbd->{'onclick'} ? qq( onclick="$nbd->{'onclick'}") : ''; $html .= qq(<span class=there id="nav_\L$nbd->{'label'}\E"$hover><a href="$nbd->{'url'}"$onclick>$label</a></span>); }
    else 
      { $html .= "<span class=inactive>$label</span>"; }
    }
  $html .= "</div>";
  $html .= "</div>";
  return $html;

  die "This stuff needs a home";
#   $html .= "</tr>";
#   $html .= <<"EOF";
# <script language="JavaScript">
# function Division (div) {
#   alert(div);
#   }
# </script>
# EOF
  }

=item $html = $server->RenderSSSForm(\%options);

Render an SSS form given the following options in C<\%options>.

C<errors>: two-element list of errors to display below table columns

=cut

sub RenderSSSForm ($$) {
  my $this = shift;
  my $options = shift;
  my $request = $options->{'request'};
  my $formp = $request->FormData();
  my $html = '';

  my $errors = '';
  if (my $ep = $options->{'errors'}) {
    $errors = "<tr class=error><th class=label>&nbsp;</th><td>$ep->[0]</td><td>$ep->[1]</td></tr>\n";
    $errors .= "<tr><td colspan=3>Please correct the errors above and resubmit your scores.</td></tr>\n";
    }
  my $config = $this->Tournament()->Config();
  my (@labels) = 
    ($config->Value('track_firsts') && !$config->Value('assign_firsts'))
      ? ('Played First','Played Second')
      : ('Winner', 'Loser');
  my %param;
  for my $key (qw(p1s p2s p1p p2p)) {
    my $value = $formp->{$key};
    $param{$key} = (defined $value) ? $value : '';
    $value =~ s/\W//g;
    }
  $html .= <<"EOF";
<form method="post" action="/cgi/sss" enctype="application/x-www-form-urlencoded">
<table class=pe align=center width=400px cellspacing=0>
<tr><th>&nbsp;</th><th>$labels[0]</th><th>$labels[1]</th></tr>
<tr>
<th class=label>Score</th>
<td class=score><input name=p1s type=text maxlength=5 size=8 value="$param{'p1s'}"></td>
<td class=score><input name=p2s type=text maxlength=5 size=8 value="$param{'p2s'}"></td>
</tr>
<tr>
<th class=label>Password</th>
<td class=pswd><input name=p1p type=password maxlength=8 size=8 value="$param{'p1p'}"></td>
<td class=pswd><input name=p2p type=password maxlength=8 size=8 value="$param{'p2p'}"></td>
</tr>
$errors<tr>
<td colspan=3>
<p class=p2>
If this is your first time using self-service scoring, please follow
the instructions carefully.
</p>
<ol>
<li>
Either player enters the game scores.  Click or use the tab or shift-tab
keys to move between boxes.
</li>
<li>
To confirm that each score is correct, each player enters their
password in the box below their own score.
</li>
<li>
Click on &ldquo;Submit Scores&rdquo;. You will be given a chance to confirm that your cumulative
results look correct before the scores are posted.
</li>
</ol>
</td>
</tr>
<tr>
<td colspan=3 align=center><input type=submit name=validate value=\"Submit Scores\"></p>
</tr>
</table>
EOF
  }

=item $html = $server->SaveConfigChanges($formp, $source);

Saves changes to tsh's configuration as indicated by the form variables
in the hash %$formp.  Returns a message informing the user whether or
not the operation succeeded.

=cut

sub SaveConfigChanges ($$$) {
  my $this = shift;
  my $formp = shift;
  my $source = shift;
  my $tournament = $this->Tournament();
  my $sourceObject = $source eq 'config' ? $tournament->Config() 
    : $source eq 'profile' ? $tournament->Profile()
    : Carp::confess "Unknown source '$source'";
  my $config = $tournament->Config();
  my $fh;
  my $changed = 0;
  for my $key ($sourceObject->UserOptions()) {
    my $newvalue = $formp->{$key};
    my $type = TSH::Config::UserOptionType($key);
    my $error = UserOptionValidate($key, $newvalue);
    return "<div class=failure>$error</div>" if $error;
    my $oldvaluep = $config::{$key};
    if ($type eq 'boolean') { 
      if ($newvalue xor $$oldvaluep) {
	$changed = 1;
	$$oldvaluep = $newvalue ? 1 : 0;
        }
      }
    elsif ($type eq 'integer') { 
      $newvalue = $newvalue ? 0+$newvalue : 0; 
      if ($newvalue != ($$oldvaluep||0)) {
	$changed = 1;
	$$oldvaluep = $newvalue;
        }
      }
    elsif ($type eq 'string') { 
      $newvalue = (defined $newvalue) ? $newvalue : '';
      if ($newvalue ne ((defined $$oldvaluep) ? $$oldvaluep : '')) {
	$changed = 1;
	$$oldvaluep = $newvalue;
        }
      }
    else 
      { return "<div class=failure>Unknown key type ($type) for $key.</div>"; }
    }
  return $sourceObject->Save();
  }

=item $server->Start() or die;

Start the server by opening the listener socket.

=cut

sub Start ($) {
  my $this = shift;
  print "Starting server...\n";
  my $result = $this->SUPER::Start();
# my $host = hostfqdn(); # takes too long
  my $port = $this->GetHTTPServerPort();
  print <<"EOF" unless $this->Tournament()->Virtual();
tsh is now in server mode.  You can connect to the server at 
http://localhost:$port from this machine, or from other machines
by replacing 'localhost' with your machine's network address.
To start tsh in interactive mode, do not include a "config port" line
in your configuration file.
EOF
  }

sub Tournament ($) {
  my $this = shift;
  return $this->{'tournament'};
  }

sub UserTournament ($$;$) {
  my $this = shift;
  my $path = shift;
  my $new = shift;
  $path =~ s/^\.\/+//;
  $path =~ s/\/+$//;
  my $old = $this->{'user_tournaments'}{$path};
  if (defined $new) {
    $this->{'user_tournaments'}{$path} = $new;
    }
  return $old;
  }

=item $response = $server->ValidatePlayerEntry($request);

Generate the content needed to validate an SSS entry.

=cut

sub ValidatePlayerEntry ($$) {
  my $this = shift;
  my $request = shift;
  my $html = '<h1>Not yet</h1>';
  my $formp = $request->FormData();
  my $config = $this->Tournament()->Config();
  my (@passwords) = @$formp{qw(p1p p2p)};
  my (@scores) = @$formp{qw(p1s p2s)};
  my (@errors) = ('','');
  my $errors;
  my (@players);
  for my $i (0..1) {
    if (my $p = $config->GetPlayerByPassword($passwords[$i])) {
      $players[$i] = $p;
      }
    else {
      $errors[$i] = 'Invalid password';
      $errors++;
      }
   }
  if ($errors) {
    return $this->RenderSSSForm({'errors'=>\@errors, 'request' => $request});
    }

  $html .= "@passwords @scores";

  return $html;
  }

=back

=head1 BUGS

Needs to support multithreaded access.

=cut

1;
