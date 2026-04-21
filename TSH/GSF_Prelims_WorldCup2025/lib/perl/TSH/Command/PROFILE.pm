#!/usr/bin/perl

# Copyright (C) 2012 John J. Chew, III <jjchew@math.utoronto.ca>
# All Rights Reserved

package TSH::Command::PROFILE;

use strict;
use warnings;

use TSH::Utility;

our (@ISA) = qw(TSH::Command);

=pod

=head1 NAME

TSH::Command::PROFILE - implement the C<tsh> PROFILE command

=head1 SYNOPSIS

  my $command = new TSH::Command::PROFILE;
  my $argsp = $command->ArgumentTypes();
  my $helptext = $command->Help();
  my (@names) = $command->Names();
  $command->Run($tournament, @parsed_arguments);
  
=head1 ABSTRACT

TSH::Command::PROFILE is a subclass of TSH::Command.

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
This command offers a command-line interface to your user profile.
Your profile gives default configuration values that will be used in
all of your tournaments, unless otherwise overridden.
To view your profile, enter "PROFILE SHOW".
To change a profile value, enter "PROFILE SET key value".
To delete a profile value, enter "PROFILE UNSET key".
EOF
  $this->{'names'} = [qw(profile)];
  $this->{'argtypes'} = [qw(ProfileCommand OptionalKey OptionalExpression)];
# print "names=@$namesp argtypes=@$argtypesp\n";

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
  my $command = uc shift;
  my ($key, $value) = @_;
  my $profile = $tournament->Profile();
  
  if ($command eq 'SHOW') {
    if (!$profile) {
      $tournament->TellUser('enoprofile');
      return;
      }
    if (my (@keys) = $profile->PersistentKeys()) {
      for my $key ($profile->PersistentKeys()) {
	print "config $key = " . $profile->RenderPerlValue($profile->Value($key)) . "\n";
	}
      }
    else {
      $tournament->TellUser('eemptyprofile');
      }
    return;
    }
  elsif ($command eq 'UNSET') {
    if ($key =~ /\W/) {
      $tournament->TellUser('ebadprofk', $key);
      return;
      }
    }
  elsif ($command eq 'SET') {
    if ($key =~ /\W/) {
      $tournament->TellUser('ebadprofk', $key);
      return;
      }
    my $type = TSH::Config::UserOptionType($key);
    unless ($type) {
      $tournament->TellUser('eunkprofk', $key);
      return;
      }
    unless (TSH::Config::UserOptionEditable($key)) {
      $tournament->TellUser('eroprofk', $key);
      return;
      }
    my $checked_value;
    $value =~ s/^\s+//; $value =~ s/\s+$//;
    if ($type->[0] =~ /^(?:enum|string)$/) {
      # permit and deal with bare strings
      if ($value !~ /^(?:".*"|'.*'|qq?\(.*\))$/) {
	$value = $profile->RenderPerlValue($value);
	}
      }
    $checked_value = eval $value;
    if ($@) {
      $tournament->TellUser('ebadprofv', $value, $@);
      return;
      }
    if (!$profile) {
      $profile = new TSH::Config('filename' => 'lib/profile.tsh',
	'type' => 'profile');
      $tournament->Profile($profile);
      }
    $profile->Value($key, $checked_value, 'persist' => 1);
    $profile->Save('mode' => 'update');
    $tournament->TellUser('iprofupd');
    return;
    }
  $tournament->TellUser('ebadprofc', $command);
  }

=back

=cut

=head1 BUGS

If we knew where the bugs were, we wouldn't need this command.

=cut

1;
