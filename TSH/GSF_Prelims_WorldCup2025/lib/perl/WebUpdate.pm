#!/usr/bin/perl

# Copyright (C) 2008-2012 John J. Chew, III <jjchew@math.utoronto.ca>
# All Rights Reserved

package WebUpdate;

use strict;
use warnings;

use File::Path;
use File::Spec;
BEGIN {
  if ($^O eq 'MSWin32') {
    eval "use Win32::Internet";
    }
  else {
    eval "use HTTP::Client";
    }
  }

# my $gUserAgent = "tsh-update/$main::gkVersion";
my $gUserAgent = "Mozilla/5.0 (poslfit; TSH)"; # siteocity can fail otherwise

sub lint () { &lint; $main::gkVersion; }

=pod

=head1 NAME

WebUpdate - update a set of files from a web server

=head1 SYNOPSIS

  # update all files listed in manifest
  my $wup = new WebUpdate(
    'server' => $server,
    'basepath' => $basepath,
    'manifest' => $manifest_name,
    # see below for other options
    );
  $wup->Update();

  # update a single file based on reported modification time
  my $wup2 = new WebUpdate(
    'server' => $server,
    'basepath' => $basepath,
    'filename' => $filename,
    # see below for other options
    );
  
=head1 ABSTRACT

This Perl module is used to update a set of local files from
content served on a web server.

=head1 DESCRIPTION

=over 4

=cut

sub CheckDirectory ($$);
sub GetFile ($$);
sub GetLocalManifest ($$);
sub GetRemoteManifest ($$);
sub GetHTTP ($$$);
sub GetHTTPS ($$$);
sub new ($@);
sub ParseManifest ($$);
sub Update ($);
sub UpdateFile ($$$$$);

sub CheckDirectory ($$) {
  my $this = shift;
  my $file = shift;
  my ($v, $d, $f) = File::Spec->splitpath($file);
  my $dir = File::Spec->catpath($v, $d, '');
  return unless $dir =~ /\S/;
  mkpath $dir, 0, 0755;
  }

sub Die ($$$@) {
  my $this = shift;
  $this->Warn(@_);
  die "Fatal error";
  }

sub GetFile ($$) {
  my $this = shift;
  my $path = shift;
  if ($path =~ /\?/) { $path .= '&posl_nocache='.rand }
  else { $path .= '?' . rand } # necessary to defeat some caches
  if ($this->{'secure'}) { 
    if ($^O eq 'MSWin32') {
      return $this->GetFileWin32($path); 
      }
    else {
      return $this->GetHTTPS($this->{'server'}, $path);
      }
    }
  if ($^O eq 'MSWin32') {
    # could switch to using GetFileWin32 when fully tested
    my $fn = "http://$this->{'server'}/$this->{'basepath'}/$path";
    my $file = Win32FetchURLUncached($this->{'win32'}, $fn);
#   my ($line) = $file =~ /(.*mirror-ftp[^\.].*)/;
#   warn $fn . "\n" . $line . "\n" . substr($file, 0, 320);
#   sleep 60;
#   die;
    unless ($file) {
      $this->Warn('ewuef', q(Server sent us an empty file for %s.  You may have briefly lost your Internet connection.  Check it and rerun the update.), $path);
      return undef;
      }
    if ($file =~ /<title>(\d\d\d .*?)<\/title>/i
      || $file =~ /^\s*(\d\d\d [A-Z].*?)/) {
      print "This looks like a server problem: $1\n";
      return undef;
      }
    return $file;
    }
  return $this->GetHTTP($this->{'server'}, 
    length($this->{'basepath'}) ? "$this->{'basepath'}/$path" : $path);
  }

sub GetFileWin32 ($$) {
  my $this = shift;
  my $path = shift;
  die "Assertion failed" unless $^O eq 'MSWin32';
# warn "this code not yet tested";
  my %param;
  my $request;
  my $socket;
  unless ($this->{'win32'}->HTTP($socket, {
    'server' => $this->{'server'},
    'port' => $this->{'port'},
    })) {
    print "Could not connect to $this->{'server'}:$this->{'port'}. Error " . $this->{'win32'}->Error() . "\n";
    return undef;
    }
  $param{'path'} = $this->{'post'} 
    ? $this->{'serverpath'} : "$this->{'basepath'}/$path";
  $param{'method'} = 'POST' if $this->{'post'};
# $param{'flags'} = &INTERNET_FLAG_SECURE if $this->{'secure'};
  $param{'flags'} = 0x00800000 if $this->{'secure'};
  unless ($socket->OpenRequest($request, \%param)) {
    print "OpenRequest() failed.\n";
    return undef;
    }
  my $message_text = '';
  if ($this->{'post'}) {
    my $message = eval "new HTTP::Message";
    my $headers;
    my (%form) = %{$this->{'post'}};
    $form{'file'} = "$this->{'basepath'}/$path";
    eval "use HTTP::Message"; # TODO: move to top of file
    $message->Header('content-type', 'multipart/form-data'); 
    $message->FormData(\%form);
    warn "should try omitting content-length";
    ($headers, $message_text) = split(/\015\012\015\012/, $message->ToString(), 2);
    for my $header (split(/\015\012/, $headers)) {
      $request->AddHeader($header) if $header =~ /:/;
      }
    }
  $request->SendRequest($message_text);

  my $file = '';
  if ($this->RequestSucceeded($request->QueryInfo('', &HTTP_QUERY_STATUS_CODE), $path)) {
    $file = $request->ReadEntireFile();
    $request->Close();
    $socket->Close();
    }
  else {
    $request->Close();
    $socket->Close();
    return undef;
    }

  unless ($file) {
    $this->Warn('ewuef', q(Server sent us an empty file for %s.  You may have briefly lost your Internet connection.  Check it and rerun the update.), $path);
    return undef;
    }
  if ($file =~ /<title>(\d\d\d .*?)<\/title>/i
    || $file =~ /^\s*(\d\d\d [A-Z].*?)/) {
    print "This looks like a server problem: $1\n";
    return undef;
    }
  return $file;
  }

sub GetHTTP($$$) {
  my $this = shift;
  my $server = shift;
  my $path = shift;
  $path = "/$path" unless $path =~ m!^/!;

# warn "GetHTTP($this, $server, $path)";
  my $http = eval "new HTTP::Client('exit_on_error'=>0)";
  # should internationalize the following message
  die "can't new HTTP::Client: $@" if $@;
  $http->Connect($server);
  my $request = ''
    ."GET $path HTTP/1.1\015\012"
    ."Host: $server\015\012"
    ."Accept-Charset: iso-8859-1\015\012"
    ."Accept-Encoding: identity\015\012"
    ."User-Agent: $gUserAgent\015\012"
    ."Connection: close\015\012"
    ."\015\012";
# warn $request;
  $http->SendRaw($request);
  my $response = $http->Receive();
  $http->Close();
  if ($response->StatusCode && $response->StatusCode =~ /^30[12357]$/) {
    my $location = $response->Header('location');
    my $protocol;
    ($protocol, $server, $path) = $location 
      =~ /^(https?):\/\/([^\/]+)(.*)/;
    unless (defined $path) {
      print "Bad redirect: $location\n";
      return undef;
      }
    if ($protocol eq 'http') {
      return GetHTTP($this, $server, $path); # not OO, to permit isolated use
      }
    else {
      my $wups = new WebUpdate(
	'server' => $this->{'server'},
#	'basepath' => $this->{'basepath'},
 	'basepath' => '',
	'localpath' => $this->{'localpath'},
	'secure' => 1,
	);
      return $wups->GetHTTPS($server, $path);
      }
    }
  if (my $error = $response->Error()) {
    print "Can't get http://$server$path: $error\n";
    return undef;
    }
  my $html = $response->Body();
  if ($html =~ /^(\d\d\d [A-Z].*)/) {
    print "Can't get http://$server$path: $1\n";
    return undef;
    }
  return $html;
  }
  
sub GetHTTPS ($$$) {
  my $this = shift;
  my $server = shift;
  my $path = shift;
  die "Assertion failed" unless $this->{'secure'};
  $path = "/$path" unless $path =~ m!^/!;

  my $http = eval "new HTTP::Client";
  # should internationalize the following message
  die "can't new HTTP::Client: $@" if $@;
  $http->ConnectSecure(
    'PeerAddr' => $server,
    'PeerPort' => $this->{'port'},
    );
  my %param;
  $param{'method'} = $this->{'post'} ? 'POST' : 'GET';
  $param{'url'} = $this->{'post'} 
    ? $this->{'serverpath'} : "$this->{'basepath'}/$path";
  my $request = new HTTP::Message(%param);
  $request->Header('Host', $server);
  $request->Header('Accept-Charset', 'iso-8859-1');
  $request->Header('Accept-Encoding', '');
  $request->Header('User-Agent', $gUserAgent);
  $request->Header('Content-Type', 'multipart/form-data');
  if ($this->{'post'}) {
    my (%form) = %{$this->{'post'}};
    $form{'file'} = "$this->{'basepath'}/$path";
    $request->FormData(\%form);
    }
  $http->Send($request);
  my $response = $http->Receive();
  $http->Close();
# warn $response->StatusCode . ' ' . $response->{'reason-phrase'};
  if (my $status = $response->StatusCode) {
    if ($status =~ /^30[1237]$/) {
      my $location = $response->Header('location');
      my $protocol;
      ($protocol, $server, $path) = $location 
	=~ /^(https?):\/\/([^\/]+)(.*)/;
      unless (defined $path) {
	print "Bad redirect: $location\n";
	return undef;
	}
      if ($protocol eq 'https') {
	return $this->GetHTTPS($server, $path);
	}
      else {
	my $wup = new WebUpdate(
	  'server' => $this->{'server'},
	  'basepath' => $this->{'basepath'},
	  'localpath' => $this->{'localpath'},
	  'secure' => 0,
	  );
	return $wup->GetHTTP($server, $path);
        }
      }
    return undef unless $this->RequestSucceeded($status, $path);
    }
  if (my $error = $response->Error()) {
    print "Can't get https://$server$path: $error\n";
    return undef;
    }
  my $html = $response->Body();
# warn "body: $html";
  if ($html =~ /^(\d\d\d [A-Z].*)/) {
    print "Can't get https://$server$path: $1\n";
    return undef;
    }
  $http->Close();
  return $html;
  }

sub GetLocalManifest ($$) {
  my $this = shift;
  my $fn = $this->MakeLocalPath(shift);
  local($/) = undef;
# warn "opening local manifest $fn";
  open my $fh, "<$fn" or return {};
  my $text = <$fh>;
  close $fh;
# print $text;
  return $this->ParseManifest($text);
  }

sub GetRemoteManifest ($$) {
  my $this = shift;
  my $fn = shift;
  $this->Warn('iwufm', q(Fetching remote manifest file '%s'.), $fn);
  my $text = $this->GetFile($fn);
  unless (defined $text) { return undef; }
  return $this->ParseManifest($text);
  }

sub MakeLocalPath ($$) {
  my $this = shift;
  my $path = shift;
  my $localpath = $this->{'localpath'};
  $path = File::Spec->catfile($localpath, $path) if length($localpath);
  return $path;
  }

=item $wup = new WebUpdate(%params);

Create a new WebUpdate object or return undef on failure.
Required parameters:

C<basepath>: relative path to remote copy on server

C<localpath>: relative path to local copy in tsh folder

C<server>: HTTP/HTTPS server hostname.

C<serverpath>: (required iff C<post> is specified) (HTTPS only for now) path to server script

Additional optional parameters are as follows.

C<manifest>: name of manifest file (default: MANIFEST.txt).

C<port>: (HTTPS only for now) if set, connect to a non-default server port.

C<post>: (HTTPS only for now) if present, should give a reference to a hash of parameters to accompany a POST request.

C<secure>: if true, connect using HTTPS instead of default HTTP.

C<tourney>: if provided, internationalized diagnostic messages will be sent through this object.

=cut

sub new ($@) {
  my $proto = shift;
  my (%args) = @_;
  my $class = ref($proto) || $proto;
# my $this = $class->SUPER::new();
  my $this = bless {
    'basepath' => undef,
    'filename' => undef,
    'localpath' => undef,
    'manifest' => 'MANIFEST.txt',
    'port' => undef,
    'post' => undef,
    'secure' => undef,
    'server' => undef,
    'serverpath' => undef,
    'tourney' => undef,
    }, $class;
  for my $key (keys %$this) {
    $this->{$key} = $args{$key} if exists $args{$key};
    }
  for my $key (qw(basepath localpath server)) {
    unless (defined $this->{$key}) {
      $this->Die('ewunop', q(Missing required parameter '%s' for WebUpdate.), $key);
      return undef;
      }
    }
  if ($this->{'post'} && !defined $this->{'serverpath'}) {
    $this->Die('ewunop', q(Missing required parameter '%s' for WebUpdate.), 'serverpath');
    return undef;
    }
  $this->{'port'} ||= $this->{'secure'} ? 443 : 80;
  eval {
    $this->{'win32'} = new Win32::Internet({'useragent' => $gUserAgent}) if $^O eq 'MSWin32';
    };
  if ($@ and $@ =~ /Win32::Internet/) {
    die "Cannot use the Win32::Internet module.\n".
        "If you are using a modern version of ActivePerl for Windows, the\n".
	"best thing for you to do is to switch to using Strawberry Perl,\n".
	"as ActivePerl has dropped support for many essential modules.\n\n".
	"As of 2022, Strawberry Perl does not include this module by default,\n".
	"but you can install it by opening a new DOS command window and entering:\n".
	"  cpan install Win32::Internet\n\n".
	"You would then need to rerun TSH.\n\n".
	"Here is the full text of the error message.\n\n$@";
    }
  return $this;
  }

sub ParseManifest ($$) {
  my $this = shift;
  my $lines = shift;
  my %data;

  for my $line (split(/\n/, $lines)) {
    next if $line =~ /^(?:Archive| +Length +Date|[- ]+$| +\d+ +\d+ files$)/;
    $line =~ s/^\s+//; $line =~ s/\+$//;
    my ($length, $date, $time, $file) = split(/\s+/, $line, 4);
    unless (defined $file) {
      $this->Warn('ewubl', q(Can't parse: '%s'.), $line);
      return undef;
      }
    $data{$file} = "$length $date $time";
    }
  return \%data;
  }

sub RequestSucceeded ($$$) {
  my $this = shift;
  my $status = shift;
  my $path = shift;
  if ($status eq '401') {
    $this->Warn('ewu401', q(Authorization denied for file '%s'.), $path);
    return undef;
    }
  if ($status =~ /^[45]/) {
    print "Server replied with a code $status error.\n";
#   eval "use Carp; confess $status"; warn $@; exit 1;
    return undef;
    }
  return 'ok';
  }

sub Update ($) {
  my $this = shift;

  if ($this->{'filename'}) {
    return $this->UpdateOne();
    }

  my $localsp = $this->GetLocalManifest($this->{'manifest'});
  unless (keys %$localsp) {
    print "No local manifest.\n";
    }
# warn join("\n", keys %$localsp);
  my $remotesp = eval { $this->GetRemoteManifest($this->{'manifest'}) };
  unless ($remotesp) {
    print "No remote manifest.\n";
    return -1;
    }
  $this->Warn('iwucm', q(Checking manifest file.));
  my $found_something;
  my $did_something = 0;
  for my $file (sort keys %$remotesp) {
    $found_something++;
    my $path = $this->MakeLocalPath($file);
#   warn "$localsp->{$file} vs. $remotesp->{$file}" if $file =~ /mirror-ftp/;
    if ((!-e $path) || (!exists $localsp->{$file}) 
      || $localsp->{$file} ne $remotesp->{$file}) { 
      if ($path =~ /\/$/) {
	unless (-d $path) {
	  print "Creating directory $path\n";
	  mkdir $path || warn "mkdir() failed: $!\n";
	  $did_something++;
	  }
	}
      else {
	$this->UpdateFile($file, $remotesp->{$file}, $localsp, $path) 
	  or return -1;
	$did_something++;
	}
      }
    else {
#     warn "$file is up-to-date\n";
      }
    }
  unless ($found_something) {
    print "Empty manifest file received: are you behind a firewall?\n";
    return -1;
    }
  return $did_something;
  }

sub UpdateFile ($$$$$) {
  my $this = shift;
  my $file = shift;
  my $remotedata = shift;
  my $localsp = shift;
  my $path = shift;
  
  $this->Warn('iwuuf', q(Updating %s.), $file);
  my $content = $this->GetFile($file);
  unless (defined $content) {
    return 0;
    }
  if ($path =~ /\.(?:pl|pm)$/) {
    if ($content !~ /^#!.*perl/) {
      warn "Received content for $path does not look like a Perl script: it looks like something is inserting content into your Internet downloads.\n";
      return 0;
      }
    }
  $localsp->{$file} = $remotedata;
  $this->CheckDirectory($path);
  my $fh;
  unless (open $fh, ">$path-new") {
    print "Can't create $path-new: $!\n";
    return 0;
    }
  if ($path =~ /\.(?:doc|dwg|gif|ico|jpg|jpeg|zip)$/) {
    binmode $fh;
    }
  unless (print $fh $content) {
    print "Can't write to $path-new: $!\n";
    return 0;
    }
  unless (close $fh) {
    print "Can't close $path-new: $!\n";
    return 0;
    }
  for my $try (1..5) {
    last if rename "$path-new", $path;
    if ($! eq 'Permission denied') {
      warn "Permission denied renaming $path-new to $path: do you have a virus scanner running? Try #$try/5";
      sleep 1;
      next;
      }
    print "Can't update $path (rename failed: $!)\n";
    return 0;
    }
  if ($path =~ /^(?:bin|util)\/|^(?:get-tsh|tourney|tsh)\.pl$|^osx-tsh\.command$/ && $path !~ /\.(?:hlp|txt)$/) {
    unless (chmod 0755, $path) {
      print "chmod $path failed: $!\n";
      return 0;
      }
    }
  $fh = undef;
  $path = $this->MakeLocalPath($this->{'manifest'});
  unless (open $fh, ">$path") {
    print "Can't creat $path: $!\n";
    return 0;
    }
  unless (print $fh map { qq($localsp->{$_} $_\n) } sort keys %$localsp) {
    print "Can't write to $path: $!\n";
    return 0;
    }
  unless (close $fh) {
    print "Can't close $path: $!\n";
    return 0;
    }
  return 1;
  }

sub UpdateOne ($) {
  my $this = shift;
  }

sub Warn ($$$@) {
  my $this = shift;
  my $code = shift;
  my $text = shift;
  my (@argv) = @_;

  if (my $tourney = $this->{'tourney'}) {
    $tourney->TellUser($code, @argv);
    }
  else {
    $text =~ s/\s*$/\n/;
    printf $text, @argv;
    return;
    }
  }

sub Win32FetchURLUncached ($$) {
  my $win32 = shift;
  my $url = shift;
#   $url =~ s/tsh\.poslfit\.com/poslarchive.com\/tsh/;
#   warn $url;
  my $flags = 
    0x100 | # INTERNET_FLAG_PRAGMA_NOCACHE
    0x80000000; # INTERNET_FLAG_RELOAD
  if (my $h = Win32::Internet::InternetOpenUrl($win32->{'handle'}, $url, "", 0, $flags, 0)) {
    my $content = Win32::Internet::ReadEntireFile($h);
    Win32::Internet::InternetCloseHandle($h);
    return $content;
    }
  else {
    my $error = Win32::GetLastError();
    if ($error == 12007) { $error .= " (cannot fetch webpage, check Internet connection)"; }
    elsif ($error == 12039) { $error .= " (Windows is configured to crash apps that try to upgrade web connection security. Go to Start Menu > Control Panel > Internet Options > Advanced, scroll to the bottom, deselect 'Warn if changing between secure and not secure mode', click 'OK', then rerun TSH."; }
    warn $win32->{'Error'} = "Windows Error #$error";
    return undef;
    }
  }

=back

=head1 BUGS

Should use persistent HTTP connections.

Should consistently use TellUser().

=cut

1;
