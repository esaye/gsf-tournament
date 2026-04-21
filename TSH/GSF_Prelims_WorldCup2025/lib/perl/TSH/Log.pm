#!/usr/bin/perl

# Copyright (C) 2005-2013 John J. Chew, III <poslfit@gmail.com>
# All Rights Reserved

package TSH::Log;

use strict;
use warnings;

use threads::shared;
use TSH::Utility qw(ConcatenateCarefully Error OpenFile PrintConsoleCrossPlatform);
use Fcntl ':flock';
use File::Copy; # copy
use File::Path; # mkpath
use File::Spec; # catfile

=pod

=head1 NAME

TSH::Log - Record displayed information in text and HTML format

=head1 SYNOPSIS

  # original interface
  my $log = new TSH::Log($tournament, $division, $type, $round, \%options);
  $log->Write($text, $html);
  $log->Close();

  # newer interface, dynamically measured columns
  my $log = new TSH::Log($tournament, $division, $type, $round, \%options);
  $log->ColumnClasses([qw(name score)]);
  $log->ColumnTitles({ 'text' => [qw(P S)], 'html' => [qw(Player Score)] });
  $log->ColumnAttributes(['id=1','id=s1']);
  $log->WriteRow(['jjc', 123], ['John Chew (#1)', 123]);
  $log->Close();

  # even newer interface, multiline titles and paging
  my $log = new TSH::Log($tournament, $division, $type, $round, \%options);
  $log->ColumnClasses([qw(name score)],'rowclass');
  $log->ColumnAttributes(['rowspan=2',]);
  $log->WriteTitle([qw('P S')], [qw('Player Score')]);
  $log->ColumnAttributes(['id=1','id=s1']);
  $log->WriteRow(['jjc', 123], ['John Chew (#1)', 123]);
  my ($text, $html) = $log->Close();

  # or instead of Close(), we can call RenderHTML() or RenderText(),
  # see ShowDivisionScoreCards

=head1 ABSTRACT

This class manages the copying of information displayed on the
console to text and HTML files.

=cut

=head1 DESCRIPTION

=head2 FORMAT

A log, in the current version of an increasingly ornate structure, consists
of some or all of the following sequence of sections, which is typically
rendered as text (with automatically sized columns) or HTML.

=over 4

=item header

(HTML only) 
everything beginning with the DOCTYPE and/or HTML open tag
and including the BODY open tag.  A TITLE tag will mark the log's title.

=item top

(HTML only) the optional contents of C<config html_top>.

=item title

The title is based by default on the log type (ratings, scorecard, etc.),
division name (if any) and round number (if any), and can be overridden
by an option.

=item table heading rows

Headings for each of the columns in the table.

=item table data rows

The main content of the log, in table form.

=item footer

(HTML only) the rest of the file, from the tsh blurb down to the HTML close tag.

=back

=head2 METHODS

=over 4

=cut

sub initialise ($$$$;$$);
sub Close($);
sub ColumnAttributes($;$);
sub ColumnClasses($;$$);
sub ColumnTitles($$);
sub EndPage ($$);
sub ExpandEntities ($);
sub Flush ($);
sub GetBlurb ($);
sub new ($$$$;$$);
sub MakeHTMLIndex ($);
sub PageBreak ($);
sub RenderFooterHTML ($$);
sub RenderFooterText ($);
sub RenderHeaderHTML ($$$$);
sub RenderHeaderText ($$$$);
sub RenderHTML ($);
sub RenderOpenTable ($$;$);
sub RenderRowsHTML ($);
sub RenderRowsText ($);
sub RenderText ($);
sub Write ($$$);
sub WriteRow ($$;$);

=item $log->Close()

Close a log and all files associated with it.

=cut

sub Close ($) {
  my $this = shift;
  my $config = $this->{'tournament'}->Config();
  $this->EndPage('last');

  for my $fh (qw(text_fh subhtml_fh)) {
    if ($this->{$fh}) {
      close($this->{$fh});
      $this->{$fh} = undef;
      }
    }
  unless ($this->{'options'}{'nohtml'}) {
    my $target_fn = $config->MakeHTMLPath($this->{'filename'});
    rename "$target_fn.new", $target_fn
      or warn "Can't update $target_fn: $!\n";
    $this->MakeHTMLIndex();
    $this->{'tournament'}->LastReport($this->{'filename'})
      unless $config->Value('nohistory');
    for my $mirror_fn (@{$this->{'mirror_filenames'}}) {
      copy($target_fn, $mirror_fn)
        or warn "Can't update mirror $mirror_fn: $!\n";
      }
    }
  }

=item $p->ColumnAttributes(\@attributes);

Set or get the list of column attributes.

=cut

sub ColumnAttributes ($;$) { TSH::Utility::GetOrSet('column_attributes', @_); }

=item $p->ColumnClasses(\@classes[, row_class]);

Set or get the list of column classes.

=cut

sub ColumnClasses ($;$$) { 
  my $this = shift;
  my $new = shift;
  if (defined $new) {
    $this->{'column_classes'} = $new;
    $new = shift;
    if (defined $new) {
      $this->{'row_class'} = $new;
      }
    else {
      $this->{'row_class'} = undef;
      }
    }
  else {
    return $this->{'column_classes'};
    }
  }

=item $p->ColumnTitles({'text'=>\@text,'html'=>\@html});

Set the list of column titles.

=cut

sub ColumnTitles ($$) { 
  my $this = shift;
  my $hashp = shift;
  $this->WriteTitle($hashp->{'text'}, $hashp->{'html'});
  }

=item $log->EndPage($islast);

Emit a footer and end the current page.  Deprecated in favour of PageBreak(),
no longer in use by production code, retained in case some offline code uses it.

Deprecated because its use of unbuffered Write() calls does not interoperate
with the current paradigm of creating a Log object and then subsequently
rendering it in different ways.

=cut

sub EndPage ($$) {
  my $this = shift;
  my $islast = shift;
  $this->Flush();
  $this->Write('', "</table>\n");
  my $text = $this->RenderFooterText();
  my $html = $this->RenderFooterHTML({'nowrapper'=>!$islast});
  $this->Write($text, $html);
  }

sub ExpandEntities ($) {
  $_[0] = '' unless defined $_[0];
  $_[0] =~ s/&([aAoOuU])uml;/$1e/;
  }

=item $fn = $log->Filename();

Return the output filename (not including its directory)
associated with this log.

=cut

sub Filename ($) { my $this = shift @_; return $this->{'filename'}; }

=item $action_taken = $log->Flush();

If WriteRow() has been called since the last call to Flush(),
then emit all text and HTML data that has been saved up using
WriteTitle() (or ColumnTitles()) and WriteRow().
Returns boolean indicating whether flushing took place.

=cut

sub Flush ($) {
  my $this = shift;
  return 0 unless @{$this->{'data_text'}} || @{$this->{'data_html'}};
  my $fh;
  my $s = $this->RenderRowsText();
  if ($this->{'options'}{'noconsole'}) {
#   warn "no console for $this->{'base_filename'}";
    }
  else {
    PrintConsoleCrossPlatform $s;
    }
  if ($fh = $this->{'text_fh'}) {
    print $fh $s;
    }
  if ($fh = $this->{'subhtml_fh'}) {
    $s = $this->RenderRowsHTML();
    print $fh $s;
    }
  $this->{'data_text'} = [];
  $this->{'data_html'} = [];
  return 1;
  }

=item $html = $log->GetBlurb([\%options]);

Return the tsh blurb that appears in the footer.

=cut

sub GetBlurb ($) {
  my $this = shift;
  my $optionsp = shift || {};

  my $config = $this->{'tournament'}->Config();
  my $bottom;
  if ($optionsp->{'isindex'}) {
    $bottom = $config->Value('html_index_bottom');
    $bottom = $config->Value('html_bottom') unless defined $bottom;
    }
  else {
    $bottom = $config->Value('html_bottom');
    }
  $bottom = '' unless defined $bottom;
  $bottom .= $this->RenderPhizBox() if $this->{'phiz'};
  return "$bottom<p class=notice>" . $config->Terminology('blurb', $main::gkVersion) . "</p>";
  }

=item $log->initialise($tournament, $division, $filename, $round, \%options)

Initialise the log object, create files.
Options (and defaults): 

body_class (report type stripped of any -\d+ and with remaining - changed to _): CSS class used for report <body>

custom_body_class (none): additional CSS class used for report <body>

custom_header (none): additional header(s) to include in the report <head>

custom_stylesheet (none): custom stylesheet, if any, to use in addition to config custom_stylesheet and tsh.css

htmltitle (title): version of title to use only in HTML format

html_page_break_top (config html_page_break_top): content to emit immediately after an HTML page break

isindex (0): if true, use header/footer information for index pages

javascript (none): custom javascript files to include in page header

noconsole (config no_console_output): do not write to console

nohtml (0): do not generate HTML files

notext (config no_text_files): do not generate text file 

notitle (0): do not display title except in HTML <title>

notop (0): do not emit config html_top

nowrapper (0): do not emit (HTML) header or footer

refresh (none): if true, include <meta http-equiv=refresh> line with this content value

title (Division ? Round ? titlename): human-readable title

titlename (ucfirst $filename): base word to use in human-readable title

texttitle (title): version of title to use only in text format

=cut

sub initialise ($$$$;$$) {
  my $this = shift;
  my $tournament = shift;
  my $dp = shift;
  my $filename = lc shift;
  my $round = lc (shift||'');
  my $optionsp = $this->{'options'} = (shift||&share({}));

  my $config = $tournament->Config();
  my $round_term = $config->Terminology('Round');
  my $html_suffix = $config->Value('html_suffix');
  my %phiz;
  if ($config->{'phiz_event_id'} && $round) {
    $this->{'phiz'} = $config->{'phiz_event_id'};
    $optionsp->{'custom_stylesheet'} = 'phiz.css';
    $optionsp->{'javascript'} ||= &share([]);
    $optionsp->{'javascript'} = [$optionsp->{'javascript'}] 
      unless ref($optionsp->{'javascript'}) eq 'ARRAY';
    push(@{$optionsp->{'javascript'}}, 'phiz.js', 'jquery-1.5.2-min.js', 'phizlaunch.js');
    }

  $optionsp->{'noconsole'} ||= $config->Value('no_console_output');

  $this->{'base_filename'} = $filename;
  $this->{'column_attributes'} = [];
  $this->{'column_classes'} = [];
  $this->{'data_html'} = []; # list alternates between {metadata} and [rows]
  $this->{'data_text'} = []; # list alternates between {metadata} and [rows]
  $this->{'dp'} = $dp;
  $this->{'filename'} = undef;
  $this->{'mirror_filenames'} = [];
  $this->{'round'} = $round;
  $this->{'row_class'} = undef;
  $this->{'title_html'} = [];
  $this->{'title_text'} = [];
  $this->{'tournament'} = $tournament;

  my ($fh, $fn, %fhs);
  my $round_000 = 
    $round =~ /^\d+$/ ? sprintf("-%03d", $round) 
    : $round =~ /^(\d+)-(\d+)$/ ? sprintf("-%03d-%03d", $1, $2) 
    : '';

  my $dname = '';
  my $dname_hyphen = '';
  if ($dp) {
    $dname = $dp->Name();
    $dname_hyphen = "$dname-";
    }
  unless ($optionsp->{'notext'} || $config->Value('no_text_files')) {
    $fn = $config->MakeRootPath("$dname_hyphen$filename.doc");
    $fh = OpenFile('>:encoding(utf8)', $fn);
    if ($fh) {
      $this->{'text_fh'} = $fh;
      }
    else {
      Error "Can't create $fn: $!\n"; 
      }
    }

  unless ($optionsp->{'nohtml'}) {
    $this->{'filename'} = "$dname_hyphen$filename$round_000$html_suffix";
    if ($config->Value('html_in_event_directory')) {
      push(@{$this->{'mirror_filenames'}}, 
        $config->MakeRootPath("$dname_hyphen$filename$html_suffix"));
      }
    for my $mirrordir (@{$config->Value('mirror_directories')}) {
      push(@{$this->{'mirror_filenames'}}, 
	File::Spec->catfile($mirrordir, 'html', $this->{'filename'}));
      mkpath(File::Spec->catfile($mirrordir, 'html'));
      }
    $fn = $config->MakeHTMLPath($this->{'filename'}.'.new');
    $fh = OpenFile('>:encoding(utf8)', $fn);
    if ($fh) {
      $this->{'subhtml_fh'} = $fh;
      }
    else {
      Error "Can't create $fn: $!\n";
      }
    }

  my $title = $optionsp->{'title'};
  unless (defined $title) {
    $title = ucfirst($optionsp->{'titlename'} || $filename);
    my $i18n;
    eval { $i18n = $config->Terminology(lc $title); };
    $title = $i18n || $title;
    $title = $config->Terminology('Round_Title', $round, $title) if $round =~ /^\d+$/;
    if ($tournament->CountDivisions() > 1 
      || $config->Value('show_divname') 
      || defined $config->Value('html_parent_directory')) { 
      $title = $dp ? $dp->Label() . " $title": $title;
      };
    }
  $this->{'title'} = $title;
  my $html = $this->RenderHeaderHTML($title, $filename, $optionsp);
  my $text = $this->RenderHeaderText($title, $filename, $optionsp);
  $this->Write($text, $html);

  my $filename_ = $filename; $filename_ =~ s/-/_/g;
  $this->Write('', $this->RenderOpenTable(''));

  return $this;
  }

=item $fmt = $log->MakeFormat($length, $class);

Return a sprintf format suitable for data of maximum length $length
and class $class.

=cut

my (%gClassAlignment) = (
  'board left' => 'r',
  'board' => 'r',
  'onum' => 'r',
  'orat' => 'r',
  'player' => 'l',
  'rank' => 'r',
  'rating difr' => 'r',
  'rating newr' => 'r',
  'rating oldr' => 'r',
  'rating' => 'r',
  'round' => 'r',
  'seat' => 'r',
  'score' => 'r',
  'sopew' => 'r',
  'spread' => 'r',
  'stat' => 'r',
  'sum' => 'r',
  'table left' => 'r',
  'table' => 'r',
  'thai' => 'r',
  'wins' => 'r',
  );

sub MakeFormat ($$) {
  my $length = shift;
  my $class = shift;

  (($gClassAlignment{$class||''}||'') eq 'r') 
    ? "%${length}s"
    : "%-${length}s";
  }

=item $log->MakeHTMLIndex();

Used internally to update the HTML index of HTML files.

=cut

sub MakeHTMLIndex ($) {
  my $this = shift;
  my $tournament = $this->{'tournament'};
  my $config = $tournament->Config();
  my $html_suffix = $config->Value('html_suffix');
  
  my $scanp = $this->ScanHTMLFiles();

  my $fh;
  my $fn = $config->MakeHTMLPath("index$html_suffix");
  unless (open $fh, ">:encoding(utf8)", $fn) {
    Error "Can't create HTML index file: $!\n";
    return;
    }
  print $fh $this->RenderHeaderHTML(
    $config->Terminology('event_coverage_index'), 'index', {'isindex' => 1});
  $this->OutputIndexBody($fh, $scanp);
  print $fh "<p class=notice>\n" .
    $config->Terminology('links_above') . "</p>\n";
  print $fh $this->RenderFooterHTML({'isindex' => 1});
  close $fh;

  for my $mirrordir (@{$config->Value('mirror_directories')}) {
    copy($fn, File::Spec->catfile($mirrordir, 'html', "index$html_suffix"))
      or warn "Can't mirror index file to $mirrordir: $!";
    }

  if (defined $config->Value('html_parent_directory')) {
    $this->MakeHTMLParentIndex($scanp);
    }
  }

=item $log->MakeHTMLParentIndex($scanp);

Update a parent (master) directory index with all the entries in this
directory.  C<$scanp> should be a data structure the type returned
from C<ScanHTMLFiles()> indicating what report files are in the 
current (child) directory.

=cut

sub MakeHTMLParentIndex ($$) {
  my $this = shift;
  my $scanp = shift;

  my $tournament = $this->{'tournament'};
  my $config = $tournament->Config();

  my $html_suffix = $config->Value('html_suffix');

  # open and import data from, or create, master index file handle
  my $fh;
  my $master_scanp;
  my $fn = File::Spec->catfile(
    $config->Value('html_parent_directory'), "index$html_suffix");
  if (open $fh, "+<:encoding(utf8)", $fn) {
    # lock file
    unless (flock($fh, LOCK_EX | LOCK_NB)) {
      warn "$fn is locked and cannot be updated. Try again later.\n";
      return;
      }
    # scan file
    $master_scanp = $this->ScanIndexFile($fh);
    }
  elsif (open $fh, ">:encoding(utf8)", $fn) {
    # lock file
    unless (flock($fh, LOCK_EX | LOCK_NB)) {
      warn "$fn is locked and cannot be updated. Try again later.\n";
      return;
      }
    $master_scanp = {
      'divisions' => {},
      'rounds' => [],
      'rtypes' => {},
      'top' => {},
      };
    }
  else {
    Error "Cannot create HTML parent index file '$fn': $!\n";
    return;
    }

  # merge our own scanp into master data
  my $prefix = $config->Value('html_child_prefix')
    or warn "Using a parent index without specifying config html_child_prefix is a bad idea.\n";
# use Data::Dumper; print Dumper($master_scanp);
  $this->MergeScans($master_scanp, $scanp, $prefix);
# use Data::Dumper; print Dumper($master_scanp), Dumper($scanp);

  # rewind, truncate, and update
  seek $fh, 0, 0 or die "Rewind failed for '$fn': $!";
  truncate $fh, 0 or die "Truncate failed for '$fn': $!";
  print $fh $this->RenderHeaderHTML(
    $config->Terminology('event_coverage_index'), 'parent-index',
      {
        'isindex' => 1,
         htmltitle => $config->Value('html_parent_title') 
           // 'config html_parent_title not specified',
      });
  $this->OutputIndexBody($fh, $master_scanp);

  print $fh $this->RenderFooterHTML({'isindex' => 1});

  flock($fh, LOCK_UN);
  close $fh;
  }

=item $fmtsp = $log->MeasureColumns();

Used internally to measure text column widths.

=cut

sub MeasureColumns ($) {
  my $this = shift;
  my @lengths;
  for my $section_key (qw(title_text data_text)) {
    my $rows = $this->{$section_key};
    next unless @$rows;
    for (my $rowi = 1; $rowi <= $#$rows; $rowi += 2) { # no metadata this pass
      my $row = $rows->[$rowi];
      for my $i (0..$#$row) {
	my $cell = $row->[$i];
	next unless defined $cell;
	my $width = length($cell);
	if (defined $lengths[$i]) {
	  $lengths[$i] = $width if $lengths[$i] < $width;
	  }
	else {
	  $lengths[$i] = $width;
	  }
	}
      }
    }

  return \@lengths;
  }

=item $log->MergeScans($dest, $src, $url_prefix);

Used internally to merged scanned directory data for indices.

=cut

sub MergeScans ($$$) {
  my $this = shift;
  my $dest = shift;
  my $src = shift;
  my $prefix = shift;

  for my $div (keys %{$src->{divisions}}) { 
    $dest->{divisions}{$div}++; 
    }
  while (my ($type, $typedp) = each %{$src->{rtypes}}) {
    for my $r0 (0 .. $#$typedp) {
      my $divsp = $typedp->[$r0];
      while (my ($div, $divdp) = each %$divsp) {
        while (my ($fulltype, $fn) = each %$divdp) {
	  $dest->{rtypes}{$type}[$r0]{$div}{$fulltype} = 
	    File::Spec->catfile($prefix, $fn);
	  }
        }
      }
    }
  for my $r0 (0 .. $#{$src->{rounds}}) {
    my $divsp = $src->{rounds}[$r0];
    while (my ($div, $divdp) = each %$divsp) {
      while (my ($type, $fn) = each %$divdp) {
	$dest->{rounds}[$r0]{$div}{$type} = 
	  File::Spec->catfile($prefix, $fn);
	}
      }
    }
  # TODO: if top data is present, provide a link to the child index.
  # TODO: if ~all divs data is present, provide a link to the child data.
  # TODO: consider doing so regardless
  # for now, just delete the ~all divs data
  delete $dest->{divisions}{'~all'}
  }

=item $d = new Log;

Create a new Log object.  

=cut

sub new ($$$$;$$) { return TSH::Utility::new(@_); }

=item $log->OutputIndexDivisionHeads($fh, @division_names);

Output the division headings for an HTML index.
Used internally.

=cut

sub OutputIndexDivisionHeads ($$@) {
  my $this = shift;
  my $fh = shift;
  my (@divisions) = @_;

  print $fh "<tr class=divheads><th class=empty>&nbsp;</th>";
  for my $div (@divisions) {
    my $title;
    if ($div eq '~all') { 
      $title = 'All Divs.';
      }
    elsif (my $dp =$this->{'tournament'}->GetDivisionByName($div)) {
      $title = $dp->Label();
      $title =~ s/Division/Div./;
      }
    elsif (my $aTitle = $this->{divtitles}{uc $div}) {
      $title = $aTitle;
      }
    else {
      $title = "Div. \U$div";
      }
    print $fh qq(<th class=division data-div="\U$div">$title</th>\n);
    }
  print $fh "</tr>\n";
  }

sub OutputIndexHeadsCompact1($$@) {
  my $this = shift;
  my $fh = shift;
  my (@rtypes) = @_;
  my $config = $this->{'tournament'}->Config();

  print $fh "<tr class=rtypes>";
  my $nrtypes = scalar(@rtypes);
  for my $i (0..$#rtypes) {
    my $rtype = $rtypes[$i];
    my $i18n = $rtype;
    eval { $i18n = $config->Terminology($rtype); };
    $i18n ||= $rtype;
    print $fh qq(<th class="rtype eqw$nrtypes )
      .($i==$#rtypes?' lastc':'').qq(">$i18n</th>\n);
    }
  print $fh "</tr>\n";
  }

=item $log->OutputIndexRoundRow($fh, \@divisions, $round_name, \@round_data, \%misc);

Output one round's division data for an HTML index.
Used internally.

=cut

sub OutputIndexRoundRow ($$$$$) {
  my $this = shift;
  my $fh = shift;
  my $divsp = shift;
  my $round_name = shift;
  my $rp = shift;
  my $optionsp = shift;
  my $tournament = $this->{'tournament'};
  my $config = $tournament->Config();
  my $colspan = $optionsp->{'colspan'};
  $colspan = " colspan=$colspan" if $colspan;

  print $fh $round_name eq '&nbsp;' ? '<tr class=round0>' : '<tr class=round>';
  unless ($optionsp->{'noround'}) {
    print $fh "<td class=round>$round_name</td>\n";
    }
  for my $div (@$divsp) {
    print $fh "<td class=links$colspan>";
    my $rdp = $rp->{$div};
    if ($rdp) {
      for my $type (sort keys %$rdp) {
	my $i18n = $type;
	eval { $i18n = $config->Terminology($type); };
# $i18n = $config->Terminology($type); print STDERR "TYPE: $type I18N: $i18n\n";
	print $fh qq(<div class="link $type"><a href="$rdp->{$type}" data-div="$div">$i18n</a></div>\n);
	}
      }
    print $fh "</td>";
    }
  print $fh "</tr>\n";
  }

=item $log->OutputIndexRoundRowCompact1($fh, $round, $round_name, \@rtypes, \%rtypes);

Output one round's division data for an HTML index.
This version is used if C<config html_index_stye = 'compact'>
and there is only one division in the tournament.
Used internally.

=cut

sub OutputIndexRoundRowCompact1 ($$$$$$) {
  my $this = shift;
  my $fh = shift;
  my $round = shift;
  my $round_name = shift;
  my $rtypesp = shift;
  my $rtypeshp = shift;
  my $tournament = $this->{'tournament'};
  my $config = $tournament->Config();
  my $divname = lc (($tournament->Divisions())[0]->Name());

  print $fh $round_name eq '&nbsp;' ? '<tr class="round0 compact">' 
    : qq(<tr class="round compact ).($round%2?'odd':'even').qq(">);
  for my $i (0..$#$rtypesp) {
    my $rtype = $rtypesp->[$i];
    print $fh qq(<td class="round).($i==$#$rtypesp?' lastc':'').qq(">\n);
    my $p = $rtypeshp->{$rtype}[$round]{$divname};
    my $seen = 0;
    for my $fulltype (sort keys %$p) {
      my $file = $p->{$fulltype};
      my $short_type = $fulltype; 
      $short_type =~ s/.* //;
      $short_type =~ s/\b0+//g;
      my $title = $fulltype eq $rtype ? $round_name : $short_type;
      print $fh qq(<div class="link $rtype"><a href="$file">$title</a></div>\n);
      $seen++;
      }
    print $fh qq(<div class="link $rtype">&nbsp;</div>)
      unless $seen;
    print $fh qq(</td>\n);
    }
  print $fh "</tr>\n";
  }

=item $log->OutputIndexTop($fh, $ncols, \%topdata);

Output the top links for an HTML index (the links that are not
specific to a division).  Used internally.

=cut

sub OutputIndexTop ($$$$) {
  my $this = shift;
  my $fh = shift;
  my $ncols = shift;
  my $topp = shift;
  my $tournament = $this->{'tournament'};
  my $config = $tournament->Config();

  printf $fh "<tr class=top><td class=links colspan=$ncols align=center>";
  for my $type (sort keys %$topp) {
    my $i18n = $type;
    eval { 
      my ($base, $round) = split(/-/, $type, 2);
      $i18n = $config->Terminology($base); 
      $i18n = $config->Terminology('Round_Title', $round, $i18n) if $round;
      };
    print $fh qq(<div class="link $type"><a href="$topp->{$type}">$i18n</a></div>\n);
    }
  print $fh "</td></tr>";
  }

=item $log->PageBreak();

Emit a page footer and break in the HTML version of the report.

=cut

sub PageBreak ($) {
  my $this = shift;

  push(@{$this->{'data_html'}}, 'page-break', undef); return; # 2014-05-22

# $this->EndPage(0);
# $this->Write('', $this->RenderOpenTable('style=page-break-before:always',
#   'noscreenhead'));
  }

=item $html= $log->RenderFooterHTML(\%options);

Render a standard report trailer in HTML.

=cut

sub RenderFooterHTML ($$) {
  my $this = shift;
  my $optionsp = shift;
  return $optionsp->{'nowrapper'} ? '' 
    : ($this->GetBlurb($optionsp) . "</body></html>");
  }

=item $html= $log->RenderFooterText();

Render a standard report trailer in text.

=cut

sub RenderFooterText ($) {
  my $this = shift;
  return '';
  }

=item $html = $log->RenderHTML();

Render entire log (header, table and footer) as HTML and reset table data.

=cut

sub RenderHTML ($) {
  my $this = shift;
  my $html = '';
  $html .= $this->RenderHeaderHTML($this->{'title'},
    $this->{'base_filename'}, $this->{'options'});
  $html .= $this->RenderRowsHTML();
  $html .= $this->RenderFooterHTML($this->{'options'});
  return $html;
  }

=item $html = $log->RenderHeaderHTML($title, $type, \%options);

C<$options{'isindex'}> uses C<$config::html_index_top> 
in preference to C<$config::html_top>.

See initialise() for other options.

=cut

sub RenderHeaderHTML ($$$$) {
  my $this = shift;
  my $title = shift;
  my $type = shift;
  my $optionsp = shift;
  my $tournament = $this->{'tournament'};
# use Carp qw(cluck); cluck "*** $title;$type;$optionsp;$optionsp->{'nowrapper'}";
  my $config = $tournament->Config();
  my $html_suffix = $config->Value('html_suffix');
  my $report_title_tag = $config->Value('report_title_tag') || 'h1';
  my $realm = $config->Value('realm');
  $realm = $realm ? " $realm" : '';
  my $div_class = ($optionsp->{'isindex'}||!$this->{'dp'}) ? '' : (' div_' . $this->{'dp'}->Name());
  my $custom_body_class = $config->Value('custom_body_class');
  $custom_body_class = $custom_body_class ? " $custom_body_class" : '';
  my $compact = ($tournament->CountDivisions() == 1 && ($config->Value('html_index_style')||'traditional')) eq 'compact' ? ' compact' : '';
  my $html = '';
  my $type_; 
  if ($optionsp->{'body_class'}) { $type_ = $optionsp->{'body_class'} }
  else {
    $type_ = $type;
    $type_ =~ s/-\d+//g;
    $type_ =~ s/-/_/;
   }

  my $custom_header = $optionsp->{'custom_header'} ? $optionsp->{'custom_header'} ."\n" : ''; 
  my $custom_stylesheet = '';
  $custom_stylesheet .= join("\n", map {
    qq(<link rel="stylesheet" href="$_" type="text/css">)
    } ConcatenateCarefully($config->Value('custom_stylesheet'), $optionsp->{'custom_stylesheet'})) unless $type eq 'enhanced-scoreboard' and $config->Value('no_scoreboard_custom_stylesheet');
  my $javascript = join("\n", map {
    qq(<script type="text/javascript" src="$_"></script>)
    } ConcatenateCarefully($optionsp->{'javascript'}));

  my $backref = ($optionsp->{'isindex'} || $optionsp->{'refresh'}) ? '' 
    : "<p class=backref>" . $config->Terminology('Back_to_round_index', "index$html_suffix") 
      . ".</p>\n";
   
# use Carp; confess unless defined $title;
  my $refresh = $optionsp->{'refresh'} ?
#   qq(<meta http-equiv=refresh content="$optionsp->{'refresh'}; url=$this->{'filename'}">\n) : '';
    qq(<meta http-equiv=refresh content="$optionsp->{'refresh'}">\n) : '';
  my $doctype = $config->Value('html_doctype') || <<"EOF";
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.0 Transitional//EN"
	"http://www.w3.org/TR/1998/REC-html40-19980424/loose.dtd">
EOF
  $html .= $optionsp->{'nowrapper'} ? '' : <<"EOF";
$doctype
<html><head><title>$title</title>
<meta http-equiv="Content-Type" content="text/html; charset=utf-8">
$custom_header$javascript
$refresh<link rel="stylesheet" href="tsh.css" type="text/css">
$custom_stylesheet
</head>
<body class="${type_}$realm$div_class$compact$custom_body_class">
$backref
EOF
  my $extra_top = $optionsp->{'notop'} ? '' : 
    $optionsp->{'isindex'} 
      ? ($config->Value('html_index_top')||$config->Value('html_top'))
      : $config->Value('html_top');
  $html .= $extra_top if $extra_top;
  my $htmltitle = $optionsp->{'htmltitle'};
  if (!defined $htmltitle) {
    $htmltitle = $title; $htmltitle =~ s/(\d)-(\d)/$1&ndash;$2/g;
    }
  if (length($htmltitle)) { $htmltitle = "<$report_title_tag>$htmltitle</$report_title_tag>\n"; }
  return $optionsp->{'notitle'} ? $html : "$html$htmltitle";
  }

=item $html = $log->RenderHeaderText($title, $type, \%options);

See initialise() for options.

=cut

sub RenderHeaderText ($$$$) {
  my $this = shift;
  my $title = shift;
  my $type = shift;
  my $optionsp = shift;
  my $config = $this->{'tournament'}->Config();
  my $type_ = $type; $type =~ s/-/_/;
  return $optionsp->{'notitle'} ? '' :
    ((defined $optionsp->{'texttitle'}) 
      ? $optionsp->{'texttitle'} : "$title\n\n");
  }

=item $html = $log->OutputIndexBody($fh, $scanp);

Render and output the body of an index based on content data scanned from
the file names in a report html_directory.

=cut

sub OutputIndexBody ($$) {
  my $this = shift;
  my $fh = shift;
  my $scanp = shift;

  my $tournament = $this->{'tournament'};
  my $config = $tournament->Config();
  my $max_rounds = $config->Value('max_rounds');
  my $recent_first = $config->Value('html_index_recent_first');
  my $round_term = $config->Terminology('Round');
  my $index_style = $config->Value('html_index_style') || 'traditional';
  my $compact = $index_style eq 'compact';
  my $ndivisions = $tournament->CountDivisions();
  my $compact1 = $compact && $ndivisions == 1;

  my (%divisions) = %{$scanp->{'divisions'}} if $scanp->{'divisions'};
  my (@divisions) = sort keys %divisions;
  my (@rounds) = @{$scanp->{'rounds'}} if $scanp->{'rounds'};
# $#rounds = $max_rounds if $max_rounds; # 2023-10-12
  my (%rtypes) = %{$scanp->{'rtypes'}} if $scanp->{'rtypes'};
  my (@rtypes) = sort keys %rtypes;
  my $nrtypes = scalar(@rtypes);
  my (%top) = %{$scanp->{'top'}} if $scanp->{'top'};

  if (%top || %divisions) {
    print $fh "<table class=index align=center>\n";
    my $ncols = $compact1 ? $nrtypes : (scalar(@divisions) + 1);
    $this->OutputIndexTop($fh, $ncols, \%top) if %top;
    if ($ndivisions != 1 or defined $config->Value('html_parent_directory')) {
      $this->OutputIndexDivisionHeads($fh, @divisions);
      }
    my (@round_numbers) = $recent_first 
      ? (0, reverse(1..$#rounds)) : (0..$#rounds);
    for my $round (@round_numbers) {
      my $rp = $rounds[$round];
      next unless $round==0 || $rp || ($max_rounds && !$recent_first);
      my $round_name = $round ? "$round_term $round" : '&nbsp;';
      if ($round && $compact1) {
	$this->OutputIndexRoundRowCompact1($fh, $round, $round_name,
           \@rtypes, \%rtypes, $rp);
	}
      else {
	$this->OutputIndexRoundRow($fh, \@divisions, $round_name, $rp, { 'colspan' => $compact1 ? $nrtypes : 1, 'noround' => $compact1 ? 1 : 0 });
	if ($compact1) {
	  $this->OutputIndexHeadsCompact1($fh, @rtypes);
	  }
        }
      }
    print $fh "</table>\n";
    }
  else {
    print $fh "<p class=notice>No reports have been generated yet.</p><p>&nbsp;</p>\n";
    }
  }

=item $html = $log->RenderOpenTable($attrs);

Render an open-table tag for our log.

=cut

sub RenderOpenTable ($$;$) {
  my $this = shift;
  my $attrs = shift;
  my $extra_class = shift;
  $extra_class = $extra_class ? " $extra_class" : '';
  $attrs = " $attrs" if $attrs;
  my $filename_ = $this->{'base_filename'};
  $filename_ =~ s/-\d+//g;
  $filename_ =~ s/-/_/g;
  return qq(<table class="$filename_$extra_class" align=center cellspacing=0$attrs>\n);
  }

sub RenderPhizBox ($) {
  my $this = shift;
  unless ($this->{'round'}) {
    return '';
    }
  my $id = "E$this->{'phiz'}_";
  if ($this->{'tournament'}->CountDivisions() > 1) {
    $id .= 'D' . $this->{'dp'}->Name() . '_';
    }
  $id .= "R$this->{'round'}";
  return qq(<div class=phiz id="$id"></div>\n);
  }

=item $html = $log->RenderPageBreakTopHTML();

Render any content specified to appear at the top of a page after a page break

=cut

sub RenderPageBreakTopHTML ($) {
  my $this = shift;
  
  my $html = $this->{'options'}{'html_page_break_top'};
  if (!defined $html) {
    my $tournament = $this->{'tournament'};
    my $config = $tournament->Config();
    $html = $config->Value('html_page_break_top');
    }
  return '' unless defined $html;
  return qq(<div class="page-break-top" style="page-break-before:always">$html</div>);
  }

=item $html = $log->RenderRowsHTML();

Render stored HTML table cells and clear them.

=cut

sub RenderRowsHTML ($) {
  my $this = shift;
  my $html = '';
  $html .= $this->RenderSectionHTML('title_html', 'th');
  $html .= $this->RenderSectionHTML('data_html', 'td');
  $this->{'title_html'} = [];
  $this->{'data_html'} = [];
  return $html;
  }

=item $text = $log->RenderRowsText();

Render stored text table cells and clear them.

=cut

sub RenderRowsText ($) {
  my $this = shift;
  my $text = '';
  my $lengthsp = $this->MeasureColumns();
  $text .= $this->RenderSectionText('title_text', $lengthsp);
  $text .= $this->RenderSectionText('data_text', $lengthsp);
  $this->{'title_text'} = [];
  $this->{'data_text'} = [];
  return $text;
  }

=item $html = $log->RenderSectionHTML($key, $tag);

Used internally to render either a group of header or data rows into HTML.

=cut

sub RenderSectionHTML ($$$) {
  my $this = shift;
  my $key = shift;
  my $tag = shift;
  my $html = '';
  my $rows = $this->{$key};
  return '' unless @$rows;

  for (my $rowi = 0; $rowi <= $#$rows; $rowi += 2) {
    my $metadata = $rows->[$rowi];
    if ($metadata eq 'page-break' and $key eq 'data_html') {
      $html .= "</table>\n";
      $html .= $this->RenderFooterHTML({'nowrapper'=>1});
      my $top = $this->RenderPageBreakTopHTML();
      $html .= $top;
      $html .= $this->RenderOpenTable(length($top) ? '' : 'style=page-break-before:always',
	'noscreenhead');
      # 20170724 tried deleting the following line to reduce duplicate headings 
      # but it results in no headings on subsequent pages in CSCs.
      # Leaving it in gives double headings on alpha pairings
      $html .= $this->RenderSectionHTML('title_html', 'th'); 
      next;
      }
    if (ref($metadata) eq 'ARRAY') { die "Assertion failed (likely old code): @$metadata"; }
    my $attributes = $metadata->{'attributes'};
    my $classes = $metadata->{'classes'};
    my $row_class = $metadata->{'row_class'};
    my $row_cell_tag = $metadata->{'tag'} || $tag;
    if ($row_cell_tag eq 'th' && !defined $row_class) {
      $row_class = 'top' . (($rowi/2)+1);
      }
    my $row = $rows->[$rowi+1];
    $html .= (defined $row_class) ? qq(<tr class="$row_class">) : '<tr>';
    for my $i (0..$#$row) {
      my $attribute = $attributes->[$i];
      $attribute = '' unless defined $attribute;
      my $class = $classes->[$i];
      my $cell = $row->[$i];
      $cell = '&nbsp;' unless (defined $cell) && length($cell); # required for Windows browsers
      $html .= qq(<$row_cell_tag);
      $html .= qq( class="$class") if defined $class;
      $html .= qq( $attribute) if length($attribute);
      $html .= qq(>$cell</$row_cell_tag>);
      }
    $html .= "</tr>\n";
    }

  return $html;
  }

=item $html = $log->RenderSectionText($key, $lengths);

Used internally to render either a group of header or data rows into text.

=cut

sub RenderSectionText ($$$) {
  my $this = shift;
  my $key = shift;
  my $lengthsp = shift;
  my $text = '';
  my $rows = $this->{$key};
  return '' unless @$rows;

  for (my $rowi = 0; $rowi <= $#$rows; $rowi += 2) {
    my $classes = $rows->[$rowi];
    my $row = $rows->[$rowi+1];
    for my $i (0..$#$row) {
#     if (ref($classes) eq 'HASH') { die "$key:".join(',', %$classes); }
      my $value = $row->[$i];
      $value = '' unless defined $value;
      $text .= sprintf(MakeFormat($lengthsp->[$i], $classes->[$i]), $value);
      $text .= ' ' unless $i == $#$row;
      }
    $text =~ s/\s+$//;
    $text .= "\n";
    }

  return $text;
  }

=item $html = $log->RenderText();

Render entire log (header, table and footer) as text and reset table data.

=cut

sub RenderText ($) {
  my $this = shift;
  my $html = '';
  $html .= $this->RenderHeaderText($this->{'title'},
    $this->{'base_filename'}, $this->{'options'});
  $html .= $this->RenderRowsText();
  $html .= $this->RenderFooterText();
  return $html;
  }

sub RowClass ($;$) {
  my $this = shift;
  my $row_class = shift;
  my $old = $this->{'row_class'};
  $this->{'row_class'} = $row_class if defined $row_class;
  return $old;
  }

sub RowClassAdd ($;$) {
  my $this = shift;
  my $new_class = shift;
  my (%classes) = map { $_ => 1 } split(/\s+/, $this->{'row_class'}||'');
  $classes{$new_class}++;
  $this->{'row_class'} = join(' ', sort keys %classes);
  }

sub RowClassRemove ($;$) {
  my $this = shift;
  my $old_class = shift;
  my (%classes) = map { $_ => 1 } split(/\s+/, $this->{'row_class'}||'');
  delete $classes{$old_class};
  $this->{'row_class'} = join(' ', sort keys %classes);
  }

=item $hashp = $logp->ScanHTMLFiles();

Scan the HTML report directory to see what files need to be indexed.
Return a reference to a hash with keys 
C(<div>),
C(<rounds>),
C(<top>),
for use by C<MakeHTMLIndex>).

=cut

sub ScanHTMLFiles ($) {
  my $this = shift;
  my $tournament = $this->{'tournament'};
  my $config = $tournament->Config();
  my $no_index_tally_slips = $config->Value('no_index_tally_slips');
  my $html_suffix = $config->Value('html_suffix');

  my $dir;
  unless (opendir($dir, $config->MakeHTMLPath(''))) {
    $tournament->TellUser('elogod', $!);
    return undef;
    }

  my %divisions;
  my %rtypes;
  my @rounds;
  my %top;
  my $ndivisions = $tournament->CountDivisions();
  my (@all_divisions) = $tournament->Divisions();
  for my $file (readdir $dir) {
    if ($file =~ /^(rosters|prizeslides|prizes|stats|frameset-\S+)\Q$html_suffix\E$/io) {
      my $type = $1;
      if ($ndivisions == 1) {
        $top{$type} = $file;
        }
      else {
	my $div = '~all';
	$divisions{$div}++;
	$rounds[0]{$div}{$type} = $file;
        }
      next;
      }
    elsif ($file =~ /^(roto|total_teams|team-pairings)(?:-(\d+))?\Q$html_suffix\E$/io) {
      my $type = $1;
      my $round = $2 || 0;
      my $div = $ndivisions == 1 ?  lc $all_divisions[0]->Name() : '~all';
      $divisions{$div}++;
      $rounds[$round]{$div}{$type} = $file;
      $rtypes{$type}[$round]{$div}{$type} = $file if $ndivisions == 1;
      next;
      }
    next if $file =~ /(?:grid|handicaps|ratings|CSC-\d+|teams)\Q$html_suffix\E$/io;
    next if $file =~ /tally-slips/ && $no_index_tally_slips;
    next unless $file =~ /^(\w+)-([-a-z_]+(?:[^-\d]\d+)?)(?:-(\d+))?(?:-(\d+))?\Q$html_suffix\E$/io;
    my $div = lc $1;
    my $type = $2;
    my $round = ($3 || 0);
    my $lastround = $4;
    next unless $tournament->GetDivisionByName($div);
    $divisions{$div}++;
    my $fulltype = $lastround ? "$type $round-$lastround" : $type;
    $round = 0 if $file =~ /\bscoreboard\b/;
    $rounds[$round]{$div}{$fulltype} = $file;
    $rtypes{$type}[$round]{$div}{$fulltype} = $file if $round;
    }
  closedir $dir;

  if (my $extrasp = $config->Value('index_top_extras')) {
    if (ref($extrasp) eq 'HASH') {
      for my $key (keys %$extrasp) {
	$top{$key} = $extrasp->{$key};
        }
      }
    }

  my %hash;
  $hash{'rounds'} = \@rounds if @rounds;
  $hash{'rtypes'} = \%rtypes if %rtypes;
  $hash{'divisions'} = \%divisions if %divisions;
  $hash{'top'} = \%top if %top;
  return \%hash;
  }


=item $hashp = $logp->ScanIndexFile($fh);

Scan a previously created index file to reimport information about
the files it indexed, to facilitate subsequent preparation of a master
index.

Takes as argument an open filehandle, which should be locked.

Return a reference to a hash with keys 
C(<div>),
C(<rounds>),
C(<top>),
for use by C<MakeHTMLIndex>, the same as C<ScanHTMLFiles>.

=cut

sub ScanIndexFile ($$) {
  my $this = shift;
  my $fh = shift;

  my $tournament = $this->{'tournament'};
  my $config = $tournament->Config();
  my $no_index_tally_slips = $config->Value('no_index_tally_slips');
  my $html_suffix = $config->Value('html_suffix');

  local($/);
  $_ = scalar(<$fh>);

  my %divisions;
  my %rtypes;
  my @rounds;
  my %top;

  my $round = 0;
  if (m!<tr class="?divheads"?>([^\0]+?)</tr>!) {
    my $divheads = $1;
    for my $cell_html (split(/<th\s+/, $divheads)) {
      next unless $cell_html =~ m!\bdata-div="([^"]+)".*>([^<]+)<!;
      my $div = $1;
      my $title = $2;

      $this->{'divtitles'}{uc $div} = $title;
      }
    }

  for my $round_html (m!<tr class="?round0?"?>([^\0]*?)</tr>!gi) {
    if ($round_html =~ s!^<td class=round>[^<]+ (\d+)</td>\s*!!) {
      $round = $1;
#     warn "Matched round $round: $round_html";
      }
    elsif ($round_html =~ s!^<td class=round>&nbsp;</td>\s*!!) {
      $round = 0;
      }
    else {
      warn "No <td class=round in: $round_html";
      }
    # warn "$round: $round_html";
    for my $cell_html (split(/<td\s+/, $round_html)) {
      for my $link_html (split(/<div class="link /, $cell_html)) {
	next unless $link_html =~ m!^([^"]+)"><a href="([^"]+)" data-div="([^"]+)"!;
	my $type = $1;
	my $url = $2;
	my $div = $3;

	$divisions{$div}++;
	$rounds[$round]{$div}{$type} = $url;
	$rtypes{$type}[$round]{$div}{$type} = $url;
#       warn "Found cell D$div R$round T$type: $url";
        }
      }
    }

  my %hash;
  $hash{'rounds'} = \@rounds if @rounds;
  $hash{'rtypes'} = \%rtypes if %rtypes;
  $hash{'divisions'} = \%divisions if %divisions;
  $hash{'top'} = \%top if %top;
  return \%hash;
  }

=item $logp->ToggleRowParity($parity);

If the boolean lvalue C<$parity> is true, set the current row class parity
to odd; else even.  In either case, toggle the value of C<$parity>.

=cut

sub ToggleRowParity ($$) {
  my $logp = shift;
# print STDERR $logp->{'row_class'};
  if ($_[0]) {
    $logp->RowClassRemove('odd');
    $logp->RowClassAdd('even');
    $_[0] = 0;
    }
  else {
    $logp->RowClassRemove('even');
    $logp->RowClassAdd('odd');
    $_[0] = 1;
    }
# print STDERR " $logp->{'row_class'}\n";
  }

=item $log->Write($text,$html)

Write text to logs and console.

=cut

sub Write ($$$) {
  my $this = shift;
  my $text = shift;
  my $html = shift;
  my $fh;
  ExpandEntities $text;
  PrintConsoleCrossPlatform $text unless $this->{'options'}{'noconsole'};
# unless (defined $html) { use Carp; confess "no html"; }
  $fh = $this->{'text_fh'}; print $fh $text if $fh;
# use PerlIO; die join(',',PerlIO::get_layers($this->{'subhtml_fh'}));
  $fh = $this->{'subhtml_fh'}; print $fh $html if $fh;
  }

=item $log->WritePartialWarning($colspan);

Warn user that results are incomplete.

=cut

sub WritePartialWarning ($$) {
  my $this = shift;
  my $colspan = shift;
  $this->Write("Based on PARTIAL results\n\n", 
    "<tr><td colspan=$colspan class=warning>Based on PARTIAL results</td></tr>\n")
  }

=item $log->WriteRow(\@coltext[, \@colhtml]);

Appends a row of data cells, to be output later by Flush(),
possibly invoked by Close().  
Saves a copy of the current values of column classes and attributes.

=cut

sub WriteRow ($$;$) {
  my $this = shift;
  my $textp = shift;
  my $htmlp = shift;
  if (!defined $htmlp) { $htmlp = $textp; }
  if (@$textp) {
    for my $text (@$textp) { ExpandEntities $text; }
    push(@{$this->{'data_text'}}, [@{$this->{'column_classes'}}], [@$textp]);
    }
  push(@{$this->{'data_html'}}, 
    {
      'attributes' => [@{$this->{'column_attributes'}}],
      'classes' => [@{$this->{'column_classes'}}],
      'row_class' => $this->{'row_class'},
    }, [@$htmlp]) 
    if @$htmlp;
  }

=item $log->WriteTitle(\@text, \@html, $optionsp);

Appends a rows of title cells to the current title area;
if option 'inline' is set, append them as inline headings
to the current data row buffer.

If data rows have already been stored (and option 'inline'
is not set), flush them and purge
any previous title rows.

Saves a copy of the current values of column classes and attributes.

=cut

sub WriteTitle ($$;$$) {
  my $this = shift;
  my $textp = shift;
  Carp::confess ref($textp) unless ref($textp) eq 'ARRAY';
  my $htmlp = shift;
  my $optionsp = shift || {};
  my $opt_inline = $optionsp->{'inline'};
  if ((!$opt_inline) and $this->Flush()) {
    $this->{'title_html'} = [];
    $this->{'title_text'} = [];
    }
  if (!defined $htmlp) { $htmlp = $textp; }
  if (@$textp) {
    for my $text (@$textp) { ExpandEntities $text; }
    push(@{$this->{$opt_inline ? 'data_text' : 'title_text'}},
      [@{$this->{'column_classes'}}], [@$textp]) 
    }
  push(@{$this->{$opt_inline ? 'data_html' : 'title_html'}}, 
    {
      'attributes' => [@{$this->{'column_attributes'}}],
      'classes' => [@{$this->{'column_classes'}}],
      'row_class' => $this->{'row_class'},
      'tag' => 'th',
    }, [@$htmlp]) 
    if @$htmlp;
  }

=back

=cut

=head1 BUGS

None known.

=cut


1;

