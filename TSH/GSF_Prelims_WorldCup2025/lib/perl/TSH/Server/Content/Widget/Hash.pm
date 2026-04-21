#!/usr/bin/perl

# Copyright (C) 2012 John J. Chew, III <jjchew@math.utoronto.ca>
# All Rights Reserved

package TSH::Server::Content::Widget::Hash;

use strict;
use warnings;
use TSH::Utility;
use HTTP::Message qw(EncodeEntities);

# our (@ISA) = qw(Exporter);
# our (@EXPORT_OK) = qw();

=pod

=head1 NAME

TSH::Server::Content::Widget::Hash - TSH user interface widget of type Hash

=head1 SYNOPSIS

  my $w = new TSH::Server::Content::Widget('type' => ['hash',{'key'=>\$keytype,'value'=>\$valuetype}], 'name' => $name, 'value' => $value);
  $html .= $w->RenderHTML();
  $value = $w->GetValue(\%param);
  
=head1 ABSTRACT

This class represents a TSH user interface widget of type Hash.

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
  my %values;
  
  for my $key_value (@{$this->{'subwidgets'}}) {
    my ($key, $value) = @$key_value;
    $values{$key->GetValue($paramp)} = $value->GetValue($paramp);
    }
  return \%values;
  }

=item $widget->Initialise(%argh);

Perform subclass-specific initialisation.

=cut

sub initialise ($@) {
  my $this = shift;
  my ($type_data, %argh) = @_;
  my $type_options = $this->{'type_options'} = $type_data->[1] || {};
  for my $required (qw(key value)) {
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
  my $valuesh = $this->{'value'};
  my $i = 0;
  for my $key (keys %$valuesh) {
    my $value = $valuesh->{$key};
    $value = $this->{'default_subvalue'} unless defined $value;
    push(@subwidgets, [
      new TSH::Server::Content::Widget(
	'type' => $type_options->{'key'},
	'name' => join('_', $name, $i, 'k'),
	'value' => $key,
	),
      new TSH::Server::Content::Widget(
	'type' => $type_options->{'value'},
	'name' => join('_', $name, $i, 'v'),
	'value' => $value,
	),
      ]);
    $i++;
    }
  $this->{'subwidgets'} = \@subwidgets;

  return $this;
  # the rest of this is from back when this was DivHash.pm
  my (@bad_divs);
  my (@division_widgets);
  for my $dp ($this->{'tourney'}->Divisions()) {
    my $dname = $dp->Name();
    if ($dname =~ /\W/) {
      push(@bad_divs, EncodeEntities($dname));
      }
    else {
      push(@division_widgets, [
	EncodeEntities($dname), 
	new TSH::Server::Content::Widget(
	  'type' => $this->{'subtype'}, 
	  'subtype' => $this->{'subsubtype'}, 
	  'name' => "${name}_$dname",
	  'value' => $this->{'value'}{$dname} || $this->{'default_value'},
          )
	]);
      }
    }
  $this->{'subwidgets'} = \@division_widgets;
  if (@bad_divs) {
    $this->{'error'} = 'This event has one or more divisions whose names include non-alphabetic characters (' . join(',', @bad_divs) . '. This practice is deprecated, and not supported on this page.';
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
  my $tourney = $this->{'tourney'};

  my $value = $this->{'value'} || {};
  my $html .= qq(<div class=hash>);
  for my $key_value (@{$this->{'subwidgets'}}) {
    my ($key, $value) = @$key_value;
    $html .= "<div class=hent>"
      . "<div class=key>" . $key->RenderHTML() . "</div>"
      . "<div class=value>" . $value->RenderHTML() . "</div>"
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

