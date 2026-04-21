#!/usr/bin/perl

# Copyright (C) 2009 John J. Chew, III <jjchew@math.utoronto.ca>
# All Rights Reserved

package TSH::Command::EnhancedScoreBoard;

use strict;
use warnings;

use TSH::Log;
# use TSH::Utility qw(Debug DebugOn FormatHTMLHalfInteger FormatHTMLSignedInteger Ordinal);

# DebugOn('SP');

our (@ISA) = qw(TSH::Command);

=pod

=head1 NAME

TSH::Command::EnhancedScoreBoard - implement the C<tsh> EnhancedScoreBoard command

=head1 SYNOPSIS

  my $command = new TSH::Command::EnhancedScoreBoard;
  my $argsp = $command->ArgumentTypes();
  my $helptext = $command->Help();
  my (@names) = $command->Names();
  $command->Run($tournament, @parsed_arguments);
  
=head1 ABSTRACT

TSH::Command::EnhancedScoreBoard is a subclass of TSH::Command.

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
Use this command to add an enhanced scoreboard to your web coverage.
Enhanced scoreboards use AJAX to dynamically update information in
the user browser whenever you trigger the saveJSON command in tsh.
EOF
  $this->{'names'} = [qw(esb enhancedscoreboard)];
  $this->{'argtypes'} = [qw(Division)];
# print "names=@$namesp argtypes=@$argtypesp\n";

  return $this;
  }

sub new ($) { return TSH::Utility::new(@_); }

=item $command->Run($tournament, @parsed_args);

Should run the command in the context of the given
tournament with the specified parsed arguments.

=cut

sub Run ($$@) { 
  my $this = shift;
  my $tournament = shift;
  my $dp = shift;
  my $dname = uc $dp->Name();
  my $config = $tournament->Config();

  $this->Processor()->Process("savejson");
  for my $basename (qw(esb tsh)) {
    my $sourcefn = $config->MakeLibPath("js/$basename.js");
    my $destfn = $config->MakeHTMLPath("$basename.js");
    unless (TSH::Utility::UpdateFile($sourcefn, $destfn)) {
      $tournament->TellUser('efilecp', $sourcefn, $destfn, $!);
      return;
      }
    }

  my $banner = '';
  if (my $banner_height = $config->Value('sb_banner_height')) {
    $banner = qq(banner_height:$banner_height,);
    my $banner_url = $config->Value('sb_banner_url');
    $banner .= qq(banner_url:"$banner_url",) if $banner_url;
    }

  my $esb_geometry = $config->Value('esb_geometry')->{$dname} || [];
  $esb_geometry = [[4,5,0]] unless @$esb_geometry;

  my $offset = 0;
  for my $esb_num (0..$#$esb_geometry) {
    my $geometry = '';
    my $esb_entry = $esb_geometry->[$esb_num] || [];
    $esb_entry = [] unless ref($esb_entry);
    my $cols = $esb_entry->[0];
    $geometry .= "'columns':$cols," if $cols and $cols =~ /^(\d+)$/;
    my $rows = $esb_entry->[1];
    $geometry .= "'rows':$rows," if $rows and $rows =~ /^(\d+)$/;
    $offset = (defined $esb_entry->[2]) ? $esb_entry->[2] : $offset;
    $geometry .= "'offset':$offset," if $offset and $offset =~ /^(\d+)$/;

    my $logp = new TSH::Log($tournament, $dp, 
      'enhanced-scoreboard' . (@$esb_geometry <= 1 ? '' : ('-'.(1+$esb_num))),
      undef,
      {
        'body_class' => 'enhanced scoreboard',
#       'custom_header' => '<meta name="viewport" content="width=device-width; user-scalable=false" />',
#       'custom_header' => '<meta name="viewport" content="width=device-width" />',
        'noconsole' => 1,
        'notext' => 1,
        'notitle' => 1,
        'javascript' => ['tsh.js', 'esb.js'],
      });

    $logp->Write('', <<"EOF");
</table>
<div id='ESBMessageText' class=ESBMessageClass></div>
<div id='sb'></div>
<script type="text/javascript">
  KeepLoadingScoreBoard({
    $banner
    $geometry
    'id' : 'sb',
    'message_object' : document.getElementById('ESBMessageText'),
    'root' : window.location.href.replace(/\\?.*/,'').replace(/[^\//]+\$/, ''),
    'division' : '$dname',
    });
</script>
<table>
EOF
    $logp->Close();
    $offset += ($cols||0) * ($rows||0);
    }
  return 0;
  }

=back

=cut

=head2 BUGS

None known.

=cut

1;
