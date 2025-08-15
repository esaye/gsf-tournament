#!/usr/bin/perl

use strict;
use warnings;

use CGI qw(:standard);
use lib '/Users/jjc/local/tsh/dev/phiz';
use lib '/home/httpd/vhosts/staging.scrabble-assoc.com/httpdocs/event/nssc2011/lib/perl';

use JJC qw(DBGet ModTime);
use PoslID;
use Fcntl ':flock';

sub AddComment ();
sub DelComment ();
sub Authenticate ();
sub JSEscape ($);
sub LoadThreadData ($);
sub LogDeletedComment ($);
sub Main ();
sub ParseThreadID ($);
sub SanitizeAttributes ($$$);
sub SanitizeContent ($);
sub SanitizeTag ($);
sub SaveThreadData ($$);
sub TryAddComment ($);
sub TryDelComment ($);

our %escape;
our $escape;
our $poslid_user;
our $real_name = '';

$config::division_required = 0;
$config::help_email = 'poslfit@gmail.com';
$config::poslid_directory = '/home/httpd/vhosts/staging.scrabble-assoc.com/httpdocs/event/nssc2011/phiz/poslid';
$config::system_name = 'NSSC 2011';
$config::phiz_directory = '/home/httpd/vhosts/staging.scrabble-assoc.com/httpdocs/event/nssc2011/phiz';

Main;

BEGIN {
  (%escape) = (
    "\"" => "\\\"",
    "\n" => "\\\n",
    "{" => "\\x7b",
    "}" => "\\x7d",
    );
  $escape = join('', keys %escape);
  };

sub AddComment () {
  my $new_id = param('at');
  my $datap = LoadThreadData $new_id;
  return $datap if exists $datap->{'error'};
  my $new_content = SanitizeContent(param('nc') || '');
  if ($new_content !~ /\S/) {
    return { 'error' => 'Your empty comment was not posted.' };
    }
  my $js = '{'
    . '"ct":' . (time*1000) . ','
    . '"au":"' . JSEscape($real_name) . '",'
    # TODO: should hash the following to avoid leaking username
    . '"ci":"' . (time . '_' . $poslid_user) . '",'
    . '"tx":"' . JSEscape($new_content) . '"}';
  if ($datap->{'data'} eq '[]') { 
    $datap->{'data'} = "[$js]";
    }
  else {
    $datap->{'data'} =~ s/]$/,$js]/ 
      or return { 'error' => "Update failed (1:$new_id), please contact the event administrator." }; 
    }
  if (my $error = SaveThreadData $new_id, $datap) {
    return { 'error' => $error };
    }
  return $datap;
  }

sub Authenticate () {
  PoslID::Initialise(
#   domain => $::ENV{'SERVER_NAME'},
    source => $config::poslid_directory,
    header => ('***HEADER***'),
    footer => ('***FOOTER***'),
    help_email => $config::help_email,
    silent => 1,
    system_name => $config::system_name,
#   hidden => [qw(config)],
    );
  if (PoslID::Check()) {
    print header('-cookie' => PoslID::Cookie());
    $poslid_user = PoslID::User();
#   warn "Authentication succeeded for $poslid_user";
    }
  else { 
    print header; 
#   warn "Authentication failed";
    }
  }

sub DelComment () {
  my $tid = param('at');
  my $cid = param('di');
  $cid =~ s/\W//g;
  my $datap;
  eval {
    $datap = LoadThreadData $tid;
    die $datap->{'error'} if exists $datap->{'error'};
    die "Comment not found" unless $datap->{'data'} =~ s/({[^{}]+"ci":"$cid"[^{}]+}),?//;
    LogDeletedComment $1;
    $datap->{'data'} =~ s/^\[,/[/;
    $datap->{'data'} =~ s/,]/]/;
    if (my $error = SaveThreadData $tid, $datap) { die $error; }
    };
  if ($@) {
    return { 'error' => $@ };
    }
  return $datap;
  }

sub JSEscape ($) {
  local ($_) = shift;
  $_ = '' unless defined $_;
  s/[$escape]/$escape{$&}/ego;
  return $_;
  }

sub LoadThreadData ($) {
  my $tdp = ParseThreadID shift;
  return { 'error' => $tdp->{'error'} } if $tdp->{'error'};
  my (%data) = ('id' => $tdp->{'id'});
  $data{'path'} = $tdp->{'path'};
  if (!-e $tdp->{'path'}) {
    $data{'modtime'} = 0;
    $data{'data'} = '[]';
    }
  elsif (open my $fh, '<', $tdp->{'path'}) {
    local($/) = undef;
    $data{'modtime'} = ModTime $fh;
    $data{'data'} = scalar(<$fh>);
    }
  else { 
    $data{'error'} = "Cannot open $tdp->{'path'}: $!";
    }
  return \%data;
  }

sub LogDeletedComment ($) {
  my $comment = shift;
  open my $fh, '>>', "$config::phiz_directory/deleted.txt" or die "Cannot log deletion: $!";
  print $fh time, ' ', $poslid_user, ' ', $comment, "\n";
  }

sub Main () {
  my $action = 'update';
  my $error = '';
  my $info = '';
  my $logged_in = 0;
  my $new_password = param('np');
  my $since = param('s') || 0;
  my $username = param('u');
  warn "QUERY: ".join('; ', map { "$_: " . param($_) } param());
  # spoof PoslID API
  if (defined $username) {
    if ($username eq '') {
      $action = 'logout';
      param('poslid_logout', 1);
      }
    else {
      $action = 'login';
      param('username', $username);
      param('password', param('p'));
      param('poslid_submit_login', 1);
      }
    }
  Authenticate;
  if (defined $poslid_user) {
    $username = $poslid_user;
    $real_name = RealName($username);
    $logged_in = 1;
    if (defined $new_password) {
      if (PoslID::ValidatePassword($poslid_user, param('op'))) {
	if (PoslID::SetPassword($poslid_user, $new_password)) {
	  $error = 'You have changed your password.';
	  }
	else {
	  $error = 'Your password could not be changed. Please contact the event administrator.';
	  }
        }
      else {
	$error = 'You did not enter your old password correctly. Please try again.';
        }
      }
    }
  elsif ($action eq 'login') {
    $error = 'That username and password do not match. Please try again, or contact the event administrator for assistance.';
    }
  my $active_thread = param('at') || '';
# warn "active thread is $active_thread, error is $error";
  TryAddComment $error if $logged_in;
  TryDelComment $error if $logged_in;
  $username = JSEscape $username;
  $error = JSEscape $error;
  $info = JSEscape $info;
  my $realname = JSEscape $real_name;
  local($") = ',';
  my (@threads) = map { 
    my $tdp = LoadThreadData $_;
    my $thread_error = $tdp->{'error'};
    if ($tdp->{'id'} eq $active_thread) {
      $thread_error ||= $error;
#     warn "matched active thread $active_thread, error is now $thread_error";
      }
    else {
#     warn "$tdp->{'id'} != active thread $active_thread";
      }
    '"'.JSEscape($tdp->{'id'}).'":' . (
      $thread_error
	? '{"e":"' . JSEscape($thread_error) . '"}'
	: ($tdp->{'data'} eq '[]' || $tdp->{'modtime'} > $since)
	  ? "{\"m\":$tdp->{'modtime'},\"c\":$tdp->{'data'}}"
	  : "{\"m\":\"nc\"}"
      );
    } split(/,/, param('t') || '');
  my $js = <<"EOF";
{"u":"$username","r":"$realname","p":"","t":{@threads},"l":$logged_in}
EOF
  warn "RESPONSE: $js";
  print $js;
  }

sub ParseThreadID ($) {
  my $id = shift;
  my $orig = $id;
  my %data;
  $data{'id'} = $id;
  $data{'event'} = $1 if $id =~ s/^E([^_]+)_*//;
  $data{'division'} = $1 if $id =~ s/^D([^_]+)_*//;
  $data{'round'} = $1 if $id =~ s/^R([^_]+)_*//;
  $data{'players'} = [sort { $a <=> $b } grep { /^\d+$/ } split(/_/, $1)] if $id =~ s/PB_(.*)_PE//;
  $data{'players'} ||= [];
  unless ($data{'event'} && (!($config::division_required) || $data{'division'}) && defined $data{'round'}) {
    $data{'error'} = "Incomplete ID: $orig";
    }
  if ($id =~ /\S/) { 
    $data{'error'} = "Cannot parse: $id";
    }
  else {
    my $p = $config::phiz_directory;
    $p .= "/$data{'event'}" if defined $data{'event'};
    $p .= "/$data{'division'}" if defined $data{'division'};
    $p .= "/$data{'round'}" if defined $data{'round'};
    my $psp = $data{'players'};
    if (@$psp) {
      $p .= '/' . join('_', @$psp) . '.js';
      }
    else {
      $p .= '/all.js';
      }
    $data{'path'} = $p;
    }
  return \%data;
  }

sub RealName ($) {
  my $id = shift;
  return (DBGet "$config::phiz_directory/realname", $id) || "Not found: $id";
  }

sub SanitizeAttributes ($$$) {
  my $slash = shift;
  my $tag = shift;
  my $attrs = shift;
  return '' if $slash;
  my $s = '';
  while ($attrs =~ s/^( \w+=(?:"[^"]+"|\w+))//) {
    $s .= $1;
    }
  return $s;
  }

sub SanitizeContent ($) {
  local ($_) = shift;
  s/<[^>]*>/&SanitizeTag($&)/ge;
  return $_;
  }

sub SanitizeTag ($) {
  local ($_) = shift;
  if (/^<(\/?)(a|b|br|div|em|font|i|li|ol|p|span|ul|u)\b([^>]*)>$/i) {
    $_ = '<' . $1 . $2 . SanitizeAttributes($1,$2,$3) . '>';
    }
  else {
    s/</&lt;/g;
    s/>/&gt;/g;
    }
  return $_;
  }

sub SaveThreadData ($$) {
  my $id = shift;
  my $datap = shift;

  length($datap->{'path'}||'')
    or return "No path to comment file, please contact event administrator";
  open my $fh, '>', $datap->{'path'}
    or return "Unexpected error saving comment file to $datap->{'path'} ($!), please contact event administrator";
  flock($fh, LOCK_EX)
    or return "Unexpected error locking comment file ($!), please contact event administrator";
  print $fh $datap->{'data'}
    or return "Unexpected error writing to comment file ($!), please contact event administrator";
  close $fh 
    or return "Unexpected error closing comment file ($!), please contact event administrator";
  return '';
  }

sub TryAddComment ($) {
  return unless param('nc');
  my $datap = AddComment;
  if ($datap->{'error'}) { 
    $_[0] = $datap->{'error'}; 
    warn "AddComment: $_[0]";
    }
  else {
    warn "AddComment: ok";
    }
  }

sub TryDelComment ($) {
  return unless param('di');
  my $datap = DelComment;
  if ($datap->{'error'}) { 
    $_[0] = $datap->{'error'}; 
    warn "DelComment: $_[0]";
    }
  else {
    warn "DelComment: ok";
    }
  }

