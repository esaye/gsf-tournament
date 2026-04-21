#!/usr/bin/perl

# Copyright (C) 2012 John J. Chew, III <jjchew@math.utoronto.ca>
# All Rights Reserved

package TSH::Server::Content::Widget;

use strict;
use warnings;
use TSH::Utility;
use HTTP::Message qw(EncodeEntities);

# our (@ISA) = qw(Exporter);
# our (@EXPORT_OK) = qw();

=pod

=head1 NAME

TSH::Server::Content::Widget - user interface widgets for TSH

=head1 SYNOPSIS

  my $w = new TSH::Server::Content::Widget('type' => $type,
    'subtype' => $subtype, 'name' => $name, 'value' => $value);
  $w2 = new TSH::Server::Content::Widget('type' => 'enum', 
    'subtype' => [qw(a b c)], 'name' => 'multiple choice',
    'value' => 'a');
  $w3 = new TSH::Server::Content::Widget('type' => 'divhash', 
    'subtype' => 'enum', 'name' => 'division_rating_system',
    'subsubtype' => [qw(CSW OWL)],
    'value' => {'A' => 'CSW'}, 'default_subvalue' => 'OWL');
  $html .= $w->RenderHTML();
  $value = $w->GetValue(\%param);
  
=head1 ABSTRACT

This class is a parent class for user interface widgets used by TSH.

=head1 DESCRIPTION

=over 4

=cut

sub CanonicaliseInteger ($$) {
  my $this = shift;
  my $value = shift;
  return 0 unless defined $value;
  $value =~ s/\..*//;
  my $sign = '';
  $sign = $1 if $value = s/^([-+])//;
  $value =~ s/\D//g;
  return 0 + "$sign$value";
  }

sub CanonicaliseString ($$) {
  my $this = shift;
  my $value = shift;
  $value = '' unless defined $value;
  return $value;
  }

=item $value = $widget->GetValue(\%param);

Default value getter: return undefined value.

When overridden, the subclass should look for a value in C<\%param>),
which typically contains data received in the form of CGI parameters.

=cut

sub GetValue ($$) {
  my $this = shift;
  my $paramp = shift;
  return undef;
  }

my (%dispatch) = (
  'boolean' => 'Boolean',
  'enum' => 'Enum',
  'hash' => 'Hash',
  'integer' => 'Integer',
  'list' => 'List',
  'sparselist' => 'SparseList',
  'string' => 'String',
  );

sub initialise ($@) {
  my $this = shift;
  my (%argh) = @_;
  for my $required (qw(name type)) {
    $this->{$required} = $argh{$required};
    unless (defined $this->{$required}) {
      die "Missing required argument '$required'";
      }
    }
  for my $optional (qw(value)) {
    $this->{$optional} = $argh{$optional} if defined $argh{$optional};
    }
  my $type = $this->{'type'};
  die "widget type must be reference to array, not scalar ('$type')" unless ref($type);
  die "widget type must be reference to array, not " . ref($type) unless ref($type) eq 'ARRAY';
  die "widget type have length at least 1, not " . scalar(@$type) unless @$type >= 1;
  die "widget type have length at most 2, not " . scalar(@$type) unless @$type <= 2;
  my $basetype = $type->[0];
  die "widget base type is undefined" unless defined $basetype;
  die "first element of widget type must be scalar, not reference to " . ref($basetype) unless ref($basetype) eq '';
  my $subclass = $dispatch{$basetype} || die "Unknown base type: '$basetype'";
  if (@$type == 2) {
    my $options = $type->[1];
    die "widget type options are explicitly undefined" unless defined $options;
    die "widget type options must be a hash, not a scalar" unless ref($options);
    die "widget type options must be a hash, not a reference to " . ref($options) unless ref($options) eq 'HASH';
    }
  $subclass = "TSH::Server::Content::Widget::$subclass";
  eval "use $subclass";
  die "Cannot load subclass '$subclass': $@" if $@;
  bless $this, $subclass;
  $this->initialise($type, %argh);
  }

sub new ($@) { return TSH::Utility::new(@_); }

=item $html = $widget->RenderHTML();

Default renderer: display an error message.

=cut

sub RenderHTML ($) {
  my $this = shift;
  my $type = EncodeEntities $this->{'type'};
  my $name = EncodeEntities $this->{'name'};

  return qq{<span class="widget error">Unknown type ($type) for widget named ($name</span>};
  }

=back

=cut

1;
