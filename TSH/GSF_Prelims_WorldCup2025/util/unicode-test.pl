#!/usr/bin/perl

use utf8;
use strict;
use warnings;
use lib '../lib/perl';
use lib './lib/perl';
use TSH::Utility;

my $s;
print "VERSION 2\n";
print "STDOUT with default encoding:\n" or warn "print: $!";
print "あいうえお愛上尾 ไทย\n" or warn "print: $!";
binmode STDOUT, ":encoding(utf8)" or warn "binmode: $!";
print "STDOUT with utf8 encoding:\n" or warn "print: $!";
print "あいうえお愛上尾 ไทย\n" or warn "print: $!";
system "chcp 874";
binmode STDOUT, ':encoding(windows-874)' or warn "binmode: $!"; 
binmode STDIN, ':encoding(windows-874)' or warn "binmode: $!"; 
print "windows-874 encoding\n" or warn "print: $!";
print "ไทย\n" or warn "print: $!";
if (0) {
print "SetupWindowsUnicodeConsole()\n" or warn "print: $!";
TSH::Utility::SetupWindowsUnicodeConsole();
print "STDOUT with SWUC:\n" or warn "print: $!";
print "あいうえお愛上尾 ไทย\n" or warn "print: $!";
}
print "Please enter some Thai text: ";
$s = scalar(<STDIN>);
print "Received: $s\n" or warn "print: $!";
print "Please enter it again: " or warn "print: $!";
binmode STDIN, ":encoding(utf8)" or warn "binmode: $!";
$s = scalar(<STDIN>);
print "Received: $s\n" or warn "print: $!";
print "Test complete. Please email a screen dump to John Chew.\n";
