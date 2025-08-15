#!/usr/bin/perl

use strict;
use warnings;

use ExtUtils::testlib;
use TSH::Pair;
use Data::Dumper;

my $rv = TSH::Pair::Resolve([1,2,3,4,6]);
print Dumper($rv);


