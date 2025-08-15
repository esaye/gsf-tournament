#!/usr/bin/perl

# Copyright (C) 2005 John J. Chew, III <jjchew@math.utoronto.ca>
# All Rights Reserved

package TFile;

=pod

=head1 NAME

TFile - manipulate John Chew's Scrabble tournament .t files 

=head1 SYNOPSIS

  my $tf = new TFile 'a.t';
  while (my $datap = $tf->ReadLine()) {
    print "$datap->{'name'}\n";
    }
  $tf->Close();

  
=head1 ABSTRACT

This Perl module is used to read tournament data files in '.t' file format.

=head1 DESCRIPTION

=over 4

=cut

use strict;
use warnings;

sub new ($$);
sub Close($);
sub FormatLine($;$);
sub GetComment($$);
sub ParseLine($$;$);
sub ReadLine($;$);

=item $value = $tf->GetComment($key);

Return the text of lines beginning with C<#$key>.

=cut

sub GetComment ($$) {
  my $this = shift;
  my $key = shift;
  return $this->{'comments_by_keyword'}{$key};
  }

=item $tf = new TFile({'type' => 'file', 'filename' => $filename);

$tf = new TFile({'type' => 'string', 'data' => $string});

Create a new TFile object.  
Returns undef on failure.

C<game>: 'scrabble' (default) or 'sudoku', affects formatting

C<encoding>: 'utf8' (e.g.) overrides the default isolatin1 encoding for files

C<inline_comments>: 1 will enable in-line comment parsing

=cut

sub new ($$) {
  my $proto = shift;
  my $argvp = shift;
  my $class = ref($proto) || $proto;

  unless (ref($argvp)) {
    $argvp = { 'type' => 'file', 'filename' => $argvp };
    }

# my $this = $class->SUPER::new();
  my $this = {
    'cursor' => 1, # next line to return
    'lines' => [ undef ],
    'comments_by_line' => { }, # saved in case we want to reconstruct the file
    'comments_by_keyword' => { }, 
    'game' => $argvp->{'game'} || 'scrabble',
    'no_random' => $argvp->{'no_random'},
    };
  if ($this->{'game'} eq 'scrabble') {
    $this->{'line_pattern'} = qr<^(.+?\S)\s+(\d+(?:[.+]\d+)*)\s*([\d\s]*);\s*([-\d\s]*)((?:;[^;]*)*)$>;
    }
  elsif ($this->{'game'} eq 'sudoku') {
    $this->{'line_pattern'} = qr<^(.+?\S)\s+(\d+(?:[.+]\d+)?)\s*([\d\s]*);\s*([-.\d\s]*)((?:;[^;]*)*)$>;
    }
  else {
    die "Bad value for 'game' parameter: '$this->{'game'}'";
    }
  my $data;
  if ($argvp->{'type'} eq 'file') {
    my $encoding = $argvp->{'tfile_encoding'} || 'isolatin1';
    open my $fh, "<:encoding($encoding)", $argvp->{'filename'} or return undef;
    local($/) = undef;
    $this->{'filename'} = $argvp->{'filename'};
    $data = scalar(<$fh>);
    $data =~ s/^(?:\x{feff}|\xef\xbb\xbf)// if defined $data;
    close $fh;
    }
  elsif ($argvp->{'type'} eq 'string') {
    $this->{'filename'} = '(string)';
    $data = $argvp->{'data'};
    }
  else {
    die "Bad type for TFile source: '$argvp->{'type'}'";
    }

  warn "no data" unless defined $data;
  {
    my $lineno = 1;
    local ($_);
    for (split(/[\012\015]+/, (defined $data) ? $data : '')) {
      if (/^\s*#.*/) {
	$this->{'comments_by_line'}{$lineno} = $_;
	if (/^\s*#(\w+)\s*(.*)$/) {
	  my $key = $1;
	  my $value = $2;
	  if ($this->{'comments_by_keyword'}{$key}) {
	    $value = $this->{'comments_by_keyword'}{$key} . "\n" . $value;
	    }
	  $this->{'comments_by_keyword'}{$key} = $value;
	  }
        }
      else {
	s/#.*// if $argvp->{'inline_comments'};
	s/\s+$//;
	s/^\s+//; 
	if (0 == length($_)) {
	  $lineno--;
	  next;
	  }
	s/$/;/ unless /;/;
	push(@{$this->{'lines'}}, { 'text' => $_ });
        }
      }
    continue {
      $lineno++;
      }
  }
  bless($this, $class);
  return $this;
  }

=item $success = $fh->Close();

Explicitly closes the .t file.

=cut

sub Close ($) {
  my $this = shift;
  
  # Currently a nop, because we have to slurp the whole file in one go
  # to handle different line breaks.  
  return 1;
  }

=item $line = FormatLine($datap[, $public]);

Recreate a formatted $line from its parsed data.

If C<$public> is true, strip private information
(currently consisting only of data entry passwords).

=cut

sub FormatLine ($;$) {
  my $p = shift;
  my $public = shift;
  my $s = sprintf("%-22s %5s %s; %s",
    $p->{'name'},
    $p->{'rating'},
    join(' ', map { (defined $_) ? $_ : '00' } @{$p->{'pairings'}}),
    join(' ', map { (defined $_) ? $_ : '00' } @{$p->{'scores'}}));
  if ($p->{'etc'}) {
    my $etcp = $p->{'etc'};
    for my $key (sort keys %$etcp) {
      next if $public && $key eq 'password';
      if (my $wordsp = $etcp->{$key}) {
	if (@$wordsp) {
#	for my $i (0..$#$wordsp) { warn "undefined value at i=$i in $key among @$wordsp for $p->{'name'}" unless defined $wordsp->[$i]; }
	  $s .= join(' ', ';', $key, map { 
	    my $extra = $_;
	    $extra = '00' unless defined $extra;
#    warn "$p->{'name'} @{$p->{'etc'}{'class'}} $key $extra from @$wordsp";
	    $extra =~ s/[\\;]/\\$&/g;
	    $extra;
	    } @$wordsp);
	  }
        }
      }
    }
  $s .= "\n";
  return $s;
  }

=item $datap = $fh->ReadLine($shared);

Read and parse one line from the file.
Returns a hash whose keys are C<id>, C<name>, C<rating>, C<pairings>,
C<scores>, C<rnd> and C<etc>.
If $shared is true, the return value is thread-shared.

=cut

sub ReadLine ($;$) {
  my $this = shift;
  my $shared = shift;

  my $id = $this->{'cursor'};
  my $linep = $this->{'lines'}[$id];
  my $text = $linep->{'text'};
  return undef unless defined $text;
  return $linep->{'data'} if $linep->{'data'};
  my $data = $linep->{'data'} = $this->ParseLine($text, $shared)
    or die "Can't parse line $id in $this->{'filename'}: $text\n";
  $data->{'id'} = $id;
  $data->{'rnd'} = $this->{'no_random'} ? 0 : ((length($text) * (100+$this->{'cursor'}) * ord($text)) % 641);
  $this->{'cursor'}++;
  return $data;
  }

=item $datap = $fh->ParseLine($line[, $shared]) 

Parse a received input line into a data structure.
If $shared, then the data structure is thread-shared.

=cut

sub ParseLine ($$;$) {
  my $this = ref($_[0]) ? shift : { 'line_pattern' => 
    qr<^(.+?\S)\s+(\d+(?:[.+]\d+)*)\s*([\d\s]*);\s*([-\d\s]*)((?:;[^;]*)*)$>
    };
  my $s = shift;
  my $shared = shift;
  $s =~ s/; # \d+\s*$/;/;
  my($player, $rating, $pairings, $scores, $etc) 
#   = $s =~ /^([^;]+[^;\s\d])\s+(\d+(?:\.\d+)?)\s*([\d\s]*);\s*([-\d\s]*)((?:;[^;]*)*)$/;
    = $s =~ $this->{'line_pattern'};
  unless (defined $scores) {
    warn "Can't parse: $s\n";
    return undef;
    }
  my $data = {};
  my $pairingsp = [];
  my $scoresp = [];
  my $etcp = {};
  if ($shared) {
    &threads::shared::share($data);
    &threads::shared::share($pairingsp);
    &threads::shared::share($scoresp);
    &threads::shared::share($etcp);
    }
  $data->{'name'} = $player;
  $data->{'rating'} = $rating;
# warn "name=$player rating=$rating pairings=@$pairingsp";
  push(@$pairingsp, map { $_ eq '00' ? undef : $_ } split(/\s+/, $pairings));
  $data->{'pairings'} = $pairingsp;
  push(@$scoresp, map { $_ eq '00' ? undef : $_ } split(/\s+/, $scores));
  $data->{'scores'} = $scoresp;
  while (length($etc)) {
    my $extra = '';
    while (1) {
      if ($etc =~ s/^\\([\\;])// || $etc =~ s/^(\\|[^\\;]+)//) { $extra .= $1; }
      elsif ($etc =~ s/^;\s*// || $etc eq '') { last; }
      else { die "assertion failed: $etc"; }
      }
    next unless $extra =~ /\S/;
    my ($tag, @words) = split(/\s+/, $extra);
    warn "Overwriting duplicate $tag field for $player.\n"
      if exists $etcp->{$tag};
    my $words = [];
    if ($shared) {
      &threads::shared::share($words);
      }
    push(@$words, map { $_ eq '00' ? undef : $_ } @words);
    $etcp->{$tag} = $words;
    }
  $data->{'etc'} = $etcp;
  return $data;
  }

=back

=cut

1;
