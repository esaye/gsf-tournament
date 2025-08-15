#!/usr/bin/perl

# Copyright (C) 2005 John J. Chew, III <jjchew@math.utoronto.ca>
# All Rights Reserved

package HTTP;

=pod

=head1 NAME

HTTP - HTTP Class

=head1 SYNOPSIS

  my $http = new HTTP;
  $http->Connect($server) or die;
  my ($boundary, $entity_body) = HTTP::EncodeMultipartFormData (
    'plain_field_name' => $field_value,
    'file_field_name' => { 'type' => 'file',
      'filename' => $filename,
      'data' => $data,
      },
    );
  $http->PutRaw(''
    ."POST $path HTTP/1.1\015\012"
    ."Host: $server\015\012"
    ."Accept-Charset: iso-8859-1\015\012"
    ."Accept-Encoding:\015\012"
    ."User-Agent: poslfit\015\012"
    ."Content-Length: " . length($entity_body) . "\015\012"
    ."Content-Type: multipart/form-data; boundary=$boundary\015\012"
    ."\015\012"
    . $entity_body
    );
  my $response = $http->GetResponse();
  $http->Close();
  if (my $error = $response->Error()) {
    print "$error\n";
    }
  my $html = $response->Body();
  
=head1 ABSTRACT

This Perl library is an interface class for the HyperText Transfer
Protocol, usually used to communicate between a web client and web server.  

=head1 DESCRIPTION

=over 4

=cut

use Fcntl qw(F_GETFL F_SETFL O_NONBLOCK);
use Socket;
use Symbol;


sub new ($@);
sub Close($);
sub Connect ($$);
sub Die ($$);
sub EncodeMultipartFormData (@);
sub GetResponse($);
sub PutRaw ($$);

=item $hp = new HTTP($key1 => $value1, ...);

Create a new HTTP object.  
All parameter keys are optional.
C<exit_on_error> gives a boolean value specifying whether or not to
exit on any error.

=cut

sub new ($@) {
  my $proto = shift;
  my $class = ref($proto) || $proto;
# my $this = $class->SUPER::new();
  my $this = {
    'state' => 'init',
    'exit_on_error' => 1,
    };
  my %param = @_;
  for my $key (qw(exit_on_error)) {
    if (exists $param{$key}) { $this->{$key} = $param{$key}; }
    elsif (!exists $this->{$key}) {
      die "Missing required parameter ($key).";
      }
    }
  
  bless($this, $class);
  return $this;
  }

=item $success = $mp->Close();

Closes the HTTP connection, which cannot be used again until it is
reopened.  
Fails only if the connection was not open to begin with.

=cut

sub Close ($) {
  my $this = shift;
  
  return undef if $this->{'state'} eq 'error';
  if ($this->{'state'} ne 'open') 
    { $this->Die("Connection is not open"); return undef; }
  $this->{'state'} = 'init';
  return 1;
  }

=item $success = $hp->Connect($hostname);

Opens a connection to the named host.

=cut

sub Connect ($$) {
  my $this = shift;
  my $hostname = shift;

  return undef if $this->{'state'} eq 'error';
  if ($this->{'state'} ne 'init') 
    { $this->Die("Connection is already open"); return undef; }

  my $serveraddress = gethostbyname($hostname)
    or $this->Die("Can't find $hostname: $!");
  my $sfh = $this->{'socket'} = gensym;
  socket($sfh, PF_INET, SOCK_STREAM, getprotobyname('tcp')) 
    or $this->Die("Couldn't create socket for web connection: $!");
  # bind($sfh, sockaddr_in(0, "\0\0\0\0")) 
  #   or $this->Die("Couldn't bind socket for web connection: $!");
  connect($sfh, sockaddr_in(80, $serveraddress)) 
    or $this->Die("Couldn't connect to web server: $!");
  {
    my $flags;
    $flags = fcntl($sfh, F_GETFL, 0)
      or $this->Die("Can't get socket flags for web connection: $!");
    fcntl($sfh, F_SETFL, $flags | O_NONBLOCK) 
      or $this->Die("Can't set socket flags for web connection: $!");
  }
  $this->{'state'} = 'open';
  return 1;
  }

=item $hp->Die($message);

Sets the module error message and exits if C<exit_on_error> was set.

=cut

sub Die ($$) { 
  my $this = shift;
  my $message = shift;
  $this->{'error'} = $message;
  $this->{'state'} = 'error';
  print STDERR $message;
  exit 1 if $this->{'exit_on_error'};
  }

=item ($boundary, $entity_body) = $hp->EncodeMultipartFormData($key1 => $value1, ...);

Encodes a hash as multipart/form-data.
Used in creating a message to POST to a web server,
using the contents of a form that includes a file upload.

=cut

sub EncodeMultipartFormData (@) {
  my @data;
  my (%data) = @_;
  my $boundary = 'posl--';
  while (my ($key, $value) = each %data) {
    if (ref($value) eq 'HASH') {
      if ($value->{'type'} eq 'file') {
	push(@data, 
	  qq(Content-Disposition: form-data; name="$key"; filename="$value->{'filename'}\015\012\015\012)
	  . "$value->{'data'}\015\012");
        }
      else {
	die "Unknown form data type: $value->{'type'}\n";
        }
      }
    else {
      while ($value =~ /--$boundary/) {
	$boundary .= chr(97 + int(rand(26)));
        }
      push(@data,
	qq(Content-Disposition: form-data; name="$key"\015\012\015\012)
	. "$value\015\012");
      }
    }
  return ($boundary, join("--$boundary\015\012", '', @data, ''));
  }

=item $message = $mp->GetResponse();

Reads an HTTP message (as a C<HTTP::Message>) from an open 
connection, returns undef or dies on failure.

=cut

sub GetResponse ($) {
  my $this = shift;

  return undef if $this->{'state'} eq 'error';
  if ($this->{'state'} ne 'open') 
    { $this->Die("Connection is not open"); return undef; }

  return HTTP::Message->new('handle' => $this->{'socket'});
  }

=item $success = $mp->PutRaw($request);

Writes text to an open connection.

=cut

sub PutRaw ($$) {
  my $this = shift;
  my $request = shift;

  return undef if $this->{'state'} eq 'error';
  if ($this->{'state'} ne 'open') 
    { $this->Die("Connection is not open"); return undef; }

  my $old = select($this->{'socket'});
  $| = 1;
  print $request;
  select $old;
# print "[begin request]\n$request\n[end request]\n";

  return 1;
  }

=back

=cut

1;
#!/usr/bin/perl

# Copyright (C) 2005 John J. Chew, III <jjchew@math.utoronto.ca>
# All Rights Reserved

package HTTP::Message;

=pod

=head1 Name

HTTPMessage -  HTTP Message Class

=head1 SYNOPSIS

  $mp = new HTTP::Message ('handle' => $this->{'socket'});
  $te = $mp->MessageHeader('transfer-encoding');
  $body = $mp->Body();


=head1 ABSTRACT

This Perl library is an abstraction of an HTTP message.  HTTP messages
are used to communicate between a web client and web server.  

=head1 DESCRIPTION

=over 4

=cut

sub new ($@);
sub Body ($);
sub Die ($$);
sub Error ($;$);
sub GetFromHandle ($$);
sub MessageHeader ($$;$);
sub ParseHeader ($$);
sub StatusCode ($;$);

=item $mp = new HTTPMessage($key1 => $value1, ...);

Create a new HTTPMessage object.  
All parameter keys are optional.
C<body> gives the message body as a string.
C<error> sets the current module error message.
C<handle> gives a handle from which to read the message.
C<message-headers> gives the message headers as a hash.

=cut

sub new ($@) {
  my $proto = shift;
  my $class = ref($proto) || $proto;
# my $this = $class->SUPER::new();
  my $this = {
    'body' => '',
    'error' => '',
    'message-headers' => {},
    };
  my %param = @_;
  for my $key (qw(body message-headers)) {
    if (exists $param{$key}) { $this->{$key} = $param{$key}; }
    elsif (!exists $this->{$key}) {
      die "Missing required parameter ($key).";
      }
    }
  bless($this, $class);

  if ($param{'handle'}) {
    $this->GetFromHandle($param{'handle'});
    }
  
  return $this;
  }

=item $body = $mp->Body();

Returns the body of an HTTP message.

=cut

sub Body ($) { my $this = shift; return $this->{'body'}; }

=item $mp->Die($error);

Sets the module error message and returns undef.
Could be overridden to invoke the builtin C<die>.

=cut

sub Die ($$) {
  my $this = shift;
  my $message = shift;

  $this->{'error'} = $message;
  return undef;
  }

=item $mp->Error($error);

=item $error = $mp->Error();

Sets and/or gets the module error message.

=cut

sub Error ($;$) {
  my $this = shift;
  my $message = shift;
  if (defined $message) 
    { return $this->{'error'} = $message; }
  else 
    { return $this->{'error'}; }
  }

=item $mp = $mp->GetFromHandle($fh);

Reads a message from a file handle using the C<sysread()>.
Sets error on error.

=cut

sub GetFromHandle ($$) {
  my $this = shift;
  my $handle = shift;

  my $buffer = '';
  my $count;
  my $rv;

  while ($buffer !~ /\015\012\015\012/) {
    $rv = sysread($handle, $buffer, 1024, length($buffer));
    next unless defined $rv; # likely no data available yet
    last unless $rv; # EOF
    }
  # parse header
  $this->ParseHeader($buffer)
    or $this->Die("Web server returned malformed header") or return $this;
# print substr($buffer, 0, $this->{'header-size'});
  if ($this->{'status-code'} != 200) {
    $this->Die("Web server request failed: $this->{'status-code'} $this->{'reason-phrase'}");
    return $this;
    }
  # remove header from buffer
  substr($buffer, 0, $this->{'header-size'}) = '';
  # if the message body length is explicitly specified
  if (my $content_length = $this->MessageHeader('content-length')) {
#   warn "content-length: $content_length\n";
    while (length($buffer) < $content_length) {
      $rv = sysread($handle, $buffer, 
	$content_length-length($buffer), length($buffer));
      next unless defined $rv; # likely no data available yet
      last unless $rv; # EOF
      }
    if (length($buffer) < $content_length) {
      $this->Die("Web server response was truncated");
      return $this;
      }
    $this->{'body'} = $buffer;
    }
  # else if a transfer encoding is given
  elsif (my $transfer_encoding = $this->MessageHeader('transfer-encoding')) {
#   warn "transfer-encoding: $transfer_encoding\n";
    if ($transfer_encoding eq 'chunked') {
      my $body = '';
      while (1) {
	# TODO: process transfer encoding extensions
#	print substr($buffer, 0, 80);
	my $chunk_size;
	while (1) {
          if ($buffer =~ s/^([0-9a-f]+)[^\015\012]*\015\012//i) {
	    $chunk_size = $1;
	    last;
	    }
#while ($buffer !~ s/^([0-9a-f]+)[^\015\012]*\015\012//i) {
#	  print "going back for more.\n";
#	  print "buffer: $buffer\n";
#	  sleep 1;
	  $rv = sysread($handle, $buffer, 1024, length($buffer));
	  next unless defined $rv; # likely no data available yet
	  last unless $rv; # EOF
	  }
	if (length($buffer) && !defined $chunk_size) {
	  $this->Die("Web server response was badly chunked\n$buffer");
	  return $this;
	  }
#	print "chunk_size: $chunk_size\n";
	last unless $chunk_size;
	$chunk_size = hex($chunk_size);
	while (length($buffer) < $chunk_size + 2) {
	  $rv = sysread($handle, $buffer, 
	    $chunk_size + 2 - length($buffer), length($buffer));
	  next unless defined $rv; # likely no data available yet
	  last unless $rv; # EOF
	  }
#        print "chunk: $buffer\n";
	$body .= substr($buffer, 0, $chunk_size);
	if (length($buffer) < $chunk_size + 2) {
	  $this->Die("Web server response was truncated");
	  return $this;
	  }
	else {
	  substr($buffer, 0, $chunk_size + 2) = '';
	  }
	}
      $this->{'body'} = $body;
      }
    else {
      $this->Die("Unsupported transfer encoding: $transfer_encoding");
      return $this;
      }
    }
  # no message body will be present
  else {
#   warn "no body\n";
    $this->{'body'} = '';
    }
  return $this;
  }

=item $mp->MessageHeader($field_name, $field_value);

=item $field_value = $mp->MessageHeader($field_name);

Sets and/or gets an individual message header.

=cut

sub MessageHeader ($$;$) {
  my $this = shift;
  my $field_name = shift;
  my $field_value = shift;
  if (defined $field_value) 
    { return $this->{'message-headers'}{$field_name} = $field_value; }
  else 
    { return $this->{'message-headers'}{$field_name}; }
  }

=item $mp->ParseHeader($header)

Intended for internal use, this method parses a message header
and updates internal variables.

=cut

# intended for internal use
sub ParseHeader ($$) {
  my $this = shift;
  my $header = shift;

  $header =~ s/^(?:\015\012)+//;
  my $header_size = index $header, "\015\012\015\012";
  if ($header_size > 0) { $this->{'header-size'} = $header_size + 4; }
  else 
    { $this->Die("Web server did not return a complete header"); return undef; }
  my ($start_line, @message_headers) 
    = split(/\015\012/, substr($header, 0, $header_size));
  if ($start_line =~ /^HTTP\S+\s+(\d\d\d)\s+([^\015\012]*)/) {
    $this->{'status-code'} = $1;
    $this->{'reason-phrase'} = $2;
    }
  else { 
    $this->Die("Web server returned a bad start line: $start_line");
    return undef; 
    }

  for my $message_header (@message_headers) {
    my ($field_name, $field_value) = split(/:\s*/, $message_header, 2);
    $field_name = lc $field_name;
    if (defined $field_value) {
      if (exists $this->{'message-headers'}{$field_name}) {
	$this->{'message-headers'}{$field_name} .= ',' . $field_value;
        }
      else {
	$this->{'message-headers'}{$field_name} = $field_value;
        }
      }
    else {
      $this->Die("Web server returned a bad message header: $header"); 
      return undef; 
      }
    }
  return $this;
  }

=item $mp->StatusCode($status_code);

=item $status_code = $mp->StatusCode();

Sets and/or gets the message's status code.

=cut

sub StatusCode ($;$) {
  my $this = shift;
  my $message = shift;
  if (defined $message) 
    { return $this->{'status-code'} = $message; }
  else 
    { return $this->{'status-code'}; }
  }

=back

=head1 SEE ALSO

The current HTTP standard at www.w3.org.

=cut

1;

#!/usr/bin/perl

# update: fetch the most recent version of tsh from the web

# Copyright (C) 2005 John J. Chew, III <jjchew@math.utoronto.ca>
# All Rights Reserved

package main; # necessary because of how we build get-tsh.pl

use strict;
use warnings;
use vars qw($VERSION);

$config'server = 'tsh.poslfit.com';
$config'basepath = '';
$VERSION = '1.000';

use lib qw(lib/perl ../lib/perl);

sub CheckFile ($);
sub Die ($);
sub GetFile ($);
sub GetHTTP ($$);
sub GetLocalManifest ($);
sub GetRemoteManifest ($);
sub Main ();
sub ParseManifest ($);
sub UpdateFile ($$\%$);

BEGIN {
  if ($^O eq 'MSWin32') {
    eval "use Win32::Internet";
    die $@ if $@;
    $global'win32_internet = new Win32::Internet();
    }
  else {
    die $@ if $@;
    }
  }

Main;

sub CheckFile ($) {
  my $filep = shift;
  }

# using die() causes Windows to abort tsh
sub Die ($) {
  my $message = shift;
  print "$message\n";
  exit 0;
  }

sub GetFile ($) {
  my $path = shift;
  if ($^O eq 'MSWin32') {
    my $file = $global'win32_internet->FetchURL(
      "http://$config'server/$config'basepath/$path"
      );
    Die "Server sent us an empty file for $path"
      unless $file;
    Die "This looks like a server problem: $1"
      if $file =~ /<title>(\d\d\d .*?)<\/title>/i;
    return $file;
    }
  return GetHTTP $config'server, "$config'basepath/$path";
  }

sub GetHTTP($$) {
  my $server = shift;
  my $path = shift;

  my $http = new HTTP;
  $http->Connect($server);
  $http->PutRaw(''
    ."GET $path HTTP/1.1\015\012"
    ."Host: $server\015\012"
    ."Accept-Charset: iso-8859-1\015\012"
    ."Accept-Encoding:\015\012"
    ."User-Agent: tsh-update/$VERSION\015\012"
    ."\015\012"
    );
  my $response = $http->GetResponse();
  $http->Close();
  if ($response->StatusCode =~ /^301$/) {
    my $location = $response->MessageHeader('location');
    ($server, $path) = $location 
      =~ /^http:\/\/([^\/]+)(.*)/;
    Die "Bad redirect: $location\n" unless defined $path;
    return GetHTTP $server, $path;
    }
  if (my $error = $response->Error()) {
      Die "Can't get http://$server$path: $error\n";
    }
  my $html = $response->Body();
  return $html;
  }
  
sub GetLocalManifest ($) {
  my $fn = shift;
  local($/) = undef;
  open my $fh, "<$fn" or return {};
  my $text = <$fh>;
  close $fh;
  return ParseManifest $text;
  }

sub GetRemoteManifest ($) {
  my $fn = shift;
  my $text = GetFile $fn;
  return ParseManifest GetFile $fn;
  }

sub Main () {
  warn "As of 2024-06-23, this script is not likely to run due to server-side changes. Please try manually downloading and extracting https://www.poslarchive.com/tsh/tsh.zip instead.\n";
  my $manifest_name = 'MANIFEST.txt';
  $manifest_name = shift @::ARGV if @::ARGV == 1;
  if (-e '../tsh.pl' && ! -e 'tsh.pl') { chdir '..'; }
  if (-e 'tsh.pl') { print "Checking for newer versions of tsh files.\n"; }
  else { print "Downloading tsh.\n"; }
  my $localsp = GetLocalManifest $manifest_name or Die "No local manifest";
  my $remotesp = GetRemoteManifest $manifest_name or Die "No remote manifest";
  my $found_something;
  my $did_something;
  for my $file (sort keys %$remotesp) {
    $found_something++;
    if ((!-e $file) || (!exists $localsp->{$file}) 
      || $localsp->{$file} ne $remotesp->{$file}) { 
      if ($file =~ /\/$/) {
	unless (-d $file) {
	  print "Creating directory $file\n";
	  mkdir $file || warn "mkdir() failed: $!\n";
	  $did_something++;
	  }
	}
      else {
	UpdateFile $file, $remotesp->{$file}, %$localsp, $manifest_name;
	$did_something++;
	}
      }
    }
  if ($did_something) {
    print "Update complete.  Please exit and rerun tsh.\n";
    }
  elsif ($found_something) {
    print "No files needed to be updated.\n";
    }
  else {
    print "Empty $manifest_name: something's wrong.\n";
    }
  }

sub ParseManifest ($) {
  my $lines = shift;
  my %data;

  for my $line (split(/\n/, $lines)) {
    next if $line =~ /^(?:Archive| +Length +Date|[- ]+$| +\d+ +\d+ files$)/;
    $line =~ s/^\s+//; $line =~ s/\+$//;
    my ($length, $date, $time, $file) = split(/\s+/, $line, 4);
    Die "Can't parse: $line\n" unless defined $file;
    $data{$file} = "$length $date $time";
    }
  return \%data;
  }

sub UpdateFile ($$\%$) {
  my $file = shift;
  my $remotedata = shift;
  my $localsp = shift;
  my $manifest_name = shift;
  
  print "Updating $file.\n";
  my $content = GetFile $file;
  $localsp->{$file} = $remotedata;
  -e $file && unlink $file;
  open my $fh, ">$file" or Die "Can't create $file: $!\n";
  print $fh $content or Die "Can't write to $file: $!\n";
  close $fh or Die "Can't close $file: $!\n";
  if ($file =~ /^(?:bin|util)\/|^(?:get-tsh|tourney|tsh)\.pl$|^osx-tsh\.command$/ && $file !~ /\.(?:hlp|txt)$/) {
    chmod 0755, $file or Die "chmod $file failed: $!\n";
    }
  open $fh, ">$manifest_name" or Die "Can't creat $manifest_name: $!\n";
  print $fh map { qq($localsp->{$_} $_\n) } sort keys %$localsp
    or Die "Can't write to $manifest_name: $!\n";
  close $fh or Die "Can't close $manifest_name: $!\n";
  }
