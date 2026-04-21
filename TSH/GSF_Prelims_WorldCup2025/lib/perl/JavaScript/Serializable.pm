#!/usr/bin/perl

# Copyright (C) 2007 John J. Chew, III <jjchew@math.utoronto.ca>
# All Rights Reserved

package JavaScript::Serializable;

use strict;
use warnings;

# use UNIVERSAL qw(can);

=pod

=head1 NAME

JavaScript::Serializable - provide JavaScript serialization to classes

=head1 SYNOPSIS

  package MyClass;
  our (@ISA);
  push(@ISA, qw(JavaScript::Serializable));
  sub EXPORT_JAVASCRIPT { 
    return ( 'mykey1' => 'jskey1', 'mykey2' => 'jskey2', ... );
    }
  my $x = new MyClass;
  my $javascript = $x->ToJavaScript();
  
=head1 ABSTRACT

This Perl library adds JavaScript serialization to its subclasses.
Class objects must be hash references.
Only those object fields explicitly exported by &EXPORT_JAVASCRIPT
will be serialized.
Field keys may be remapped using &EXPORT_JAVASCRIPT.
Scalar values will be translated as strings or numbers depending on 
what Perl thinks they are.
List and hash reference values in object fields will be iterated
over; other object references must be to other subclasses of 
JavaScript::Serializable.

=cut

sub FromJSON ($);
sub FromJSONStringLiteral ($);
sub ToJavaScriptAny ($);

=head1 DESCRIPTION

=over 4

=cut

my $gkTrue = do { bless \(my $dummy = 1), "JSON::Boolean" };
my $gkFalse = do { bless \(my $dummy = 0), "JSON::Boolean" };
my $gkWhiteRE = qr[ \t\r\n];
my (%gkEscaped) = (
  '"' => '"',
  '\\' => '\\',
  '/' => '/',
  'b' => "\b",
  'f' => "\f",
  'n' => "\n",
  'r' => "\r",
  't' => "\t",
  );

=item ($converted, $rest) = FromJSON($jsonString);

Parse a JSON string, for use where the modern standard library JSON.pm
is unavailable.

Returns converted data as C<$converted>, and unparsed trailing data as C<$rest>.

Die on parse error.

=cut

sub FromJSON ($) {
  my $s = shift;
  $s =~ s/^$gkWhiteRE+//;
  # null literal
  return (undef, $s) if $s =~ s/^null$gkWhiteRE*//;
  # Boolean literal
  return ($gkFalse, $s) if $s =~ s/^false$gkWhiteRE*//;
  return ($gkTrue, $s) if $s =~ s/^true$gkWhiteRE*//;
  # numeric literal
  return ((eval $1), $s) 
   if $s =~ s/^(-?(?:0|[1-9]\d*)(?:\.\d+)?(?:[eE][-+]\d+)?)$gkWhiteRE*//;
  # string literal
  return ((FromJSONStringLiteral $1), $s) 
    if $s =~ s/^"((?:[^\\"]|\\(?:["\\\/bfnrt]|u[0-9a-fA-F]{4}))*)"$gkWhiteRE*//;
  # array
  if ($s =~ s/^\[//) {
    my $rv = [];
    ($rv->[0], $s) = FromJSON $s;
    while (1) {
      return ($rv, $s) if $s =~ s/^]$gkWhiteRE*//;
      die "error 1 parsing array at: $s" unless $s =~ s/^,$gkWhiteRE*//;
      ($rv->[@$rv], $s) = FromJSON $s;
      }
    }
  if ($s =~ s/^\{//) {
    my $rv = {};
    my $key;
    ($key, $s) = FromJSON $s;
    die "error 2 parsing object at: $s" unless $s =~ s/^:$gkWhiteRE*//;
    ($rv->{$key}, $s) = FromJSON $s;
    while (1) {
      return ($rv, $s) if $s =~ s/^}$gkWhiteRE*//;
      die "error 3 parsing object at: $s" unless $s =~ s/^,$gkWhiteRE*//;
      ($key, $s) = FromJSON $s;
      die "error 4 parsing object at: $s" unless $s =~ s/^:$gkWhiteRE*//;
      ($rv->{$key}, $s) = FromJSON $s;
      }
    }
  die "error 5 parsing JSON at: $s";
  }

=item $ref = FromJSONStringLiteral($JSONStringLiteral);

Parse the content of a JSON string literal, replacing the escape
sequences \" \\ \/ \b \f \n \r \t \uXXXX.

=cut

sub FromJSONStringLiteral ($) {
  my $s = shift;
  $s =~ s/\\(["\\\/bfnrt]|u([0-9a-fA-F]{4}))/$2 ? chr(hex($2)) : $gkEscaped{$1}/ge;
  return $s;
  }

sub Quote ($) {
  my $s = shift;
  $s =~ s/(["\\\n])/\\$1/g;
  return qq("$s");
  }

sub ToJavaScript ($) {
  my $this = shift;
  my (%keymap) = $this->EXPORT_JAVASCRIPT();
  my %data;
  while (my ($perlkey, $jskey) = each %keymap) {
    $data{$jskey} = $this->{$perlkey};
    }
  return ToJavaScriptAny(\%data);
  }

=item $js = ToJavaScriptAny($object);

Internal use only

=cut

sub ToJavaScriptAny ($) {
  my $value = shift;
  my $js = '';

  if (!defined $value) 
    { return "undefined"; }
  my $ref = ref($value);
  if ($ref eq '') 
  # looks_like_number thinks '1.' looks like a number, but we want it to be a string to save the '.'
#   { return (looks_like_number $value) ? $value : Quote($value); }
    { 
      if ($value =~ /^-?(?:\d+|\d*\.\d+)$/) {
	$value =~ s/^(-?)0+(\d)/$1$2/; # Some browsers abort on apparent octal
	return $value;
        }
      else {
        return Quote($value); 
        }
    }
  if (UNIVERSAL::can($value, 'ToJavaScript')) {
    return $value->ToJavaScript();
    }
  if ($ref eq 'ARRAY') 
    { return '[' . join(',', map { ToJavaScriptAny($_) } @$value) .  ']'; }
  if ($ref eq 'HASH') {
    return '{' . join(',', map { Quote($_) . ':' . ToJavaScriptAny($value->{$_}) } sort keys %$value) . '}';
    }
  if ($ref =~ /^Ratings::/) {
    return Quote($value->Name());
    }
  die "ToJavaScriptAny(): don't know what to do with $value";
  }

=back

=cut

=head1 BUGS

None reported so far.

=cut

1;
