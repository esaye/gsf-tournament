#!/usr/bin/perl

# Copyright (C) 2005 John J. Chew, III <jjchew@math.utoronto.ca>
# All Rights Reserved

package TSH::Command::EVAL;

use strict;
use warnings;

use TSH::Utility;

our (@ISA) = qw(TSH::Command);

=pod

=head1 NAME

TSH::Command::EVAL - implement the C<tsh> EVAL command

=head1 SYNOPSIS

  my $command = new TSH::Command::EVAL;
  my $argsp = $command->ArgumentTypes();
  my $helptext = $command->Help();
  my (@names) = $command->Names();
  $command->Run($tournament, @parsed_arguments);
  
=head1 ABSTRACT

TSH::Command::EVAL is a subclass of TSH::Command.

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
This command evaluates (runs) an arbitrary Perl expression.
If you do not know what this means, do not use the command.
EOF
  $this->{'names'} = [qw(eval)];
  $this->{'argtypes'} = [qw(Expression)];
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
  my ($args) = join(' ', @_);
  
# my $rawargs = $_;
# chomp $rawargs;
# $rawargs =~ s/^\s*eval\s+//i;
# if (join(' ', split(/\s+/, $rawargs)) ne $args) {
#   $tournament->TellUser('wevalarg', $args, $rawargs);
#   }
# else {
#   $args = $rawargs;
#   }
  print join("\n", eval $args);
  print "\n";
  print "\$\@: '$@'\n" if $@;
  }

=back

=cut

=head1 BUGS

None known.

=cut

1;
