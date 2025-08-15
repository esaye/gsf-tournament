#!/usr/bin/perl

# Copyright (C) 2006-2018 John J. Chew, III <poslfit@gmail.com>
# All Rights Reserved

package TSH::Command::LOOK;

use strict;
use warnings;

require 'dawg.pl';

use TSH::Utility;

our (@ISA) = qw(TSH::Command);

=pod

=head1 NAME

TSH::Command::LOOK - implement the C<tsh> LOOK command

=head1 SYNOPSIS

  my $command = new TSH::Command::LOOK;
  my $argsp = $command->ArgumentTypes();
  my $helptext = $command->Help();
  my (@names) = $command->Names();
  $command->Run($tournament, @parsed_arguments);
  
=head1 ABSTRACT

TSH::Command::LOOK is a subclass of TSH::Command.

=cut

=head1 DESCRIPTION

=over 4

=cut

sub initialise ($$$$);
sub new ($);
sub Run ($$@);

=item $parserp->initialise()

Used internally to (re)initialise the object.

=cut

sub initialise ($$$$) {
  my $this = shift;
  my $path = shift;
  my $namesp = shift;
  my $argtypesp = shift;

  $this->{'help'} = <<'EOF';
This command checks words for acceptability, if you have a dictionary
file installed.
EOF
  $this->{'names'} = [qw(look)];
  $this->{'argtypes'} = [qw(Words)];
# print "names=@$namesp argtypes=@$argtypesp\n";
# if (-r 'lib/words/twl2006.dwg') {
#   &dawg'open(*TWL2006, 'lib/words/twl2006.dwg');
#   $this->{'dict'}{'TWL2006'} = *TWL2006;
#   }
  if (-r 'lib/words/twl2016.dwg') {
    &dawg'open(*TWL2016, 'lib/words/twl2016.dwg');
    $this->{'dict'}{'TWL2016'} = *TWL2016;
    }
# if (-r 'lib/words/sowpods2003.dwg') {
#   &dawg'open(*SOWPODS2003, 'lib/words/sowpods2003.dwg');
#   $this->{'dict'}{'SOWPODS2003'} = *SOWPODS2003;
#   }
# if (-r 'lib/words/collins.dwg') {
#    &dawg'open(*COLLINS, 'lib/words/collins.dwg');
#    $this->{'dict'}{'CSW2007'} = *COLLINS;
#    }
#  if (-r 'lib/words/csw2012.dwg') {
#    &dawg'open(*CSW2012, 'lib/words/csw2012.dwg');
#    $this->{'dict'}{'CSW2012'} = *CSW2012;
#    }
  if (-r 'lib/words/csw2015.dwg') {
    &dawg'open(*CSW2015, 'lib/words/csw2015.dwg');
    $this->{'dict'}{'CSW2015'} = *CSW2015;
    }
  if (-r 'lib/words/ods5.dwg') {
    &dawg'open(*ODS5, 'lib/words/ods5.dwg');
    $this->{'dict'}{'ODS5'} = *ODS5;
    }
  if (-r 'lib/words/sswl2016.dwg') {
    &dawg'open(*SSWL2016, 'lib/words/sswl2016.dwg');
    $this->{'dict'}{'SSWL2016'} = *SSWL2016;
    }

  return $this;
  }

sub new ($) { return TSH::Utility::new(@_); }

=item $command->Run($tournament, @parsed_args)

Should run the command in the context of the given
tournament with the specified parsed arguments.

=cut

sub Run ($$@) { 
  my $this = shift;
  my $tournament = shift;
  my (@words) = @_;
  my $count_good_plays = $tournament->Config()->Value('count_good_words');
  
  unless ($this->{'dict'}) 
    { $tournament->TellUser('elooknod'); return; }
  my %bad;
  my %ok;
  for my $dict (keys %{$this->{'dict'}}) { $ok{$dict} = 0; }
  for my $word (@words) {
    for my $dict (keys %ok) {
      if (&dawg'check($this->{'dict'}{$dict}, lc $word)) {
        $ok{$dict}++;
        }
      else {
        $bad{$dict}++;
        }
      }
    }
  for my $dict (sort keys %ok) {
    my $good = '';
    if ($count_good_plays) { 
      $good = " (".($ok{$dict}||0)." acceptable)";
      }
    printf "The play is%s acceptable in %s$good.\n", $bad{$dict} ? ' not' : '', $dict;
    }
  }

=back

=cut

=head1 BUGS

Should support multiple dictionaries.

Should rewrite dawg.pl as a modern Perl module.

=cut

1;
