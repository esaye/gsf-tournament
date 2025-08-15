#!/usr/bin/perl

use strict;
use warnings;

# canonicalise CSV data, mainly for testing the CSV library

use lib './lib/perl';
use TSH::Utility::CSV;

sub Main ();

Main;

sub Main () {
  local($/) = undef;
  my $csv = scalar(<>);
  print TSH::Utility::CSV::Encode ((TSH::Utility::CSV::Decode $csv, {}), {});
  }
