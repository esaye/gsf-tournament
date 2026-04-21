#!/usr/bin/perl

# under development

use CGI qw(:standard);
use FileHandle;
use IPC::Open2;

$config::tshdir = "/Users/jjc/local/2006-dallas/tsh";

sub Die ($);
sub Main ();

Main;

sub Die ($) {
  print "Unexpected error: $_[0]\n";
  exit 1;
  }

sub Main () {
  print header('text/xml');
  chdir $config::tshdir or Die "chdir failed: $!";
  my $command = param('command');
  unless ($command) { 
    print "empty command\n";
    exit 0;
    }

  my $reader;
  my $writer;
  my $pid = open2($reader, $writer, "./tsh.pl");
  print $writer "$command\n";
  print $writer "quit\n";
  my (@lines) = <$reader>;
  waitpid $pid, 0;
  print "$#lines\n@lines";
  }
