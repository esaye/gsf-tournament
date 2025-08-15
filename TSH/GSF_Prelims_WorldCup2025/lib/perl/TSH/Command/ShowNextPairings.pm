#!/usr/bin/perl

# Copyright (C) 2005-2014 John J. Chew, III <jjchew@math.utoronto.ca>
# All Rights Reserved

package TSH::Command::ShowNextPairings;

use strict;
use warnings;

use TSH::Log;
use TSH::Utility qw(Debug DebugOn OpenFile Ordinal);

our (@ISA) = qw(TSH::Command);

my %StateOfNextPairings;
# A hash to keep us from writing to the filesystem too often.
# Simply a local copy for each division of maxp and maxs.

=pod

=head1 NAME

TSH::Command::ShowNextPairings - implement the C<tsh> ShowNextPairings command

=head1 SYNOPSIS

  my $command = new TSH::Command::ShowNextPairings;
  my $argsp = $command->ArgumentTypes();
  my $helptext = $command->Help();
  my (@names) = $command->Names();
  $command->Run($tournament, @parsed_arguments);
  
=head1 ABSTRACT

TSH::Command::ShowNextPairings is a subclass of TSH::Command.

=cut

=head1 DESCRIPTION

=over 4

=cut

sub initialise ($@);
sub new ($);
sub Run ($$@);

sub initialise ($@) {
  my $this = shift;

  $this->SUPER::initialise(@_);
  $this->{'help'} = <<'EOF';
Use this command to display the pairings for this division for the 
round after the latest one with pairings.
EOF
  $this->{'names'} = [qw(snp shownextpairings)];
  $this->{'argtypes'} = [qw(Division)];

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
  my ($dp) = @_;
  my $config = $tournament->Config();
  my $html_suffix = $config->Value('html_suffix');

  my $round = 0;

  Debug 'SNP', "Doing SNP\n";
  Debug 'SNP', "SNP:  Div is " . $dp->Name() . "\n";
  Debug 'SNP', "SNP:  maxp = %d, maxs = %d\n",  $dp->{'maxp'}, $dp->{'maxs'};

  my $dname = '';
  my $dname_hyphen = '';
  if ($dp) {
    $dname = $dp->Name();
    $dname_hyphen = "$dname-";
  }


    $round = sprintf("-%03d", $dp->{'maxs'} + 2 );
    return if ( (defined $StateOfNextPairings{$dname}->{'maxs'} &&
	       $StateOfNextPairings{$dname}->{'maxs'} == $dp->{'maxs'}) &&
	      (defined  $StateOfNextPairings{$dname}->{'maxp'} &&
		 $StateOfNextPairings{$dname}->{'maxp'} == $dp->{'maxp'} ) );
  if ( $dp->{'maxp'} >= $dp->{'maxs'} + 1 ) {
    Debug 'SNP', "change detected;  maxp was %d, maxs was %d\n", 
                 $StateOfNextPairings{$dname}->{'maxp'}, 
                 $StateOfNextPairings{$dname}->{'maxs'};
    foreach my $fn ( ('pairings', 'alpha-pairings') ) {
      my $origfn = $config->MakeHTMLPath("$dname_hyphen$fn$round$html_suffix");
      if ( -e $origfn ) {
	Debug 'SNP',  "Found $origfn\n";
	  my $copyfn = $origfn;
	  $copyfn =~ s/-\d+\././;
	  TSH::Utility::UpdateFile( $origfn, $copyfn );
          $StateOfNextPairings{$dname}->{'maxs'} = $dp->{'maxs'};
          $StateOfNextPairings{$dname}->{'maxp'} = $dp->{'maxp'};
          # We don't update the state record until we've found an appropriate
          # pairings report--sometimes the hook_division_update will fire
          # before the report is ready.
        } # Found pairings file 
      else
	{
	  Debug 'SNP',  "$origfn not present\n";
	}
      }
    }
  else # Pairings not ready
    {
      Debug 'SNP',  "Pairings not ready\n";
      $StateOfNextPairings{$dname}->{'maxs'} = $dp->{'maxs'};
      $StateOfNextPairings{$dname}->{'maxp'} = $dp->{'maxp'};
      foreach my $fn ( ('pairings', 'alpha-pairings') ) {
	my $logp = new TSH::Log($tournament, $dp, $fn, '', {
          'title' => "No Pairings Yet",
          'noconsole' => 1 ,
	  'refresh' => $config->Value('pairings_refresh'),
          'notext' => 1,
							     });
	$logp->Write( '', '<p class="number" align="center">Pairings for Div ' 
                 . $dp->Name() . ' this round are not yet available.  Please stand by.</p>');
	$logp->Close();
      }
    }
  }


1;
