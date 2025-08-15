#!/usr/bin/perl

# Copyright (C) 2005 John J. Chew, III <jjchew@math.utoronto.ca>
# All Rights Reserved

package TSH::ParseArgs::Division;

use strict;
use warnings;

use TSH::Division;
use TSH::Utility;

=pod

=head1 NAME

TSH::ParseArgs::Division - handle a command-line argument that should be a tournament division name

=head1 SYNOPSIS

  my $parser = new TSH::ParseArgs::Division;

=head1 ABSTRACT

This Perl module is used by C<ParseArgs.pm> to ignore command-line arguments.

=cut

=head1 DESCRIPTION

=over 4

=cut

sub initialise ($$);
sub new ($$);
sub Parse ($$);
sub Usage ($);

=item $parserp->initialise($processor);

Used internally to (re)initialise the object.

=cut

sub initialise ($$) {
  my $this = shift;
  $this->{'processor'} = shift;
  return $this;
  }

=item $parserp = new ParserArgs::Division($processor);

Create a new instance

=cut

sub new ($$) { TSH::Utility::new(@_); }

=item $argument_description = $this->Parse($line_parser)

Return the checked value of the command-line argument,
or () if the argument is invalid.

=cut

sub Parse ($$) {
  my $this = shift;
  my $line_parser = shift;
  my $value = $line_parser->GetArg();
  my $dp;
  my $matchdp = $line_parser->GetShared('division');
  my $tournament = $this->{'processor'}->Tournament();
found_div: {
  if (defined $value) {
    # check for class specifier
    if ($value =~ s/\{(.*)\}$//) {
      $line_parser->SetShared('class', $1);
      }
    $dp = $tournament->GetDivisionByName($value);
#   warn "dp=$dp matchdp=$matchdp";
    if (defined $dp) {
      # begin kludge to distinguish numerical division from players
      my $ok = 1;
#     warn $value;
      if ($value =~ /^\d+$/) {
	my $i = $line_parser->ParserIndex();
	my (@parsers) = @{$line_parser->Parsers()};
	my $argi = $line_parser->ArgumentIndex();
	my (@argv)= @{$line_parser->Arguments()};
#       warn join(',', $i, @parsers);
#       warn join(',', $argi, @argv);
	if ($argi == 2 && @argv == 3
	  && ref($parsers[$i]) eq 'TSH::ParseArgs::Player'
	  && ref($parsers[$i+1]) eq 'TSH::ParseArgs::Round0'
	  && ref($parsers[$i+2]) eq 'TSH::ParseArgs::Nothing'
	  ) {
	  $ok = 0;
	  }
        }
      if ($ok) {
	if ($matchdp) {
	  if ($matchdp->Name() ne $dp->Name()) {
	    $line_parser->Error("That player is not in division $value.");
	    return ();
	    }
	  }
	else {
	  $line_parser->SetShared('division', $dp); # for range-checking of pn
	  }
	last found_div;
        }
      }
    }
  if ($tournament->CountDivisions() == 1) {
    $line_parser->UnGetArg($value) if defined $value;
    $dp = ($tournament->Divisions())[0];
    $line_parser->SetShared('division', $dp); # for range-checking of pn
    last found_div;
    }
  elsif (defined $value) {
    if ($value =~ /^(\S*),(\S*)$/ || $value =~ /^([a-z][a-z]\S*)()$/i) {
      my $pp = $tournament->FindPlayer($1, $2, undef);
      if ($pp) {
	$dp = $pp->Division();
	$line_parser->SetShared('player', $pp);
	last found_div;
        }
      else {
	$line_parser->Error("Player match failed.");
	return ();
        }
      }
    elsif ($value =~ /^([a-zA-Z]+)(\d+)$/) {
      my $dn = $1;
      my $pn = $2;
      $dp = $tournament->GetDivisionByName($dn);
      if (!$dp) {
	$line_parser->Error("'$dn' is not a valid division name.");
        }
      else {
	my $pp = $dp->Player($pn);
	if ($pp) {
	  $line_parser->SetShared('player', $pp);
	  last found_div;
	  }
	else {
	  $line_parser->Error("'$pn' is not a valid player number in division '$dn'.");
	  return ();
	  }
	}
      }
    $line_parser->Error("I don't know a Division '$value'.");
    return ();
    }
  else {
    $line_parser->Error("You need to specify a division with this command.");
    return ();
    }
  } # found_div:
  # range check possible earlier arguments based on division-specific 
  # value of $dp->MaxRound0
  if (my $error = $line_parser->GetShared('round_error')) {
    if (my $max_round0 = $dp->MaxRound0()) {
      my $round = $line_parser->GetShared('round_value');
      if ($round > $max_round0 + 1) {
	$line_parser->Error({'code' => $error, 'argv' => [$round]});
	return ();
	}
      }
    }
  return $dp;
  }

=item $argument_description = $this->Usage()

Briefly describe this argument's usage (in a word or hyphenated phrase)

=cut

sub Usage ($) {
  my $this = shift;
  my $tournament = $this->{'processor'}->Tournament();
  if ($tournament->CountDivisions() == 1) {
    return '';
    }
  else {
    return 'division';
    }
  }

=back

=head1 BUGS

None known.

=cut

1;
