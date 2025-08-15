#!/usr/bin/perl

package TSH::Pair;

use 5.000;
use strict;

require Exporter;
require DynaLoader;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
@ISA = qw(Exporter
	DynaLoader);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

# This allows declaration	use TSH::Pair ':all';
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.
%EXPORT_TAGS = ( );

@EXPORT_OK = ( );

@EXPORT = qw( );

$VERSION = '0.01';

bootstrap TSH::Pair $VERSION;

# Preloaded methods go here.

1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

TSH::Pair - Perl extension for blah blah blah

=head1 SYNOPSIS

  use TSH::Pair;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for TSH::Pair, created by h2xs. It looks like the
author of the extension was negligent enough to leave the stub
unedited.

Blah blah blah.

=head2 EXPORT

None by default.



=head1 SEE ALSO

Mention other useful documentation such as the documentation of
related modules or operating system documentation (such as man pages
in UNIX), or any relevant external documentation such as RFCs or
standards.

If you have a mailing list set up for your module, mention it here.

If you have a web site set up for your module, mention it here.

=head1 AUTHOR

John Chew, E<lt>jjc@nonetE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2005 by John Chew

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut
