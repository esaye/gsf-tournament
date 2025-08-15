#!/usr/bin/perl

# Copyright (C) 2012 John J. Chew, III <jjchew@math.utoronto.ca>
# All Rights Reserved

package TSH::PlugIn;

=pod

=head1 NAME

TSH::PlugIn - utility routines for TSH plug-ins

=head1 SYNOPSIS

  TSH::PlugIn::LoadAll($basedir);

  my $p = new TSH::PlugIn::Whatever(\%argh);
  $p->Welcome(\%argvp);

=head1 ABSTRACT

This module implements the required plug-in interface for the TSH plug-in Plus.

=head1 DESCRIPTION

=over 4

=cut

use strict;
use warnings;

use File::Spec;

sub new ($$);
sub Welcome ($$);

sub ImplementedRatingSystems ($) {
  return ();
  }

=item $p->initialise(\%options);

Performs common plug-in creation-time initialisation.

Dies on failure.

=cut

sub initialise ($$) {
  my $this = shift;
  my $argvp = shift;

  for my $required (qw()) {
    if (exists $argvp->{$required}) {
      $this->{$required} = $argvp->{$required};
      }
    else { 
      die "missing required option $required";
      }
    }

  my $base_class = ref($this);
  $base_class =~ s/.*://;
  $this->{'base_class'} = $base_class;

  return $this;
  }

=item $p->Welcome({'tournament' => $tournament});

Welcome the user to let them know the plug-in is installed.

=cut

sub Welcome ($$) {
  my $this = shift;
  my $argvp = shift;

  for my $required (qw(tournament)) {
    if (exists $argvp->{$required}) {
#     Carp::confess $argvp->{$required};
      $this->{$required} = $argvp->{$required};
      }
    else { 
      die "missing required option $required";
      }
    }
  for my $optional (qw(mode)) {
    if (exists $argvp->{$optional}) {
      $this->{$optional} = $argvp->{$optional};
      }
    }

  # we do not have to load commands defined by the plug-in here; they are
  # automatically picked up by VCommand::LoadAll() because the tsh.pl 
  # initialisation code adds the appropriate plug-in paths to @::INC.
  
  # load plug-in specific terminology file

  # load plug-in specific message file
  my $tournament = $this->{'tournament'};
  unless ($tournament->Silent()) {
    my $config = $tournament->Config();
    my (@filenames) = grep { -r $_ && -f $_ } map {
      /plugin/ ? () : do {
	my ($libvol, $libdir, $file) = File::Spec->splitpath($_);
	my (@libdir) = File::Spec->splitdir($libdir);
	shift @libdir if @libdir && $libdir[0] eq 'lib';
	$config->MakeLibPath(File::Spec->catpath($libvol, File::Spec->catdir(@libdir), $file), lc $this->{'base_class'});
	};
      } $tournament->UserMessage()->{0}->Filenames();
    $tournament->AddMessageFiles(@filenames);
    }

  no strict qw(refs);
  my $version = ${ref($this) . "::gkVersion"};
  use strict qw(refs);

  $tournament->TellUser("i_\L$this->{'base_class'}_welcome", $version);
  return 1;
  }

=back

=cut

1;

