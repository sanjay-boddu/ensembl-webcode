#!/usr/local/bin/perl
###############################################################################
#   
#   Name:           EnsEMBL::HTML::StaticTemplates.pm
#   
#   Description:    Populates templates for static content.
#                   Run at server startup
#
###############################################################################

package EnsEMBL::Web::Document::DHTMLmerge;
use strict;
use warnings;
use File::Path;
use CSS::Minifier;
use JavaScript::Minifier;
use Digest::MD5 qw(md5_hex);

no warnings "uninitialized";

sub merge_all {
  my( $ini_file, $species_defs ) = @_;
  warn $ini_file;
  my $current_files = {'type'=>'minified','css'=>undef,'js'=>undef};
  if( -e $ini_file && open I, $ini_file ) {
    while(<I>) {
warn ".... $_ ....";
      $current_files->{$1}=$2 if /^(\w+)\s*=\s*(\S+)/;
    }
    close I;
  }
#  warn $species_defs->ENSEMBL_JSCSS_TYPE;
#  warn $species_defs->ENSEMBL_JS_NAME;
#  warn $species_defs->ENSEMBL_CSS_NAME;
  warn "
*  $current_files->{'css'}
*  $current_files->{'js'}
*  $current_files->{'type'}
";

  my $css_update = merge( $species_defs, 'css', $current_files->{'css'} );
  my $js_update  = merge( $species_defs, 'js',  $current_files->{'js'}  );
  warn "
X  $css_update
X  $js_update
X  $current_files->{'type'}
";
  if( $css_update || $js_update ) {
    $current_files->{'css'} = $css_update ? $css_update : $current_files->{'css'};
    $current_files->{'js'}  = $js_update  ? $js_update  : $current_files->{'js'};
    open O, ">$ini_file";
  warn "
#  $current_files->{'css'}
#  $current_files->{'js'}
#  $current_files->{'type'}
";
    warn "WRITING NEW FILE....";
    printf O "type = %s\ncss = %s\njs = %s\n",
      $current_files->{'type'}, $current_files->{'css'}, $current_files->{'js'};
    close O;
    warn "Modifying and re-writing species_defs";
    $species_defs->{'_storage'}{'ENSEMBL_JSCSS_TYPE'} = $current_files->{'type'};
    $species_defs->{'_storage'}{'ENSEMBL_JS_NAME'}    = $current_files->{'js'};
    $species_defs->{'_storage'}{'ENSEMBL_CSS_NAME'}   = $current_files->{'css'};
    warn "WRITNG SPECIES_DEFS FILE";
    $species_defs->store(); 
    warn "WRITEN SPECIES_DEFS";
  }
}

sub merge {
  my( $species_defs, $type, $current_file ) = @_;
  my %contents = ();
  my $first_root = ${SiteDefs::ENSEMBL_SERVERROOT}.'/htdocs/';
  foreach my $root ( reverse @SiteDefs::ENSEMBL_HTDOCS_DIRS ) {
    my $dir = "$root/components";
    if( -e $dir && -d $dir ) {
      opendir DH, $dir;
      my @T = readdir( DH );
      my @files = sort grep { /^\d/ && -f "$dir/$_" && /\.$type$/ } @T;
      closedir DH;
      foreach my $fn (@files) {
        warn $fn;
        my($K,$V) = split /-/, $fn;
        open I, "$dir/$fn";
        local $/ = undef;
        my $CONTENTS = <I>;
        close I;
        $contents{$K} .= "
/***********************************************************************
 $dir/$fn
***********************************************************************/

$CONTENTS

";
      }
    }
  }
  my $NEW_CONTENTS = '';
  foreach ( sort keys %contents ) {
    warn "MERGING $_";
    $NEW_CONTENTS .= $contents{$_};
  }
  warn "New contents for $type produced";
  if( $current_file ) {
    if (open I, "$first_root/merged/$current_file.$type") {
      local $/ = undef;
      my $CONTENTS = <I>;
      close I;
      return undef if $CONTENTS eq $NEW_CONTENTS;
    }
  }
  my $filename = md5_hex( $NEW_CONTENTS );
  my $fn = "$first_root/merged/$filename.$type";
  
  open O, ">$fn" or die "can't open $fn for writing";
  print O $NEW_CONTENTS;
  close O;
  my $minified = "$first_root/minified/$filename.$type";
  open INFILE,  $fn;
  warn "Creating $minified file??";
  return undef unless open OUTFILE, ">$minified";
  if( $type eq 'css' ) {
    CSS::Minifier::minify(input => *INFILE, outfile => *OUTFILE);
  } else {
    JavaScript::Minifier::minify(input => *INFILE, outfile => *OUTFILE);
  }
  close OUTFILE;
  close INFILE;
  warn "New contents for $type saved to:
  Merged:   $fn
  Minified: $minified
";
  return $filename;
}

1;
