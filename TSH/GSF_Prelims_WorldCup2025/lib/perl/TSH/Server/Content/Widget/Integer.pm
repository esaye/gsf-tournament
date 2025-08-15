#!/usr/bin/perl

# Copyright (C) 2012 John J. Chew, III <jjchew@math.utoronto.ca>
# All Rights Reserved

package TSH::Server::Content::Widget::Integer;

use strict;
use warnings;
use TSH::Utility;
use HTTP::Message qw(EncodeEntities);

# our (@ISA) = qw(Exporter);
# our (@EXPORT_OK) = qw();

=pod

=head1 NAME

TSH::Server::Content::Widget::Integer - TSH user interface widget of type Integer

=head1 SYNOPSIS

  my $w = new TSH::Server::Content::Widget('type' => 'boolean', 'name' => $name, 'value' => $value);
  $html .= $w->RenderHTML();
  $value = $w->GetValue(\%param);
  
=head1 ABSTRACT

This class represents a TSH user interface widget of type Integer.

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
  my $value = $paramp->{$this->{'name'}};
  return $this->CanonicaliseInteger($value);
  }

=item $widget->Initialise(%argh);

Perform subclass-specific initialisation.

=cut

sub initialise ($@) {
  my $this = shift;
  my ($type_data, %argh) = @_;
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

  my $value = $this->{'value'} || 0;
  return qq(<input name="$name" type=text maxlength=10 size=10 value="$value" onkeyup="return TSHValidateInteger(this)">);
  }

=back

=cut

1;

