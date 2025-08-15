#!/usr/bin/perl

# Copyright (C) 2010-2012 John J. Chew, III <jjchew@math.utoronto.ca>
# All Rights Reserved

package TSH::Utility::CSV;

use strict;
use warnings;

use Exporter;

our (@ISA) = 'Exporter';
our (@EXPORT_OK) = qw();

=pod

=head1 NAME

TSH::Utility::CSV - utilities for parsing and constructing CSV data

=head1 SYNOPSIS

  my $rowsp = TSH::Utility::CSV::Decode($csv, { 'quiet' => 1 });

  my $rowsp = TSH::Utility::CSV::DecodeFast($csv, { });

  my $csv = TSH::Utility::CSV::Encode(\@rows, { 'quiet' => 1 });

=head1 ABSTRACT

This library contains code for parsing and constructing CSV data in memory.

=cut

sub Decode ($$);
sub DecodeFast ($$);
sub Encode ($;$);

=head1 DESCRIPTION

=over 4

=cut
 
=item my (@rows) = Decode $csv, \%options;

Decode CSV data in C<$csv>) and return a reference to a list of
rows, each row being represented as a reference to a list of its
values.

Options include:

debug: emit verbose debug messages

quiet: if true, emit no warnings about bad input data

=cut

sub Decode ($$) {
  local ($_) = shift;
  my $options = shift;
  my @rows;
  my $row = [''];
  while (length($_)) {
    if (s/^(?:\015\012|\015|\012)//) {
      warn "DEBUG: end of line" if $options->{'debug'};
      push(@rows, \@$row);
      $row = [''];
      }
    elsif (s/^"([^"]*)"//) {
      warn "DEBUG: quoted cell" if $options->{'debug'};
      my $cell = $1;
      while (s/^("[^"]*)"//) { # "" => "
	$cell .= $1;
        }
      if (s/^("[^,\015\012]*)//) {
	warn "CSV error (1): missing close quote at: $1\n" unless $options->{'quiet'};
	$cell .= $1;
	}
      warn "DEBUG: cell = $cell" if $options->{'debug'};
      $row->[-1] .= $cell;
      }
    elsif (s/^"([^,\015\012]*)//) {
      my $cell = $1;
      warn "DEBUG: bad quoted cell = $cell" if $options->{'debug'};
      warn "CSV error (2): missing close quote at: $cell\n" unless $options->{'quiet'};
      $row->[-1] .= $cell;
      }
    elsif (s/^,//) {
      warn "DEBUG: end of cell" if $options->{'debug'};
      push(@$row, '');
      }
    elsif (s/^([^,"\015\012]*)//) { # can match empty string, must be last
      my $cell = $1;
      warn "DEBUG: unquoted cell = $cell" if $options->{'debug'};
      if (/^"/) {
        warn "CSV error (3): quote found in unquoted cell after: $cell\n" unless $options->{'quiet'};
	if (s/^([^,\012\015]*)//) { $cell .= $1; }
	}
      $row->[-1] .= $cell;
      warn "DEBUG: row = @$row" if $options->{'debug'};
      }
    else {
      die "CSV panic: don't know what to do with: $_";
      }
    }
  if (@$row > 1 || length($row->[0])) { push(@rows, \@$row); }
  return \@rows;
  }

=item my (@rows) = DecodeFast $csv, \%options;

Decode CSV data in C<$csv>) and return a reference to a list of
rows, each row being represented as a reference to a list of its
values.  Just like C<Decode>, except it's 20 times faster, but 
hasn't been thoroughly field-tested.

Currently has no options.

Die on bad input data.

=cut

sub DecodeFast ($$) {
  local ($_) = shift;
  my $options = shift;
  my (@rows);
  my $row;
  # TODO: rewrite this table-driven
  my $state = 0;
  # 0: have just ended a line (also the initial state)
  # 1: have seen at least the opening quote of a quoted field
  # 2: have seen a quote that might end a quoted field
  # 3: have just seen a field-separating comma
  # 4: have just seen a line-ending CR
  # 5: have seen at least one char in an unquoted field
  while (/("|[^"]+)/g) {
    if ($1 eq '"') {
         if ($state == 1) { $state = 2; }
      elsif ($state == 2) { $row->[-1] .= '"'; $state = 1; }
      elsif ($state == 3) { $state = 1; }
      elsif ($state == 5) { die "unexpected quote in row #".scalar(@rows); }
      else                { $state = 1; $row = ['']; push(@rows, $row); }
      }
    else {
#     warn qq(state=$state token="$1");
      if ($state == 1) { $row->[-1] .= $1; }
      else {
	my $lastch = substr($1, -1);
	my (@lines) = map { [split /,/, $_, -1] } split(/\015?\012/, $1, -1);
	if ($state == 0 or $state == 4) {
	  # RFC 4180 implicitly permits blank lines, and this only catches them
	  # at the beginnings of blocks
#  if (@{$lines[0]} == 0) { die "empty line in CSV at row #".scalar(@rows); }
	  }
	elsif ($state == 2) { # at end of quote
	  my $firstLine = shift @lines;
	  my $firstCell = shift @$firstLine;
 	  if (($firstCell//'') ne '') 
	    { die "partially quoted field in row #".scalar(@rows); }
	  push(@$row, @$firstLine);
	  }
	elsif ($state == 3) { # after comma
	  my $firstLine = shift @lines;
	  my $firstCell = shift @$firstLine;
	  $row->[-1] .= $firstCell;
	  push(@$row, @$firstLine);
	  }
	elsif ($state == 5) { # in unquoted field
	  my $firstLine = shift @lines;
	  my $firstCell = shift @$firstLine;
	  if ($firstCell ne '') { $row->[-1] .= $firstCell; }
	  push(@$row, @$firstLine);
	  }
	push(@rows, @lines);
	   if ($lastch eq "\012") { $state = 0; pop @rows; }
	elsif ($lastch eq "\015") { $state = 4; }
	elsif ($lastch eq ",")    { $state = 3; }
	else                      { $state = 5; }
	$row = $rows[-1];
	}
      }
    }
  return \@rows;
  }

=item my ($csv) = Encode \@rows, \%options;

Encode data in list of lists C<@rows>) and return a string containing its
CSV representation.

Options include:

(none)

=cut

sub Encode ($;$) {
  my $rowsp = shift;
  my $options = shift || {};
  my $csv = '';
  for my $rowp (@$rowsp) {
    $csv .= join(',',
      map { my $cell = $_; $cell = '' unless defined $cell; $cell =~ s/"/""/g; qq("$cell"); }
      @$rowp
      ) . "\n";
    }
  return $csv;
  }

=back

=cut

=head1 BUGS

None known.

=cut

1;
