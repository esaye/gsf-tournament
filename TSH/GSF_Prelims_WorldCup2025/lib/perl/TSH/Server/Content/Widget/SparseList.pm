#!/usr/bin/perl

# Copyright (C) 2012 John J. Chew, III <jjchew@math.utoronto.ca>
# All Rights Reserved

package TSH::Server::Content::Widget::SparseList;

use strict;
use warnings;
use TSH::Utility;
use HTTP::Message qw(EncodeEntities);

# our (@ISA) = qw(Exporter);
# our (@EXPORT_OK) = qw();

=pod

=head1 NAME

TSH::Server::Content::Widget::SparseList - TSH user interface widget of type SparseList

=head1 SYNOPSIS

  my $w = new TSH::Server::Content::Widget('type' => 'sparselist,integer', 'name' => $name, 'value' => $value);
  $html .= $w->RenderHTML();
  $value = $w->GetValue(\%param);
  
=head1 ABSTRACT

This class represents a TSH user interface widget of type SparseList.

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
  my $name = EncodeEntities $this->{'name'};
  my @value;
  
  for (my $i = 0; ; $i++) {
    my $key = $paramp->{"${name}_k_$i"};
    last unless defined $key;
    my $value = $paramp->{"${name}_v_$i"} || $this->{'default_value'};
    $value[$i] = $value;
    }
  die;
  for my $key (grep { /^\Q$name\E_\d+/ } keys %$paramp) {
    my ($i) = $key =~ /(\d+)$/;
    if (my $widget = $this->{'subwidgets'}[$i]) {
      $value[$i] = $widget->GetValue($paramp);
      }
    else {
      $value[$i] = (new TSH::Server::Content::Widget(
	'type' => $this->{'subtype'}, 
	'subtype' => $this->{'subsubtype'}, 
	'name' => "${name}_$i",
	))->GetValue($paramp);
      }
    }
  return \@value;
  }

=item $widget->Initialise(%argh);

Perform subclass-specific initialisation.

=cut

sub initialise ($@) {
  my $this = shift;
  my ($type_data, %argh) = @_;
  for my $required (qw(subtype)) {
    $this->{$required} = $argh{$required};
    unless (defined $this->{$required}) {
      die "Missing required argument '$required'";
      }
    }
  for my $optional (qw()) {
    $this->{$optional} = $argh{$optional} if defined $argh{$optional};
    }
  my (@subwidgets);
  my $name = EncodeEntities $this->{'name'};
  if (my $listp = $this->{'value'}) {
    die 'value of SparseList must be reference to list'
      unless ref($listp) eq 'LIST';
    for my $i (0..$#$listp) {
      my $value = $listp->[$i];
      next unless defined $value;
      $subwidgets[$i] = new TSH::Server::Content::Widget(
	'type' => $this->{'subtype'},
	'subtype' => $this->{'subsubtype'}, 
	'name' => "${name}_$i",
	'value' => $value,
        );
      }
    }
  $this->{'subwidgets'} = \@subwidgets;
  }

# only create instances through parent class
# sub new ($@) { return TSH::Utility::new(@_); }

=item $html = $widget->RenderHTML();

Default renderer: display an error message.

=cut

sub RenderHTML ($) {
  my $this = shift;
  my $name = EncodeEntities $this->{'name'};
  my $tourney = $this->{'tourney'};

  my $value = $this->{'value'} || {};
  my $html .= qq(<td class=value>);
  my $template = qq(<div class=division><span class=divname>%s</span> <input name="%s" type=text maxlength=10 size=10 value="%s"></div>);
  for my $i (0..$#{$this->{'subwidgets'}}) {
    my $widget = $this->{'subwidgets'}[$i] || next;
    $html .= "<div class=listentry><span class=index>$i</span> "
      . $widget->RenderHTML() . "</div>";
    }
  # TODO: create/delete entries
  # TODO: should let user edit keys as well as values
  $html .= qq(</td>);
  return $html;
  }

=back

=cut

1;

