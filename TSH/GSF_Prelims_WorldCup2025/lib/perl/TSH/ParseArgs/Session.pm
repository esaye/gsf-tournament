#!/usr/bin/perl

# Copyright (C) 2017 John J. Chew, III <poslfit@gmail.com>
# All Rights Reserved

package TSH::ParseArgs::Session;

use strict;
use warnings;

use TSH::Utility;

=pod

=head1 NAME

TSH::ParseArgs::Session - handle a command-line argument that should be a session identifier

=head1 SYNOPSIS

  my $parser = new TSH::ParseArgs::Session;

=head1 ABSTRACT

This Perl module is used by C<ParseArgs.pm> to parse a session identifier

=cut

=head1 DESCRIPTION

=over 4

=cut

sub initialise ($);
sub new ($);
sub Parse ($$);
sub Usage ($);

=item $parserp->initialise();

Used internally to (re)initialise the object.

=cut

sub initialise ($) {
  my $this = shift;
  return $this;
  }

sub new ($) { TSH::Utility::new(@_); }

=item $argument_description = $parserp->Parse($line_parser)

Return the checked value of the command-line argument,
or () if the argument is invalid.

=cut

sub Parse ($$) {
  my $this = shift;
  my $line_parser = shift;
  my $value = $line_parser->GetArg();
  if (!defined $value) {
    $line_parser->Error("You need to specify a session identifier with this command.");
    return ();
    }
  if ($value =~ /([^-\w])/) {
    $line_parser->Error("'$value' does not look like a session identifier, because it contains the illegal character '$1'.");
    return ();
    }
  return $value;
  }

=item $argument_description = $this->Usage()

Briefly describe this argument's usage (in a word or hyphenated phrase)

=cut

sub Usage ($) {
  my $this = shift;
  return 'session-id';
  }

=back

=cut

1;




