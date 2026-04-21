#!/usr/bin/perl

# Copyright (C) 2005-2007 John J. Chew, III <jjchew@math.utoronto.ca>
# All Rights Reserved

package UserMessage;

use threads::shared;
use JavaScript::Serializable;

our (@ISA);
@ISA = qw(JavaScript::Serializable);
sub EXPORT_JAVASCRIPT () { return map { $_ => $_ } qw(messages); }

=pod

=head1 NAME

UserMessage - User diagnostic message class

=head1 SYNOPSIS

  my $um = new UserMessage($message_filename);
  my $s = Render('code' => $code, 'argv' => \@args);
  $um->SetExplainFilter(\&sub);
  $um->SetErrorFilter(\&sub);
  $um->SetNoteFilter(\&sub);
  $um->SetWarningFilter(\&sub);
  $um->Show($code, @args);
  $um->Explain();
  $um->Explain($code);
  
=head1 ABSTRACT

This Perl library manages user diagnostic messages.
Messages are stored in a text file to facilitate translation.
Messages may be informational notes, warnings or errors.
Each message has a detailed explanation associated with it,
which the user may request if the brief text is insufficient.

=head1 DESCRIPTION

=over 4

=cut

sub AddFiles ($$);
sub DefaultFilter ($);
sub Explain($;$);
sub new ($$);
sub Render ($@);
sub SetErrorFilter ($\&;$);
sub SetExplainFilter ($\&);
sub SetNoteFilter ($\&);
sub SetWarningFilter ($\&;$);
sub Show($$@);

sub AddFiles ($$) {
  my $this = shift;
  my (%argh) = @_;
  my (@filenames) = @{$argh{'file'}};
  $this->{'encoding'} = $argh{'encoding'} if $argh{'encoding'};
  while (@filenames) {
    my $filename = pop @filenames;
    push(@{$this->{'filename'}}, $filename);
    $this->LoadFile($filename);
    }
  }

=item DefaultFilter($text);

The default filter for showing any kind of message calls print if
STDOUT is a tty (suggesting that we are running interactively),
and otherwise prints on STDERR (believing that we may be running
as a CGI script).

=cut

sub DefaultFilter ($) {
  my $this = shift;
  if (-t STDOUT) {
    print $this;
    }
  else {
    print STDERR $this;
    }
  }

=item $success = $um->Explain()
=item $success = $um->Explain($code))

Give the detailed text for an error message.  If no code is
specified, then give the explanation for the last message
issued.  If none has been issued, do nothing.

=cut

sub Explain ($;$) {
  my $this = shift;
  my $code = (shift || $this->{'lastcode'});
  if ($code) {
    my $s = $this->{'messages'}{$code};
    if (defined $s) {
      &{$this->{'explainfilter'}}($code, $s->{'detail'});
      return 1;
      }
    }
  return 0;
  }

sub Filenames ($) {
  my $this = shift;
  return @{$this->{'filename'}};
  }

sub LoadFile ($$) {
  my $this = shift;
  my $filename = shift;
  my $fh;
  unless (open $fh, "<:encoding($this->{'encoding'})", $filename) {
    warn "Can't open $filename: $!"; 
    return; 
    }
  local($/) = undef;
  my (@required) = qw(brief type);
  push(@required, q(detail)) unless $this->{'nodetail'};
  my %seen;
  my $slurp = scalar(<$fh>);
  local ($_);
  my (@errors);
  for (split(/(?:\015\012){2}|(?:\012\015){2}|\012{2}|\015{2}|\n{2}/, $slurp)) { # can't be sure the linebreak matches the encoding
#   die length($_) if /.\r\n\r\n./;
    next unless /\S/;
    my $datap = &share({});
    if (%$datap) { # 5.8.0 bug
      for my $key (keys %$datap) { delete $datap->{$key}; }
      }
#   warn "BEGIN RECORD\n$_\nEND RECORD\n";
    eval { 
      for my $line (split(/\s*[\n\r\015\012]+/)) {
  #     warn $line if $this->{'filename'} =~ /nor/;
	my ($key, $value) = split(/=/, $line, 2);
  #     warn "key=$key\nvalue=$value\n";
	die "Duplicate key '$key' in record:\n$_\n" if exists $datap->{$key};
	$datap->{$key} = $value;
	}
      die "No message code in record:\n$_\n" unless exists $datap->{'code'};
      die "Duplicate entries for message code [$datap->{'code'}]\n"
	if $seen{$datap->{'code'}}++;
      for my $field (@required) {
	next if exists $datap->{$field};
	my $keys = join(', ', keys %$datap);
	die "Record for [$datap->{'code'}] is missing required field '$field', but has keys: $keys.\n";
	}
      die "Record for [$datap->{'code'}] has bad message type '$datap->{'type'}'\n"
	unless $datap->{'type'} =~ /^(?:note|warning|error|label)$/;
      };
    if ($@) {
      push(@errors, $@);
      }
    else {
      $this->{'messages'}{$datap->{'code'}} = $datap;
      }
    }
  close($fh);
  if (@errors) {
    warn "Message database '$filename' could not be fully parsed due to\n"
      . "the following serious syntax error(s).  Records that could not\n"
      . "be parsed were ignored, which may lead to software crashing later.\n"
      . join('', @errors);
    }
# warn "$filename $this->{'messages'}{'Spread'}{'brief'}" if $filename eq 'lib/terms/deu.txt';
  }

=item $um = new UserMessage('file' => $filename, 'nodetail' => $boolean, 'hidecode' => $boolean);

Create a new UserMessage object based on the parameters given:

  file: message filename (if an array reference, a list of filenames to be used
    in order of decreasing preference order)
  nodetail: if true, do not require a detailed description field in the message files
  hidecode: if true, do not append the message code to displayed messages.
  encoding: if set, override the default isolatin1 encoding

=cut

sub new ($$) {
  my $proto = shift;
  my (%options) = @_;
  my $class = ref($proto) || $proto;
# my $this = $class->SUPER::new();
  my $this = {};
  &share($this);
  # We can't currently use an \& here (and passim) because threads::shared won't share them
  $this->{'encoding'} = $options{'encoding'} || 'isolatin1';
# $this->{'errorfilter'} = \&DefaultFilter;
  $this->{'errorfilter'} = 'UserMessage::DefaultFilter';
# $this->{'explainfilter'} = \&DefaultFilter;
  $this->{'explainfilter'} = 'UserMessage::DefaultFilter';
# $this->{'filename'} = $options{'file'} || do { use Carp; confess};
  $this->{'hidecode'} = $options{'hidecode'};
  $this->{'lastcode'} = undef;
  $this->{'messages'} = &share({});
  $this->{'nodetail'} = $options{'nodetail'};
# $this->{'notefilter'} = \&DefaultFilter;
  $this->{'notefilter'} = 'UserMessage::DefaultFilter';
# $this->{'warningfilter'} = \&DefaultFilter;
  $this->{'warningfilter'} = 'UserMessage::DefaultFilter';
  bless($this, $class);
  
  $this->{'filename'} = &share([]);
  if (ref($options{'file'})) {
    push(@{$this->{'filename'}}, @{$options{'file'}});
    }
  else {
    $this->{'filename'}[0] = $options{'file'};
    }
  my (@filenames) = @{$this->{'filename'}};
# warn "@{$options{'file'}}";
# warn "filenames: @filenames; encoding: $this->{'encoding'} at";
  while (@filenames) {
    my $filename = pop @filenames;
    $this->LoadFile($filename);
    }

  return $this;
  }

=item $s = $um->Render('code' => $code, 'argv' => \@argv, 'hidecode' => $boolean);

Return the brief text for the message, filling in sprintf fields from @args. 

=cut

sub Render ($@) {
  my $this = shift;
  my (%options) = @_;
  my $code = $options{'code'};
  $this->{'lastcode'} = $code;
  my $s = $this->{'messages'}{$code};
  if ($s) {
    $s = sprintf($s->{'brief'}, @{$options{'argv'}});
    my $hidecode = exists $options{'hidecode'}
      ? $options{'hidecode'}
      : $this->{'hidecode'};
    $s .= " [$code]" unless $hidecode;
    }
  else {
#   use Carp; warn join(',', keys %{$this->{'messages'}}); confess "Unknown message code '$code'"; 
    eval "use Carp"; &Carp::confess("Unknown message code '$code'");
    }
  return $s;
  }

=item SetErrorFilter(\&sub);

Set the filter for displaying errors.

=cut

sub SetErrorFilter ($\&;$) {
  my $this = shift;
  my $sub = shift;
  my $arg = shift;
  $this->{'errorfilter'} = $sub;
  $this->{'errorfilter_arg'} = $arg;
  }

=item SetExplainFilter(\&sub);

Set the filter for displaying explanationss.

=cut

sub SetExplainFilter ($\&) {
  my $this = shift;
  my $sub = shift;
  $this->{'explainfilter'} = $sub;
  }

=item SetNoteFilter(\&sub);

Set the filter for displaying notes.

=cut

sub SetNoteFilter ($\&) {
  my $this = shift;
  my $sub = shift;
  $this->{'notefilter'} = $sub;
  }

=item SetWarningFilter(\&sub);

Set the filter for displaying warnings.

=cut

sub SetWarningFilter ($\&;$) {
  my $this = shift;
  my $sub = shift;
  my $arg = shift;
  $this->{'warningfilter'} = $sub;
  $this->{'warningfilter_arg'} = $arg;
  }

=item $um->Show($code, @args)

Give the brief text for the message, filling in sprintf
fields from @args.  Use one of the output filters depending on
the message type.

=cut

sub Show ($$@) {
  my $this = shift;
  my $code = shift;
  my $datap = $this->{'messages'}{$code};
  unless ($datap) {
    warn "Unknown message code: $code";
    return 0;
    }
  my $s = $this->{'messages'}{$code};
  my $type = $s->{'type'};
  die "No message type for code $code: $type"
    unless defined $type;
  die "Bad message type for code $code: $type"
    unless $type =~ /^(?:note|warning|error)$/;
  $this->{'lastcode'} = $code;
  &{$this->{$type.'filter'}}($code, $type, sprintf($s->{'brief'}, @_), 
    $this->{$type.'filter_arg'});
  return 1;
  }

=back

=cut

=head1 BUGS

Need to allow encoding to be a vector, for using multiple files with different encodings.

Should have been called something like UserMessageLibrary.

=cut

1;
