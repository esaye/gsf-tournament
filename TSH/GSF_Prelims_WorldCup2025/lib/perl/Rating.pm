#!/usr/bin/perl

# Copyright (C) 2012 John J. Chew, III <jjchew@math.utoronto.ca>
# All Rights Reserved

package Rating;

use strict;
use warnings;

use TSH::Utility;

=head1 SYNOPSIS

  use Rating;

  my $r = new Rating('primary' => 1800) || die;
  if (1800 != $r->Primary(1600)) { print "Rating has changed.\n"; }
  
=head1 ABSTRACT

This Perl module represents the value of a rating within a rating
system.  For the purposes of this module, a rating is an opaque
scalar (which could be a reference to a more complex data structure).
This module exists primarily to serve as a parent class for more
sophisticated rating data.

=cut

=head1 DESCRIPTION

=head2 Methods

=cut

BEGIN {
  use Exporter ();
  use vars qw(
    $VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS
    );
  $VERSION = do { my @r = (q$Revision: 1.1 $ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r }; 
  @ISA = qw(Exporter);
  @EXPORT = qw();
  @EXPORT_OK = qw(
    );
  %EXPORT_TAGS = ();
  }

=item $d->initialise();

(Re)initialise a Rating object, for internal use.

=cut

sub initialise ($) {
  my $this = shift;
  my (%argv) = @_;
  $this->{'primary'} = $argv{'primary'};
  }

=item $d = new Rating(%argv);

Create a new Rating object.  

=cut

sub new ($) { return TSH::Utility::newshared(@_); }

=item $p = $r->Primary();
=item $r->Primary($p);

Set or get the rating's primary value.

=cut

sub Primary ($;$) { TSH::Utility::GetOrSet('primary', @_); }

=back

=head1 BUGS

None known

=cut

1;
