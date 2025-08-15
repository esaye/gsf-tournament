#!/usr/bin/perl

# Copyright (C) 2005 John J. Chew, III <jjchew@math.utoronto.ca>
# All Rights Reserved

package TSH::ParseArgs::Ignore;

use strict;
use warnings;

use TSH::Utility;

=pod

=head1 NAME

TSH::ParseArgs::Ignore - handle a command-line argument that should be ignored

=head1 SYNOPSIS

  my $parser = new TSH::ParseArgs::Ignore;

=head1 ABSTRACT

This Perl module is used by C<ParseArgs.pm> to ignore command-line arguments.

=cut

=head1 DESCRIPTION

=over 4

=cut

sub initialise ($);
sub new ($);
sub Usage ($);

=item $parserp->initialise();

Used internally to (re)initialise the object.

=cut

sub initialise ($) {
  my $this = shift;
  return $this;
  }

=item $parserp = new ParserArgs::Ignore

Create a new instance

=cut

sub new ($) { TSH::Utility::new(@_); }

=item $argument_description = $this->Usage()

Briefly describe this argument's usage (in a word or hyphenated phrase)

=cut

sub Usage ($) {
  my $this = shift;
  return '';
  }

=back

=cut

1;


