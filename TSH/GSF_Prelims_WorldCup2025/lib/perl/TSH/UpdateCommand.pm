#!/usr/bin/perl

# Copyright (C) 2020 John J. Chew, III <poslfit@gmail..com>
# All Rights Reserved

package TSH::UpdateCommand;

use strict;
use warnings;
use threads::shared;
use TSH::Utility qw(OpenFile);
use TSH::Command;

our (@ISA) = qw(TSH::Command);

=pod

=head1 NAME

TSH::UpdateCommand - common code for commands that update TSH code/data

=head1 SYNOPSIS

This subclass supports features common to commands that update TSH code/data
(the main code base, player photos, rating lists, etc.?), and exists to 
facilitate scripted access to update features.
  
=head1 ABSTRACT

$processor->GetCommandByName('UPDATE')->Load()->Check();

=cut

=head1 DESCRIPTION

=over 4

=item $command->Check();

Check to see if an update is advisable.

=cut

sub Check ($) {
  my $this = shift;
  die "this method should be overloaded";
  }

=item $command->CheckOne($manifest_fn, $title);

Check to see if one package needs updating.

=cut

sub CheckOne ($$$) {
  my $this = shift;
  my $manifest_fn = shift;
  my $title = shift;

  my $always_fn = $manifest_fn;
  $always_fn =~ s/(\.?\w+)$/-always$1/;
  my $never_fn = $manifest_fn;
  $never_fn =~ s/(\.?w*)$/-never$1/;
  if (-e $always_fn) { $this->Update($manifest_fn); return; }
  if (!-e $manifest_fn) { 
    print "The $title has not been fully installed or is missing its manifest file.\n";
    if (!-e $never_fn) { $this->PromptUpdate($title, $manifest_fn, $always_fn, $never_fn); }
    return;
    }
  my $age = int(-M $manifest_fn);
  if ($age > 7) {
    print "The $title has not been updated in $age days.\n";
    if (!-e $never_fn) { $this->PromptUpdate($title, $manifest_fn, $always_fn, $never_fn); }
    return; 
    }
  }

=item $command->PromptUpdate($title, $manifest_fn, $always_fn, $never_fn);

Prompt to offer to run an update.

=cut

sub PromptUpdate ($$$$$) {
  my $this =       shift;
  my $title =      shift;
  my $manifest_fn= shift;
  my $always_fn =  shift;
  my $never_fn =   shift;
  my $s = '';
  while ($s !~ /^\s*([ALNY])\s*$/i) {
    print "Would you like to update it now? Enter the first letter of your choice.\n";
    $s = TSH::Utility::ReadLine('update', "Yes, Later, Always, Never: ");
    unless ($s) { 
      print "\n" unless defined $s;
      print "If you're not sure, choose L.\n";
      $s = '';
      }
    $s = uc $s;
    }
  if ($s eq 'L') { return; }
  if ($s eq 'N') { close OpenFile('>', $never_fn); return; }
  if ($s eq 'A') { close OpenFile('>', $always_fn); }
  $this->Update($manifest_fn);
# print "Would you like to update it now? ";
  }

=item $command->Update($manifest_fn);

Run an update.

=cut

sub Update ($) {
  my $this = shift;
  my $manifest_fn = shift;
  $this->Run($this->Processor()->Tournament());
  my $now = time;
  utime $now, $now, $manifest_fn;
  }

=back

=cut

=head1 BUGS

=cut


