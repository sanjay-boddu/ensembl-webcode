=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

package EnsEMBL::Web::Component::Gene::GeneSummary;

use strict;

use EnsEMBL::Web::Document::Image::R2R;

use base qw(EnsEMBL::Web::Component::Gene);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(1);
}

sub content {
  my $self          = shift;
  my $hub           = $self->hub;
  my $object        = $self->object;
  my $species_defs  = $hub->species_defs;
  my $table         = $self->new_twocol;
  my $site_type     = $species_defs->ENSEMBL_SITETYPE;
  my @CCDS          = @{$object->Obj->get_all_DBLinks('CCDS')};
  my @Uniprot       = @{$object->Obj->get_all_DBLinks('Uniprot/SWISSPROT')};
  my $db            = $object->get_db;
  my $alt_genes     = $self->_matches('alternative_genes', 'Alternative Genes', 'ALT_GENE', 'show_version'); #gets all xrefs, sorts them and stores them on the object. Returns HTML only for ALT_GENES
  my @RefSeqMatches = @{$object->gene->get_all_Attributes('refseq_compare')};
  my $display_link  = $self->get_gene_display_link;

  $table->add_row('Name', qq|<p>$display_link->{'link'} ($display_link->{'dbname'})</p>|) if $display_link;

  # add CCDS info
  if (scalar @CCDS) {
    my %temp = map { $_->display_id, 1 } @CCDS;
    @CCDS = sort keys %temp;
    $table->add_row('CCDS', sprintf('<p>This gene is a member of the %s CCDS set: %s</p>', $species_defs->DISPLAY_NAME, join ', ', map $hub->get_ExtURL_link($_, 'CCDS', $_), @CCDS));
  }

  # add Uniprot info
  if (scalar @Uniprot) {
    my %temp = map { $_->primary_id, 1 } @Uniprot;
    @Uniprot = sort keys %temp;
    $table->add_row('UniProtKB', sprintf('<p>This gene has proteins that correspond to the following Uniprot identifiers: %s</p>', join ', ', map $hub->get_ExtURL_link($_, 'Uniprot/SWISSPROT', $_), @Uniprot));
  }

  ## add RefSeq match info where appropriate
  if (scalar @RefSeqMatches) {
    my $string;
    foreach my $match (@RefSeqMatches) {
      my $v = $match->value;
      $v =~ /RefSeq Gene ID ([\d]+)/;
      my $id = $1;
      my $url = $hub->get_ExtURL('REFSEQ_GENEIMP', $id);
      (my $link = $v) =~ s/RefSeq Gene ID ([\d]+)/RefSeq Gene ID <a href="$url" rel="external">$1<\/a>/;
      $string .= sprintf('<p>%s</p>', $link);
    }
    $table->add_row('RefSeq', $string);
  }

  ## LRG info
  # first link to direct xrefs (i.e. this gene has an LRG)
  my @lrg_matches = @{$object->get_database_matches('ENS_LRG_gene')};
  my $lrg_html;
  my %xref_lrgs;    # this hash will store LRGs we don't need to re-print

  if(scalar @lrg_matches && $hub->species_defs->HAS_LRG) {
    my $lrg_link;
    for my $i(0..$#lrg_matches) {
      my $lrg = $lrg_matches[$i];
      my $link = $hub->get_ExtURL_link($lrg->display_id, 'ENS_LRG_gene', $lrg->display_id);

      if($i == 0) { # first one
        $lrg_link .= $link;
      }
      elsif($i == $#lrg_matches) { # last one
        $lrg_link .= " and ".$link;
      }
      else { # any other
        $lrg_link .= ", ".$link;
      }
      $xref_lrgs{$lrg->display_id} = 1;
    }
    $lrg_link =
      $lrg_link." provide".
      (@lrg_matches > 1 ? "" : "s").
      " a stable genomic reference framework ".
      "for describing sequence variants for this gene";

    $lrg_html .= $lrg_link;
  }

  # now look for lrgs that contain or partially overlap this gene
  foreach my $attrib(@{$object->gene->get_all_Attributes('GeneInLRG')}, @{$object->gene->get_all_Attributes('GeneOverlapLRG')}) {
    next if $xref_lrgs{$attrib->value};
    my $link = $hub->get_ExtURL_link($attrib->value, 'ENS_LRG_gene', $attrib->value);
    $lrg_html .= '<br/>' if $lrg_html;
    $lrg_html .=
      'This gene is '.
      ($attrib->code =~ /overlap/i ? "partially " : " ").
      'overlapped by the stable genomic reference framework '.$link;
  }

  # add a row to the table
  $table->add_row('LRG', $lrg_html) if $lrg_html;

  $table->add_row('Ensembl version', $object->stable_id.'.'.$object->version);

  ## Link to another assembly, e.g. previous archive
  my $current_assembly = $hub->species_defs->ASSEMBLY_VERSION;
  my $alt_assembly = $hub->species_defs->SWITCH_ASSEMBLY;
  my $alt_release = $hub->species_defs->SWITCH_VERSION;
  my $site_version = $hub->species_defs->ORIGINAL_VERSION || $hub->species_defs->ENSEMBL_VERSION;

  if ($alt_assembly) {
    my $txt;
    my $url = 'http://'.$hub->species_defs->SWITCH_ARCHIVE_URL;
    my $mapping = grep sprintf('chromosome:%s#chromosome:%s', $current_assembly, $alt_assembly), @{$hub->species_defs->get_config($hub->species, 'ASSEMBLY_MAPPINGS')||[]};
    ## get coordinates on other assembly if available
    if ($mapping) {
        my $segments = $object->get_Slice->project('chromosome', $alt_assembly);
        ## link if there is an ungapped mapping of whole gene
        if (scalar(@$segments) == 1) {
          my $new_slice = $segments->[0]->to_Slice;
          $txt .= "<p>This gene maps to ";
          $txt .= sprintf(qq(<a href="${url}%s/Location/View?r=%s:%s-%s" target="external">%s-%s</a>),
                          $hub->species_path,
                          $new_slice->seq_region_name,
                          $new_slice->start,
                          $new_slice->end,
                          $self->thousandify($new_slice->start),
                          $self->thousandify($new_slice->end));
          $txt .= qq( in $alt_assembly coordinates.</p>);
        }
        else {
            $txt .= qq(<p>There is no ungapped mapping of this gene onto the $alt_assembly assembly.</p>);
          }

        if ($alt_release < $site_version) {
          ## If jumping back, look for old stable IDs
          my @old_ids;
          my $predecessors = $object->get_predecessors();
          foreach my $pred (@$predecessors) {
            if ($pred->release <= $alt_release) {
              push @old_ids, $pred->stable_id();
            }
          }

          ## Dedupe IDs
          my (%seen, @ok_ids);
          foreach (@old_ids) {
            push @ok_ids, $_ unless $seen{$_};
            $seen{$_} = 1;
          }

          if (@ok_ids) {
            $txt .= qq(<p>View this locus in the $alt_assembly archive: );
            foreach my $id (@ok_ids) {
              $txt .= sprintf(qq(<a href="%s" rel="external">%s</a> ),
                          $url.$hub->species_path."/Gene/Summary?g=".$id,$id);
            }
          }
          else {
            $txt .= 'Stable ID '.$hub->param('g')." not present in $alt_assembly.";
          }
        }
      }
      else {
        $txt .= sprintf('<p><a href="%s/%s/Search/Results?q=%s" rel="external">Search for this gene</a> on assembly %s.</p>', $url, $hub->species_path, $hub->param('g'), $alt_assembly);
      } 
      $table->add_row("$alt_assembly assembly", $txt);
    }

  # add some Vega info
  if ($db eq 'vega') {
    my $type    = $object->gene_type;
    my $version = $object->version;
    my $c_date  = $object->created_date;
    my $m_date  = $object->mod_date;
    my $author  = $object->get_author_name;
    my $remarks = $object->retrieve_remarks;

    $table->add_row('Gene type', qq{<p>$type [<a href="http://vega.sanger.ac.uk/info/about/gene_and_transcript_types.html" target="external">Definition</a>]</p>});
    $table->add_row('Version &amp; date', qq{<p>Version $version</p><p>Modified on $m_date (<span class="small">Created on $c_date</span>)<span></p>});
    $table->add_row('Author', "This transcript was annotated by $author");
    if ( @$remarks ) {
      my $text;
      foreach my $rem (@$remarks) {
      	next unless $rem;  #ignore remarks with a value of 0
        $text .= "<p>$rem</p>";
      }
      $table->add_row('Remarks', $text) if $text;
    }
  } else {
    my $type = $object->gene_type;
    $table->add_row('Gene type', $type) if $type;
  }

  eval {
    # add prediction method
    my $label = ($db eq 'vega' || $site_type eq 'Vega' ? 'Curation' : 'Annotation') . ' method';
    my $text  = "<p>No $label defined in database</p>";
    my $o     = $object->Obj;

    if ($o && $o->can('analysis') && $o->analysis && $o->analysis->description) {
      $text = $o->analysis->description;
    } elsif ($object->can('gene') && $object->gene->can('analysis') && $object->gene->analysis && $object->gene->analysis->description) {
      $text = $object->gene->analysis->description;
    }

    $table->add_row($label, $text);
  };

  $table->add_row('Alternative genes', $alt_genes) if $alt_genes; # add alternative gene info

  my $cv_terms = $object->get_cv_terms;
  if (@$cv_terms) {
    my $first = shift @$cv_terms;
    my $text = qq(<p>$first [<a href="http://vega.sanger.ac.uk/info/about/annotation_attributes.html" target="external" class="constant">Definitions</a>]</p>);
    foreach my $next (@$cv_terms) {
      $text .= "<p>$next</p>";
    }
    $table->add_row('Annotation Attributes', $text) if $text;;
  }

  ## Secondary structure (currently only non-coding RNAs)
  if ($hub->database('compara') && $object->availability->{'has_2ndary'}) {
    my $image           = EnsEMBL::Web::Document::Image::R2R->new($hub, $self, {});
    my ($display_name)  = $object->display_xref;
    my $svg_path        = $image->render($display_name, 1);
    my $html;
    if ($svg_path) {
      my $fullsize = $hub->url({'action' => 'SecondaryStructure'});
      $html = qq(<object data="$svg_path" type="image/svg+xml"></object>
<br /><a href="$fullsize">[click to enlarge]</a>);
      $table->add_row('Secondary structure', $html);
    }
  }

  return $table->render;
}

sub get_synonyms {
  my ($self, $match_id, @matches) = @_;
  my ($ids, $syns);
  foreach my $m (@matches) {
    my $dbname = $m->db_display_name;
    my $disp_id = $m->display_id;
    if ($dbname =~/(HGNC|ZFIN)/ && $disp_id eq $match_id) {
      my $synonyms = $m->get_all_synonyms;
      $ids = '';
      $ids = $ids . ', ' . (ref $_ eq 'ARRAY' ? "@$_" : $_) for @$synonyms;
    }
  }
  $ids  =~ s/^\,\s*//;
  $syns = $ids if $ids =~ /^\w/;
  return $syns;
}

1;
