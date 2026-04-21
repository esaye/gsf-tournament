#!/usr/bin/perl

# Copyright (C) 2012 John J. Chew, III <jjchew@math.utoronto.ca>
# All Rights Reserved

package TSH::PlugInManager;

=pod

=head1 NAME

TSH::PlugInManager - routines for managing TSH plug-ins

=head1 SYNOPSIS

  use TSH::PlugInManager;
  our $gPlugInManager;
  BEGIN { $gPlugInManager = new TSH::PlugInManager({'basedir' => './plugins'}); }

=head1 ABSTRACT

This module implements a manager for the TSH plug-in system.

=head1 DESCRIPTION

A list of all available plug-ins (installed or not) can be
found in lib/plugins.txt.

A new plug-in architecture was developed in 2012.  Older plug-ins
(dict, pix-cs and pix-naspa) are called "type 1", store their
files outside of the newer plugins/ directory, and use arbitrary
and ad hoc APIs.

Newer ones (core, plus, test, thai) are called "type 2", store
their files in plugins/, and are accessed through TSH::Plugin
and TSH::PluginManager.

=over 4

=cut

use strict;
use warnings;
use File::Spec;
use threads::shared;
use TSH::PlugIn;
use TSH::Utility;
use WebUpdate;

=item $pim->CallAll('Method', @argv);

Invoke a method on all installed plug-ins, and return a reference
to a hash mapping plug-in name to reference to returned list value.

=cut

sub CallAll ($$@) {
  my $this = shift;
  my $method = shift;
  my (@argv) = @_;

  my %rv;
  while (my ($name, $plugIn) = each %{$this->{'registry'}}) {
    no strict 'refs';
    $rv{$name} = [$plugIn->$method(@argv)];
#   print "@{$rv{$name}}\n";
    }
  return \%rv;
  }

=item $pim->GetPlugInIDs();

=cut

sub GetPlugInIDs ($$) {
  my $this = shift;
  return sort keys %{$this->{'catalogue_by_id'}};
  }

=item $pim->GetPlugInInfo(\%options);

=cut

sub GetPlugInInfo ($$) {
  my $this = shift;
  my $argvp = shift;
  my $pip;
  if (my $id = $argvp->{'id'}) { return $this->{'catalogue_by_id'}{$id}; }
  elsif (my $module = $argvp->{'module'}) 
    { return $this->{'catalogue_by_module'}{$module}; }
  else { return undef; }
  }

=item $pim->GetPlugInInfoField(\%options);

=cut

sub GetPlugInInfoField ($$) {
  my $this = shift;
  my $argvp = shift;
  my $field = $argvp->{'field'} || 'no-such-field';
  return undef unless $field =~ /^(?:id|title|module|description|terms|server|basepath|serverpath|manifest|secure|type|installed)$/;
  my $pip = $this->GetPlugInInfo($argvp) || return undef;
  return $pip->{$field};
  }

=item $p->initialise(\%options);

Initialise the manager, load all available plug-ins.

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
  for my $optional (qw(basedir listfile)) {
    if (exists $argvp->{$optional}) {
      $this->{$optional} = $argvp->{$optional};
      }
    }
  $this->{'catalogue_by_id'} = {}; # lists known plug-ins
  $this->{'catalogue_by_module'} = {}; # lists known plug-ins
  $this->{'registry'} = {}; # lists installed plug-ins
  $this->LoadCatalogue();
  $this->LoadInstalled();
  return $this;
  }

=item $success = $pim->IfAny($method, @argv);

Performs a short-circuit "OR" operation over the results of applying
the given method with the given arguments to each installed Type 2 plug-in.

=cut

sub IfAny ($$@) {
  my $this = shift;
  my $method = shift;
  my (@argv) = @_;
  for my $plugIn (values %{$this->{'registry'}}) {
    no strict 'refs';
    my $rv = $plugIn->$method(@argv);
    return $rv if $rv;
    }
  return undef;
  }

=item $pim->InitialiseAll(\%args);

Ask all registered plug-ins to initialise themselves using C<%args> and announce
themselves to the user through C<$args{'tournament'}>.

=cut

sub InitialiseAll ($$) {
  my $this = shift;
  my $args = shift;
  my $tournament = $args->{'tournament'};
  for my $plugIn (values %{$this->{'registry'}}) {
    $plugIn->Welcome($args) or $tournament->TellUser('eunwelcome', $plugIn);
    }
  }

=item $pim->LoadCatalogue();

Load information about all known plug-ins.

=cut

sub LoadCatalogue ($) {
  my $this = shift;
  my $listfile = $this->{'listfile'};
  return unless (defined $listfile) && -f $listfile;
  open my $fh, $listfile or do {
    warn "Cannot open plug-in list $listfile: $!";
    return;
    };
  local($/) = "\n\n";
  while (<$fh>) {
    chomp;
    my %pdata;
    eval { %pdata = map { split(/\s*=\s*/, $_, 2) } split (/\n/) };
    my $ok = 1;
    for my $required (qw(id title description terms basepath localpath server manifest)) {
      next if defined $pdata{$required};
      warn "Plug-in information record is missing required field '$required':\n\n$_\n";
      $ok = 0; 
      last;
      }
    next unless $ok;
    my $id = $pdata{'id'};
    my $localpath = $pdata{'localpath'};
    my $manifest = $pdata{'manifest'};
    $manifest = File::Spec->catfile($localpath, $manifest) if length($localpath);
    $pdata{'installed'} = 1 if -e $manifest;

    if ($this->{'catalogue_by_id'}{$id}) {
      warn "Ignoring duplicate plug-in information record (1) for '$id'\n";
      next;
      }
    $this->{'catalogue_by_id'}{$id} = \%pdata;
    if (my $module = $pdata{'module'}) {
      if ($this->{'catalogue_by_module'}{$module}) {
	warn "Ignoring duplicate plug-in information record (2) for '$module'\n";
	next;
	}
      $this->{'catalogue_by_module'}{$module} = \%pdata;
      }
    }
  }

=item $pim->LoadInstalled();

Load all installed Type 2 plug-ins.

=cut

sub LoadInstalled ($) {
  my $this = shift;
  my $plugins_dir = $this->{'basedir'};
  return unless (defined $plugins_dir) && -d $plugins_dir;
  opendir my $dh, $plugins_dir or do {
    warn "Cannot open plug-in directory $plugins_dir: $!";
    return;
    };
  my $plugin_pattern = qr/./;
  if (defined $::ENV{'TSH_PLUGINS'}) {
    $plugin_pattern = lc $::ENV{'TSH_PLUGINS'};
    $plugin_pattern =~ s/[^\s\w]/ /g;
    $plugin_pattern =~ s/ {2,}/ /g;
    $plugin_pattern =~ s/^ //;
    $plugin_pattern =~ s/ $//;
    $plugin_pattern =~ y/ /|/;
    $plugin_pattern = qr[^(?:$plugin_pattern)$]o;
    }
  while (my $plugin_name = readdir($dh)) {
    my $plugin_dir = File::Spec->catdir($plugins_dir, $plugin_name);
    next if $plugin_name =~ /^\./;
    if ($plugin_name !~ $plugin_pattern) {
      next;
      }
    my $PlugInName = ucfirst $plugin_name;
    my $class = "TSH::PlugIn::$PlugInName";
    if (my $cep = $this->{'catalogue_by_module'}{$class}) {
      $cep->{'installed'} = 0; # assume failure
      }
    elsif ($this->{'listfile'}) {
      warn "Plug-in module $class is not in the system catalogue.\n";
      }
    next unless -d $plugin_dir;
    next unless -r $plugin_dir;
    my $perl_dir = File::Spec->catdir($plugin_dir, 'lib/perl');
    next unless -d $perl_dir;
    eval "use lib '$perl_dir'";
    warn "use lib $perl_dir failed: $@" if $@;
    eval "package main; use $class";
    warn "use $class failed: $@" if $@;
    my $plugIn = $class->new({}) || next;
    $this->{'registry'}{$plugin_name} = $plugIn;
    if (my $cep = $this->{'catalogue_by_module'}{$class}) {
      $cep->{'installed'} = 1;
      }
    }
  }

sub new ($) { return TSH::Utility::new(@_); }

sub Names ($) {
  my $this = shift;
  return sort keys %{$this->{'registry'}};
  }

=item $rv = $pim->Update(\%args);

Try to update the specified plug-in.  Returns a positive value if
an update was successful and required, zero if no update was
required, or negative one error.

Arguments:

id (required unless module present): Plug-in ID.

module (required unless id present): Perl module name associated with a plug-in.

password (required if secure update): password for secure updates

tourney (optional): specifies a tournament object through which to
communicate with the user

username (required if secure update): username for secure updates

=cut

sub Update ($$) {
  my $this = shift;
  my $argvp = shift;

  my $pip = $this->GetPlugInInfo($argvp);
  my $tourney = $argvp->{'tourney'};
  unless ($pip) {
    if (my $id = $argvp->{'id'}) {
      if ($tourney) { $tourney->TellUser('enoplug', $id); }
      else { warn "No such plug-in: $id"; }
      }
    elsif (my $module = $argvp->{'module'}) { warn "No such module: $module"; }
    else { warn "Must specify plug-in ID or module"; }
    return -1;
    }
  unless ($pip->{'installed'}) {
    my $if_new = $argvp->{'if_new'} || 'warn';
    if ($if_new eq 'warn') {
      if ($tourney) { $tourney->TellUser('wnewplug', $pip->{'id'}); }
      else { warn "Installing instead of updating new plug-in '$pip->{'id'}'"; }
      }
    }
  warn "would update $pip->{'id'}"; return;
  my $wup;
  if ($pip->{'secure'}) {
    $wup = new WebUpdate(
      'basepath' => $pip->{'basepath'},
      'localpath' => $pip->{'localpath'},
      'manifest' => $pip->{'manifest'},
      'post' => {
	'username' => $argvp->{'username'}, 
	'password' => $argvp->{'password'},
        },
      'secure' => $pip->{'secure'},
      'server' => $pip->{'server'},
      'serverpath' => $pip->{'serverpath'},
      'tourney' => $tourney,
      );
    }
  else {
    $wup = new WebUpdate(
      'basepath' => $pip->{'basepath'},
      'localpath' => $pip->{'localpath'},
      'manifest' => $pip->{'manifest'},
      'server' => $pip->{'server'},
      'tourney' => $tourney,
      );
    }
  unless ($wup) {
    warn "Could not create new WebUpdate object, not updating plug-in $pip->{'id'}";
    return -1;
    }

  $tourney->TellUser('iconnupd', 'https://www.poslarchive.com', "plug-in $pip->{'id'}") if $tourney;
  my $status = $wup->Update();
  $tourney->TellUser($status > 0 ? 'iupdok' : $status == 0 
    ? 'iupdnone' : 'iupdabort') if $tourney;
  }

=back

=cut

1;
