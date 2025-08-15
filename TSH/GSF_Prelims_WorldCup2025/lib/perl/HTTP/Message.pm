#!/usr/bin/perl

use strict;
use warnings;
use Carp;
$SIG{__DIE__} = sub { confess $_[0]; };

# Copyright (C) 2005 John J. Chew, III <jjchew@math.utoronto.ca>
# All Rights Reserved

package HTTP::Message;

our(@ISA) = 'Exporter';
our(@EXPORT_OK) = qw(EncodeEntities);

=pod

=head1 Name

HTTPMessage -  HTTP Message Class

=head1 SYNOPSIS

  use HTTP::Message;
  # read message from socket (see also HTTP::Client, HTTP::Socket)
  $mp = new HTTP::Message ('handle' => $this->{'socket'});
  $te = $mp->Header('transfer-encoding');
  $body = $mp->Body();

  # create new message to send
  use HTTP::Message;
  $mp = new HTTP::Message ('handle' => $this->{'socket'});
  $mp->Header('content-type', 'multipart/form-data');
  $mp->FormData({'foo'=>1,'bar'=>2});
  $mp->ToString();

=head1 ABSTRACT

This Perl library is an abstraction of an HTTP message.  HTTP messages
are used to communicate between a web client and web server.  

=head1 DESCRIPTION

=over 4

=cut

sub new ($@);
sub Body ($;$);
sub Date ($;$);
sub Die ($$);
sub EncodeEntities ($);
sub EncodeMultipartFormData (@);
sub Error ($;$);
sub FormData ($;$);
sub GetFromHandle ($$);
sub HTTPVersion ($;$);
sub Header ($$;$);
sub Headers ($);
sub Method ($;$);
sub Read ($$;$);
sub ReadBody ($$;$);
sub ReadHeader ($$;$);
sub ReadLine ($$;$);
sub StatusCode ($;$);
sub URL ($;$);

=item $mp = new HTTPMessage($key1 => $value1, ...);

Create a new HTTPMessage object.  
All parameter keys are optional.
C<body> gives the message body as a string.
C<error> sets the current module error message.
C<handle> gives a handle from which to read the message.
C<headers> gives the message headers as a hash.
C<method> gives the method (GET/POST).
C<url> gives the URL.

=cut

sub new ($@) {
  my $proto = shift;
  my $class = ref($proto) || $proto;
# my $this = $class->SUPER::new();
  my $this = {
    'body' => '',
    # 'content-length' => undef,
    'error' => '',
    'handle' => undef,
    'http-version' => '1.1',
    # 'last-header-read' => undef,
    'headers' => {},
    'method' => undef,
    # 'reason-phrase' => undef,
    'source-object' => undef,
    'status-code' => undef,
    # 'transfer-encoding' => undef,
    'url' => undef,
    };
  my %param = @_;
  for my $key (keys %param) {
    if (!exists $this->{$key}) { die "Unknown parameter ($key)"; }
    }
# Carp::cluck join(',', keys %param);
  for my $key (qw(body error headers http-version method status-code url)) {
    if (exists $param{$key}) { $this->{$key} = $param{$key}; }
    elsif (!exists $this->{$key}) {
      die "Missing required parameter ($key).";
      }
    }
  bless($this, $class);

  if ($param{'handle'}) {
    $this->Read($param{'handle'});
    }
  elsif ($param{'source-object'}) {
    $this->Read($param{'source-object'}, 'object');
    }
  
  return $this;
  }

=item $body = $mp->Body();

=item $mp->Body($body);

Sets/gets the body of an HTTP message.

=cut

sub Body ($;$) {
  my $this = shift; 
  my $body = shift;
  if (defined $body) 
    { return $this->{'body'} = $body; }
  else 
    { return $this->{'body'}; }
  }

=item $time = $mp->Date();

=item $mp->Date($time);

Sets/gets the Date: header of an HTTP message.
$time is in seconds since epoch.

=cut

sub Date ($;$) {
  my $this = shift; 
  my $time = shift;
  if (defined $time) { 
    my ($sec, $min, $hour, $mday, $month, $year, $wday) = gmtime($time);
    my $gmtime = sprintf("%3s, %02d %3s %4d %02d:%02d:%02d GMT",
      qw(Sun Mon Tue Wed Thu Fri Sat)[$wday],
      $mday, 
      qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec)[$month],
      $year+1900,
      $hour, $min, $sec);
    $this->{'headers'}{'date'} = $gmtime;
    }
  else 
    { die "not yet implemented"; }
  }

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

my (%entities) 
  = ('&' => '&amp;', '>' => '&gt;', '<' => '&lt;', '"' => '&quot;');

sub DecodeURL ($) {
  my $s = shift;
  $s =~ s/%(..)/chr(hex($1))/eg;
  return $s;
  }

sub EncodeEntities ($) {
  my $s = shift;
  $s =~ s/(["&<>])/$entities{$1}/g;
  return $s;
  }

=item ($boundary, $entity_body) = EncodeMultipartFormData($key1=>$value1, ...);

Encodes a hash as multipart/form-data.
Used in creating a message to POST to a web server,
using the contents of a form that includes a file upload.

File uploads should be represented as hash references:
{ type => 'file', filename => $filename, data => $data }.

If a key has multiple values, then its value should be an array reference.

All other values should be represented as scalars.

=cut

sub EMFD1 ($$$) {
  my $datap = shift;
  my $key = shift;
  my $value = shift;

  if (ref($value) eq 'HASH') {
    if ($value->{'type'} eq 'file') {
      push(@$datap, 
	qq(Content-Disposition: form-data; name="$key"; filename="$value->{'filename'}"\015\012\015\012)
	. "$value->{'data'}\015\012");
      }
    else {
      die "Unknown form data type: $value->{'type'}\n";
      }
    }
  else {
#     Carp::confess $key unless defined $value;
    $value = '' unless defined $value;
    push(@$datap,
      qq(Content-Disposition: form-data; name="$key"\015\012\015\012)
      . "$value\015\012");
    }
  }

sub EncodeMultipartFormData (@) {
  my (%data) = @_;
  my @data;
  while (my ($key, $value) = each %data) {
    if (ref($value) eq 'ARRAY') {
      for my $v1 (@$value) { EMFD1 \@data, $key, $v1; }
      }
    else { EMFD1 \@data, $key, $value; }
    }
  my $boundary = 'posl--';
  for my $value (@data) {
    while ($value =~ /--$boundary/) {
      $boundary .= chr(97 + int(rand(26)));
      }
    }
  my $s = join("--$boundary\015\012", '', @data, '');
  $s =~ s/\015\012$/--\015\012/;
  return ($boundary, $s);
  }

=item $mp->Error($error);

=item $error = $mp->Error();

Sets and/or gets the module error message.

=cut

sub Error ($;$) {
  my $this = shift;
  my $message = shift;
  if (defined $message) { 
#   warn "HTTP Error: $message";
    return $this->{'error'} = $message; 
    }
  else 
    { return $this->{'error'}; }
  }

=item $mp->FormData({$key1=>$val1,...});

=item $hashp = $mp->FormData();

Sets and/or gets HTML form data in the message.

=cut

sub FormData ($;$) {
  my $this = shift;
  my $newdata = shift;
  my $type = $this->Header('content-type') || '';
  if (defined $newdata) {
    if ($type eq 'x-www-form-urlencoded') {
      die "Can't yet set form data for type $type";
      }
    elsif ($type =~ /\bmultipart\/form-data\b/) {
      $this->{'error'} = '';
      my ($boundary, $html) = EncodeMultipartFormData %$newdata;
      unless ($this->{'error'}) {
	$this->{'headers'}{'content-type'} 
	  = "multipart/form-data; boundary=$boundary";
	$this->{'body'} = $html;
        }
      }
    elsif ($type eq '') {
      $this->Die("Can't set form data without a Content-Type.");
      }
    else {
      $this->Die("Can't set form data for unknown Content-Type $type");
      }
    }
  elsif ($type eq '') {
    return {};
    }
  elsif ($type =~ qr[\bapplication/x-www-form-urlencoded\b]) {
    my (@data) = split(/&/, $this->{'body'});
    my %data;
    for my $data (@data) {
      my ($key, $value) = split(/=/, $data, 2);
      $key =~ s/\+/ /g;
      $key =~ s/%([0-9a-f]{2})/pack('C',hex($1))/gie;
      $value =~ s/\+/ /g;
      $value =~ s/%([0-9a-f]{2})/pack('C',hex($1))/gie;
      $data{$key} = $value;
      }
    return \%data;
    }
  elsif ($type =~ qr[\bmultipart/form-data\b]) {
    my ($boundary) = ($type =~ /\bboundary=(\S*[^\s;])/);
    if (!$boundary) {
      $this->Die("multipart/form-data must specify boundary in content-type.");
      }
    else {
      my %data;
      for my $part (split(/--\Q$boundary/, $this->{'body'})) {
	next unless $part =~ /[^-\s]/;
	if ($part =~ s/^\015?\012Content-Disposition:\s*form-data;\s*name="(.*)"\015?\012\015?\012//i) {
	  my $name = $1;
	  $part =~ s/\015?\012$//;
	  $data{$name} = $part;
#	  warn "$name: $part";
	  }
	else {
#	  warn "oops: [$part]";
	  $this->Die("Cannot parse part of multipart/form-data: $part");
#	  return undef;
	  }
        }
      return \%data;
      }
    }
  else {
    die "not yet implemented ($type)";
    }
  }

=item $success = $mp->GetFromHandle($fh);

Reads a message from a file handle.
Deprecated in favour of C<Read>.
On error, returns undef and sets error.

=cut

sub GetFromHandle ($$) {
  my $this = shift;
  my $handle = shift;

  warn "HTTP::Message::GetFromHandle is deprecated: use Read instead\n";
  return $this->Read($handle);
## should this be moved somewhere?
# if ($this->{'status-code'} != 200) {
#   $this->Die("Web server request failed: $this->{'status-code'} $this->{'reason-phrase'}");
#   return $this;
#   }
  }

=item $mp->HTTPVersion($url);

=item $version = $mp->HTTPVersion();

Sets and/or gets the message's HTTPVersion.

=cut

sub HTTPVersion ($;$) {
  my $this = shift;
  my $version = shift;
  if (defined $version) 
    { return $this->{'http-version'} = $version; }
  else 
    { return $this->{'http-version'}; }
  }

=item $mp->Header($field_name, $field_value);

=item $field_value = $mp->Header($field_name);

Sets and/or gets an individual message header.

=cut

sub Header ($$;$) {
  my $this = shift;
  my $field_name = lc shift;
  my $field_value = shift;
  if (defined $field_value) 
    { return $this->{'headers'}{$field_name} = $field_value; }
  else 
    { return $this->{'headers'}{$field_name}; }
  }

=item %headers = $mp->Headers();

Returns all of the message headers in a hash.

=cut

sub Headers ($) {
  my $this = shift;
  return %{$this->{'headers'}};
  }

=item $mp->Method($error);

=item $error = $mp->Method();

Sets and/or gets the HTTP access method.

=cut

sub Method ($;$) {
  my $this = shift;
  my $method = shift;
  if (defined $method) 
    { return $this->{'method'} = $method; }
  else 
    { return $this->{'method'}; }
  }

=item $seconds_since_epoch = ParseRFC1123($string);

Parse a time value rendered as per RFC 1123, return undef on failure.

=cut

sub ParseRFC1123 ($) {
  local($_) = shift;
  s/.*,\s*//;
  s/^(\d+)\s*// or return undef;
  my $D = $1;
  s/^(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)\s*//i or return undef;
  my $M = {'jan'=>0,'feb'=>1,'mar'=>2,'apr'=>3,'may'=>4,'jun'=>5,
    'jul'=>6,'aug'=>7,'sep'=>8,'oct'=>9,'nov'=>10,'dec'=>11}->{lc $1};
  s/^(\d+)\s*// or return undef;
  my $Y = $1;
  $Y += 1900 if $Y < 1900;
  s/^(\d+)\s*:\s*// or return undef;
  my $h = $1;
  s/^(\d+)\s*// or return undef;
  my $m = $1;
  my $s = s/^:\s*(\d+)\s*// ? $1 : 0;
  my $adjustment = 0;
  if (s/^(z|ut|gmt|edt|est|cst|cdt|mst|mdt|pst|pdt)\s*//i) {
    $adjustment = {
      'z' => 0,
      'ut' => 0,
      'gmt' => 0,
      'edt' => -4*60,
      'est' => -5*60,
      'cdt' => -5*60,
      'cst' => -6*60,
      'mdt' => -6*60,
      'mst' => -7*60,
      'pdt' => -7*60,
      'pst' => -8*60,
      }->{lc $1};
    }
  elsif (s/^([-+]?)(\d\d)(\d\d)\s*//) {
    my ($sign, $mm, $ss) = ($1, $2, $3);
    $adjustment = ($sign eq '-' ? -1 : 1) * ($mm*60 + $ss);
    }
  eval 'use Time::Local';
  die "Cannot find Time::Local: $@" if $@;
  my $time;
  eval { $time = Time::Local::timegm($s, $m, $h, $D, $M, $Y) };
  return undef unless $time;
  $time -= 60 * $adjustment;
  return $time;
  }

=item $success = $mp->Read($handle);

Reads a message from a handle.
On error, returns undef and sets C<error>.

=cut

sub Read ($$;$) {
  my $this = shift;
  my $handle = shift;
  my $source_is_object = shift;
  $this->ReadHeader($handle, $source_is_object) or return undef;
  return $this->ReadBody($handle, $source_is_object);
  }

=item $success = $mp->ReadBody($handle);

Reads a message body from C<$handle>.
Must be called after a successful call to C<ReadHeader>.
On error, sets C<error> and returns undef.

=cut

sub ReadBody ($$;$) {
  my $this = shift;
  my ($handle, $source_is_object) = (@_);
  $this->{'body'} = '';
  # if the message body length is explicitly specified
  if (my $content_length = $this->Header('content-length')) {
    my $read = 0;
    while ($read < $content_length) {
      my $s = '';
      my $rv = $source_is_object 
	? $handle->Read($s, $content_length - $read)
	: read $handle, $s, $content_length - $read;
      $this->{body} .= $s;
      if (!defined $rv) {
	$this->Die("Incomplete: error reading message body");
	return undef;
	}
      if ($rv == 0) {
	$this->Die("Incomplete: web server response was truncated ($read < $content_length)");
	return undef;
        }
      $read += $rv;
      }
    }
  # else if a transfer encoding is given
  elsif (my $transfer_encoding = $this->Header('transfer-encoding')) {
    if ($transfer_encoding eq 'chunked') {
      while (1) {
	my $chunk = $this->ReadChunk($handle, $source_is_object);
	if (!defined $chunk) { 
	  return undef;
	  }
	last unless length($chunk);
	$this->{'body'} .= $chunk;
        }
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
  return 1;
  }

=item $line = $mp->ReadChunk($handle);

Used internally to read one chunk from C<$handle>.  
Chunks are a kind of HTTP transfer encoding consisting of
a hexadecimal byte count, "\015\012", the specified number of bytes,
and another "\015\012".
Returns undef on error.

=cut

sub ReadChunk($$;$) {
  my $this = shift;
  my $handle = shift;
  my $source_is_object = shift;
  my $count = $this->ReadLine($handle, $source_is_object);
  if (!defined $count) {
    $this->Die("Incomplete: chunk had no count");
    return undef;
    }
  if ($count !~ /^([0-9a-f]+) *\015*\012$/i) {
    $this->Die("Incomplete: chunk had bad count: $count");
    return undef;
    }
  $count = hex($1);
  my $data = '';
  my $tries = 0;
  while (length($data) < $count+2) {
    my $buffer = '';
    my $rv = $source_is_object 
      ? $handle->Read($buffer, $count+2)
      : read $handle, $buffer, $count+2;
    if (!defined $rv) {
      $this->Die("Incomplete: error reading chunk data");
      return undef;
      }
    $data .= $buffer;
    if (length($data) < $count+2) {
      $tries++;
      warn "Incomplete chunk @{[length $data]}/@{[$count+2]} bytes after try #$tries/25\n";
      if ($tries >= 25) {
	$this->Die("Incomplete: EOF reading chunk data at $rv/@{[$count+2]}");
	return undef;
	}
      sleep 1;
      }
    }
  if ($data !~ s/\015\012$//) {
    $this->Die("chunk data not followed by line break");
    return undef;
    }
  return $data;
  }

=item $mp->ReadHeader($handle) or die;

Reads a message header from $handle.
On error sets C<error> and returns undef.

=cut

sub ReadHeader($$;$) {
  my $this = shift;
  my $handle = shift;
  my $source_is_object = shift;

  # read start line
  $this->ReadStartLine($handle, $source_is_object) or return undef;
  # read message body a line at a time
  while (1) {
    my $rv = $this->ReadHeaderLine($handle, $source_is_object);
    return undef unless defined $rv;
    last unless $rv;
    }
  return 1;
  }

=item $mp->ReadHeaderLine($handle) or die "oops";

Used internally to read a header line of a message from C<$handle>
using C<ReadLine>.
Returns 
2 if the previous line was just continued,
1 if a new header was successfully read,
0 on end-of-header
and undef on error.

=cut

sub ReadHeaderLine ($$;$) {
  my $this = shift;
  my $handle = shift;
  my $source_is_object = shift;
  my $line = $this->ReadLine($handle, $source_is_object);
  # error reading header
  if (!defined $line) {
    $this->Die("Incomplete: error reading message header");
    return undef;
    }
  # normal end of header
  if ($line =~ /^\015?\012$/) { 
    return 0; 
    }
  # EOF before end of header
  if ($line !~ s/\015?\012$//) {
    $this->Die("Incomplete: header line not terminated");
    return undef;
    }
  # continuation line
  if ($line =~ s/^\s+//) {
    if (defined $this->{'last-header-read'}) {
      $this->{'headers'}{$this->{'last-header-read'}}
        .= ' ' . $line;
      return 2;
      }
    else {
      $this->Die("Bad continuation line at start of header");
      return undef;
      }
    }
  my ($field_name, $field_value) = split(/:\s*/, $line, 2);
  # error parsing header line
  if (!defined $field_value) {
    $this->Die("Malformed message header: $line");
    return undef;
    }
  $field_name = lc $field_name;
  $this->{'last-header-read'} = $field_name;
  if (exists $this->{'headers'}{$field_name}) {
    $this->{'headers'}{$field_name} .= ',' . $field_value;
    }
  else {
    $this->{'headers'}{$field_name} = $field_value;
    }
# warn "$field_name: $field_value\n";
  return 1;
  }

=item $line = $mp->ReadLine($handle);

Used internally to read one line (terminated by /\015?\012/) from
C<$handle>.  
Needed because C<getline> and C<$/> do not support 
pattern-matching for line breaks.
Canonicalises line break to "\015\012".

=cut

sub ReadLine($$;$) {
  my $this = shift;
  my $handle = shift;
  my $source_is_object = shift;
  local($/) = "\012";
  my $line = $source_is_object 
    ? $handle->GetLine()
    : scalar($handle->getline);
  if (defined $line) { $line =~ s/\015?\012$/\015\012/; }
  return $line;
  }

=item $mp->ReadStartLine($handle) or die "oops";

Used internally to read the starting line of a message from C<$handle>
using C<ReadLine>.

=cut

sub ReadStartLine ($$;$) {
  my $this = shift;
  my $handle = shift;
  my $source_is_object = shift;
  my $line = $this->ReadLine($handle, $source_is_object);
  if (!defined $line) {
    $this->Die("Error reading message header");
    return undef;
    }
  if ($line =~ /^HTTP\S+\s+(\d\d\d)\s+([^\015\012]*)/) {
    $this->{'status-code'} = $1;
    $this->{'reason-phrase'} = $2;
    }
  elsif ($line =~ /^(GET|POST)\s+(\S+)\s+HTTP\/(\d+\.\d+)\s*\015?\012/) {
    $this->{'method'} = $1;
    $this->{'url'} = $2;
    $this->{'http-version'} = $3;
    $this->{'url'} =~ s/^http:\/\/[^\/]*//;
    }
  elsif ($line =~ /^(GET|POST)\s+(\S+)\s*\015?\012/) {
    $this->{'method'} = $1;
    $this->{'url'} = $2;
    $this->{'http-version'} = "0.9";
    }
  else { 
    $this->Die("Web server returned a bad start line: $line");
    return undef; 
    }
  return 1;
  } 

=item $s = RenderRFC1123($seconds_since_epoch);

Return a time value rendered as per RFC 1123.

=cut

sub RenderRFC1123 ($) {
  my ($s, $m, $h, $D, $M, $Y, $wd) = gmtime(shift);

  return sprintf("%s, %02d %s %d %02d:%02d:%02d GMT",
    (qw(Sun Mon Tue Wed Thu Fri Sat))[$wd],
    $D,
    (qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec))[$M],
    $Y+1900,
    $h, $m, $s);
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

=item $s = $mp->ToString();

Returns a string representation of the message, suitable for transmitting
using HTTP.
Will set the Content-Length header if necessary.

=cut
sub ToString ($) {
  my $this = shift;
  my $s;

  my $http_version = $this->{'http-version'} || '1.1';
  my $status_code = $this->{'status-code'} || '200';
  my $reason_phrase = { 
    '200' => 'OK',
    '301' => 'Moved Permanently',
    '303' => 'See Other', # CGI referring to static file
    '400' => 'Bad Request',
    '401' => 'Unauthorized',
    '404' => 'File Not Found',
    '500' => 'Internal Error',
    '503' => 'Service Unavailable',
    }->{$status_code} || 'Unknown Code';
  # if really old HTTP
  if ($http_version eq '0.9') {
    if (defined $this->{'method'}) 
      { return "GET $this->{'url'}\015\012\015\012"; }
    elsif ($status_code eq '200') 
      { return $this->{'body'}; }
    else 
      { return "$status_code $reason_phrase\015\012\015\012$this->{'body'}"; }
    }
  # otherwise modern HTTP
  # set start line
  if (defined $this->{'method'}) 
    { $s = "\U$this->{'method'}\E $this->{'url'} HTTP/$http_version\015\012"; }
  else 
    { $s = "HTTP/$http_version $status_code $reason_phrase\015\012"; }
  # add message headers 
  $this->{'headers'}{'content-length'} = length($this->{'body'});
  $this->{'headers'}{'date'} = RenderRFC1123(time);
  for my $key (sort keys %{$this->{'headers'}}) {
    $s .= "\u$key: $this->{'headers'}{$key}\015\012";
    }
  $s .= "\015\012";
  # add body
# warn $s; # DEBUG
  $s .= $this->{'body'};
  return $s;
  }

=item $mp->URL($url);

=item $url = $mp->URL();

Sets and/or gets the message's URL.

=cut

sub URL ($;$) {
  my $this = shift;
  my $url = shift;
  if (defined $url) 
    { return $this->{'url'} = $url; }
  else 
    { return $this->{'url'}; }
  }

=back

=head1 SEE ALSO

The current HTTP standard at www.w3.org.

=cut

1;

