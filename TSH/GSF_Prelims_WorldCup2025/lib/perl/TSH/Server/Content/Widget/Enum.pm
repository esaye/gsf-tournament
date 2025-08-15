#!/usr/bin/perl

# Copyright (C) 2012 John J. Chew, III <jjchew@math.utoronto.ca>
# All Rights Reserved

package TSH::Server::Content::Widget::Enum;

use strict;
use warnings;
use TSH::Utility;
use HTTP::Message qw(EncodeEntities);

# our (@ISA) = qw(Exporter);
# our (@EXPORT_OK) = qw();

=pod

=head1 NAME

TSH::Server::Content::Widget::Enum - TSH user interface widget of type Enum

=head1 SYNOPSIS

  my $w = new TSH::Server::Content::Widget('type' => ['boolean',{'values'=>[qw(a b c)],'default'=>'b'}]', 'name' => $name, 'value' => $value);
  $html .= $w->RenderHTML();
  $value = $w->GetValue(\%param);
  
=head1 ABSTRACT

This class represents a TSH user interface widget of type Enum.

=head1 DESCRIPTION

=over 4

=cut

=item $value = $widget->GetValue(\%param);

Return value of widget, as found in C<\%param>, typically
a hash of values received in the form of CGI parameters.

=cut

sub GetValue ($) {
  my $this = shift;
  my $paramp = shift;
  my $values = $this->{'type_options'}{'values'};
  my $default = $this->{'type_options'}{'default'};
  $default = $values->[0] unless defined $default;

  my $user_value = $paramp->{$this->{'name'}};
  return $default unless defined $user_value;
  for my $value (@$values) {
    return $user_value if $user_value eq $value;
    }
  return $default;
  }

=item $widget->Initialise(%argh);

Perform subclass-specific initialisation.

=cut

sub initialise ($@) {
  my $this = shift;
  my ($type_data, %argh) = @_;
  my $type_options = $this->{'type_options'} = $type_data->[1] || {};
  for my $required (qw(values)) {
    die "Missing required type option '$required'" unless defined $type_options->{$required};
    }
  for my $required (qw()) {
    $this->{$required} = $argh{$required};
    unless (defined $this->{$required}) {
      die "Missing required argument '$required'";
      }
    }
  for my $optional (qw()) {
    $this->{$optional} = $argh{$optional} if defined $argh{$optional};
    }
  }

# only create instances through parent class
# sub new ($@) { return TSH::Utility::new(@_); }

=item $html = $widget->RenderHTML();

Default renderer: display an error message.

=cut

sub RenderHTML ($) {
  my $this = shift;
  my $name = EncodeEntities $this->{'name'};

  my $html = qq{<select name="$name">};
  my $values = $this->{'type_options'}{'values'};
  my $default = $this->{'type_options'}{'default'};
  $default = $values->[0] unless defined $default;
  for my $option (@$values) {
    $option = EncodeEntities $option;
    $html .= qq{<option value="$option"};
    $html .= qq{ selected="selected"} if $default eq $option;
    $html .= qq{>$option</option>};
    }
  $html .= qq{</select>};
  return $html;
  }

=back

=cut

1;

