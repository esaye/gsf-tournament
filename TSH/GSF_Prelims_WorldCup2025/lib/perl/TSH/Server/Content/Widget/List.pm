#!/usr/bin/perl

# Copyright (C) 2012 John J. Chew, III <jjchew@math.utoronto.ca>
# All Rights Reserved

package TSH::Server::Content::Widget::List;

use strict;
use warnings;
use TSH::Utility;
use HTTP::Message qw(EncodeEntities);

# our (@ISA) = qw(Exporter);
# our (@EXPORT_OK) = qw();

=pod

=head1 NAME

TSH::Server::Content::Widget::List - TSH user interface widget of type List

=head1 SYNOPSIS

  my $w = new TSH::Server::Content::Widget('type' => ['list',{'value'=>'integer'}], 'name' => $name, 'value' => [1,2,3]);
  $html .= $w->RenderHTML();
  $valuep = $w->GetValue(\%param);
  
=head1 ABSTRACT

This class represents a TSH user interface widget of type List.

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
  my @value;
  
  for my $subwidget (@{$this->{'subwidgets'}}) {
    push(@value, $subwidget->GetValue($paramp));
    }
  return \@value;
  }

=item $widget->Initialise(%argh);

Perform subclass-specific initialisation.

=cut

sub initialise ($@) {
  my $this = shift;
  my ($type_data, %argh) = @_;
  my $type_options = $this->{'type_options'} = $type_data->[1] || {};
  for my $required (qw(value)) {
    die "Missing required type option '$required'" unless defined $type_options->{$required};
    }
  for my $required (qw()) {
    $this->{$required} = $argh{$required};
    unless (defined $this->{$required}) {
      die "Missing required argument '$required'";
      }
    }
  for my $optional (qw(default_subvalue)) {
    $this->{$optional} = $argh{$optional} if defined $argh{$optional};
    }

  my $name = EncodeEntities $this->{'name'};
  my (@subwidgets);
  my (@key_widgets, @value_widgets);
  my $valuesp = $this->{'value'};
  for my $i (0..$#$valuesp) {
    my $value = $valuesp->[$i];
    my $i1 = $i + 1;
    $value = $this->{'default_subvalue'} unless defined $value;
    push(@subwidgets, 
      new TSH::Server::Content::Widget(
	'type' => $type_options->{'value'},
	'name' => join('_', $name, $i1),
	'value' => $value,
	),
      );
    }
  $this->{'subwidgets'} = \@subwidgets;

  return $this;
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
  my $html .= qq(<div class=list>);
  for my $subwidget (@{$this->{'subwidgets'}}) {
    $html .= "<div class=lent>" 
      . $subwidget->RenderHTML() 
      . "<div class=delete><button>delete</button></div>"
      . "</div>";
    }
  $html .= "<div class=add><button>add</button></div>";
  $html .= qq(</div>);
  return $html;
  }

=back

=cut

1;

