#!/usr/bin/perl

# Copyright (C) 2007 John J. Chew, III <jjchew@math.utoronto.ca>
# All Rights Reserved

package TSH::ParseArgs;

use strict;
use warnings;

use Carp;

=pod

=head1 NAME

TSH::ParseArgs - parse typed command-line arguments

=head1 SYNOPSIS

  # within main routine
  my $parser = new TSH::ParseArgs;
  my (@argv) = $parser->ParseArgs($argvp, \@argv_types);
  my $arg_parser = $parser->ArgumentParser('Division');
  my $error = $parser->Error();
  die $error if $error;

  # argument parser
  sub ParseArgs::Type::Parse ($$) {
    my $this = shift;
    my $line_parser = shift;
    my $shared = $line_parser->GetShared('key');
    $line_parser->SetShared('key', $shared + 1);
    my $value = $line_parser->GetArg();
    $line_parser->UnGetArg($value);
    }
  
=head1 ABSTRACT

This Perl module is used to validate arguments to commands entered
into C<tsh>.

=cut

=head1 DESCRIPTION

=over 4

=cut

sub GetArg ($);
sub GetShared ($$);
sub Error ($;$);
sub initialise ($$);
sub new ($$);
sub LoadArgumentParser ($$);
sub Parse ($$$);
sub Processor ($;$);
sub SetShared ($$$);
sub UnGetArg ($$);

=item $i = $p->ArgumentIndex();

May be used very carefully by argument parsers to examine the current
argument index.

=cut

sub ArgumentIndex ($) { my $this = shift; return $this->{'argi'}; }

=item $argumentsp = $p->Arguments();

May be used very carefully by argument parsers to examine the list
of arguments to be called for this command.

=cut

sub Arguments ($) { my $this = shift; return $this->{'argv'}; }

=item $parser = $parserp->ArgumentParser($type);

=item $parserp->ArgumentParser($type, $parser);

Used externally to fetch an argument parser object.
Used internally to store a cached argument parser object.

=cut

sub ArgumentParser ($$;$) {
  my $this = shift;
  my $type = shift;
  my $parser = shift;
  my $class = "TSH::ParseArgs::$type";
  my $old = $this->{'parser_cache'}{$class};
  if (defined $parser) {
    $this->{'parser_cache'}{$class} = $parser;
    }
  elsif (!defined $old) {
    $old = $this->{'parser_cache'}{$class} = $this->LoadArgumentParser($type);
    }
  return $old;
  }

=item $value = $parserp->GetArg();

Used by individual argument parsers to obtain the current argument
needing to be parsed.

=cut

sub GetArg ($) {
  my $this = shift;
  my $value = $this->{'argv'}[$this->{'argi'}++];
# unless (defined $value) {
#   confess "GetArg failed with p_i=$this->{'parser_index'}.\n";
#   }
# warn "GetArg: $value\n";
  return $value;
  }

=item $parserp->GetShared($key)

Used by individual argument parsers to share data.
See Player and Division for an example.

=cut

sub GetShared ($$) {
  my $this = shift;
  my $key = shift;
# warn "$key is $this->{'shared'}{$key}";
  return $this->{'shared'}{$key};
  }

=item $parserp->Error();

Used externally to fetch the current parser error message,
or undef if none.
Used internally to set the current parser error message.

=cut

sub Error ($;$) {
  my $this = shift;
  my $message = shift;
  if (defined $message) {
    if (ref($message)) {
      my $tournament = $this->{'processor'}->Tournament();
      $message = $tournament->UserMessage()->{0}->Render(%$message);
      }
    chomp $message;
    if (defined $this->{'error'}) {
      $this->{'error'} .= $message;
      }
    else {
      $this->{'error'} = $message; 
      }
    }
  return $this->{'error'};
  }

=item $parserp->initialise($processor);

Used internally to (re)initialise a parser object.

=cut

sub initialise ($$) {
  my $this = shift;
  $this->{'processor'} = shift;
# $this->{'division'} = undef;
  $this->{'error'} = undef;
  $this->{'shared'} = {};
  return $this;
  }

=item $parserp = new TSH::ParseArgs($processor);

Create a new parser object.

=cut

sub new ($$) {
  my $proto = shift;
  my $class = ref($proto) || $proto;
# my $this = $class->SUPER::new();
  my $this = {
    'parser_cache' => {},
    };
  bless($this, $class);
  $this->LoadArgumentParser('Ignore');
# {
#   my $parser_class = 'TSH::ParseArgs::Ignore';
#   eval "require $parser_class";
#   die $@ if $@;
#   $this->ArgumentParser('Ignore', $parser_class->new($this->{'processor'}));
# }
  $this->initialise(@_);
  return $this;
  }

=item $arg_parser = $parser->LoadArgumentParser($type);

Load the appropriate parser for the given type.
Should only be used internally for classes known to be as yet unloaded.
Loaded classes should be found using ArgumentParser().

=cut

sub LoadArgumentParser($$) {
  my $this = shift;
  my $type = shift;
  my $class = "TSH::ParseArgs::$type";
  my $parser = $this->{'parser_cache'}{$class};
  return $parser if $parser;
  eval "use $class";
  if ($@) {
    my $tournament = $this->{'processor'}->Tournament();
    $tournament->TellUser('enomod', "$class.pm", $@);
    return ();
    }
  eval { $parser = $class->new($this->{'processor'}); };
  if (my $error = $@) {
    # when would this ever happen in a working installation?
    # why is this worth trapping?
    my $tournament = $this->{'processor'}->Tournament();
    $tournament->TellUser('eparseload', "$class.pm", $error);
    return ();
    }
  $this->ArgumentParser($type, $parser);
  return $parser;
  }

=item @checked_argv = $parserp->Parse(\@argv, \@types);

Check to make sure each member of @argv has the type indicated in
@types and return normalized values.

=cut

sub Parse ($$$) {
  my $this = shift;
  my $argvp = shift;
  my $typesp = shift;
# print STDERR "argv has largest index $#$argvp and values @$argvp\n";
# print STDERR "types has largest index $#$typesp and values @$typesp\n";

  $this->initialise($this->{'processor'});
  $this->{'argv'} = $argvp;
  $this->{'argi'} = 1; # skip command name

  my @parsers;
  for my $type (@$typesp, 'Nothing') {
    push(@parsers, $this->ArgumentParser($type));
    }
  $this->{'parsers'} = \@parsers;
  $this->{'parser_index'} = 0;
  $this->{'parsed'} = [];
  while ($this->{'parser_index'} <= $#{$this->{'parsers'}}) {
#   warn "PA001. pix=$this->{'parser_index'} argi=$this->{'argi'} p=".ref($this->{'parsers'}[$this->{'parser_index'}])." v=$this->{'argv'}[$this->{'argi'}]\n";
    my (@values) = $this->{'parsers'}[$this->{'parser_index'}++]->Parse($this);
    if (@values) {
#     warn "PA002. values=@values\n";
      push(@{$this->{'parsed'}}, @values);
      }
    elsif ($this->Error()) {
      $this->Processor()->Tournament()->TellUser('eparse', $this->Error());
      return ();
      }
    }
  return @{$this->{'parsed'}};
  }

=item $i = $p->ParserIndex();

May be used very carefully by argument parsers to examine the current
parser index.

=cut

sub ParserIndex ($) { my $this = shift; return $this->{'parser_index'}; }

=item $parsersp = $p->Parsers();

May be used very carefully by argument parsers to examine the list
of parsers to be called for this command.

=cut

sub Parsers ($) { my $this = shift; return $this->{'parsers'}; }

=item $processor = $p->Processor();

=item $p->Processor($processor);

Get/set the processor object associated with us.

=cut

sub Processor ($;$) { TSH::Utility::GetOrSet('processor', @_); }

=item $parserp->RemoveShared($key)

Used by individual argument parsers to share data.
Removes data associated with the key.
See Player and Division for an example.

=cut

sub RemoveShared ($$) {
  my $this = shift;
  my $key = shift;
  delete $this->{'shared'}{$key};
  }

=item $parserp->SetShared($key, $val)

Used by individual argument parsers to share data.
See Player and Division for an example.

=cut

sub SetShared ($$$) {
  my $this = shift;
  my $key = shift;
  my $val = shift;
  $this->{'shared'}{$key} = $val;
# warn "$key is now $this->{'shared'}{$key}";
  }

=item $parserp->UnGetArg($value)

Used by individual argument parsers to return the current argument
if it didn't need to be parsed after all. 

=cut

sub UnGetArg ($$) {
  my $this = shift;
  my $value = shift;
  $this->{'argv'}[--$this->{'argi'}] = $value;
  }

=back

=cut

1;

