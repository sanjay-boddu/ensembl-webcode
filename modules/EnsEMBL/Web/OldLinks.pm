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

package EnsEMBL::Web::OldLinks;

### Redirect URLs for both pre-51-style URLs and new/renamed pages in archive links 

use strict;

use base qw(Exporter);

our @EXPORT = our @EXPORT_OK = qw(get_redirect get_archive_redirect);

## Mappings for URLs prior to Ensembl release 51 (still used by some incoming links!)
## Shouldn't need updating

our %script_mapping = (
  'blastview'             => 'Tools/Blast',
  'featureview'           => 'Location/Genome',
  'karyoview'             => 'Location/Genome',
  'mapview'               => 'Location/Chromosome',
  'cytoview'              => 'Location/Overview', 
  'contigview'            => 'Location/View',    
  'sequencealignview'     => 'Location/SequenceAlignment', 
  'syntenyview'           => 'Location/Synteny',          
  'markerview'            => 'Location/Marker',          
  'ldview'                => 'Location/LD',             
  'multicontigview'       => 'Location/Multi',         
  'alignsliceview'        => 'Location/Compara_Alignments/Image', 
  'geneview'              => 'Gene/Summary',                
  'genespliceview'        => 'Gene/Splice',                   
  'geneseqview'           => 'Gene/Sequence',                
  'generegulationview'    => 'Gene/Regulation',             
  'geneseqalignview'      => 'Gene/Compara_Alignments',    
  'genetree'              => 'Gene/Compara_Tree',         
  'familyview'            => 'Gene/Family',              
  'genesnpview'           => 'Gene/Variation_Gene',     
  'idhistoryview'         => 'Gene/Idhistory',         
  'transview'             => 'Transcript/Summary',    
  'exonview'              => 'Transcript/Exons',     
  'protview'              => 'Transcript/ProteinSummary',   
  'transcriptsnpview'     => 'Transcript/Population',      
  'domainview'            => 'Transcript/Domains/Genes',  
  'alignview'             => 'Transcript/SupportingEvidence/Alignment',
  'snpview'               => 'Variation/Explore',                    
  'searchview'            => 'Search/Results',            
  'search'                => 'Search/Results',             
  # internal views
  'colourmap'             => 'Server/Colourmap',          
  'status'                => 'Server/Information',       
  'helpview'              => 'Help/Search',             
);


## Add new views here, and for renamed views, create links both ways (for fast lookup)
 
our %archive_mapping = ('Location/Compara_Alignments'             => { 'initial_release' => 54 },
                         'Location/Multi'                         => { 'initial_release' => 56 },
                         'Location/Compara_Alignments/Image'      => { 'initial_release' => 56 },
                         'Location/Compara'                       => { 'initial_release' => 62 },
                         'Variation/Populations'                  => { 'initial_release' => 60 },
                         'Variation/Individual'                   => { 'renamed' => 'Variation/Sample' }, 
                         'Variation/Sample'                       => { 'formerly' => { 80 => 'Variation/Individual'} },
                         'Variation/Phenotype'                    => { 'initial_release' => 57 },
                         'Variation/HighLD'                       => { 'initial_release' => 58 },
                         'Variation/Compara_Alignments'           => { 'initial_release' => 54 },
                         'Variation/Explore'                      => { 'initial_release' => 65 },
                         'Variation/ExternalData'                 => { 'initial_release' => 57 },
                         'Variation/Citations'                    => { 'initial_release' => 72 },
                         'StructuralVariation/Explore'            => { 'initial_release' => 62 },
                         'StructuralVariation/Evidence'           => { 'initial_release' => 62 },
                         'StructuralVariation/Context'            => { 'initial_release' => 60 },
                         'StructuralVariation/Mappings'           => { 'initial_release' => 70 },
                         'StructuralVariation/Phenotype'          => { 'initial_release' => 70 },
                         'Regulation/Summary'                     => { 'initial_release' => 56 },
                         'Regulation/Cell_line'                   => { 'initial_release' => 58 },
                         'Regulation/Evidence'                    => { 'initial_release' => 56 },
                         'Regulation/Context'                     => { 'initial_release' => 56 },
                         'Gene/Phenotype'                         => { 'initial_release' => 64 },
                         'Gene/Compara'                           => { 'initial_release' => 62 },
                         'Gene/StructuralVariation_Gene'          => { 'initial_release' => 63 },
                         'Gene/TranscriptComparison'              => { 'initial_release' => 71 },
                         'Gene/Expression'                        => { 'initial_release' => 71 },
                         'Gene/SpeciesTree'                       => { 'initial_release' => 69 },
                         'Gene/Alleles'                           => { 'initial_release' => 78 },
                         'Gene/SecondaryStructure'                => { 'initial_release' => 74 },
                         'Gene/ExpressionAtlas'                   => { 'initial_release' => 80 },
                         'Transcript/Ontology/Image'              => { 'initial_release' => 60 },
                         'Transcript/Ontology/Table'              => { 'initial_release' => 60 },
                         'Transcript/Variation_Transcript/Table'  => { 'initial_release' => 68 },
                         'Transcript/Variation_Transcript/Image'  => { 'initial_release' => 68 },
                         'GeneTree/Image'                         => { 'initial_release' => 60 },
                         'Family/Details'                         => { 'initial_release' => 75 },
                         'LRG/Genome'                             => { 'initial_release' => 58 },
                         'LRG/Summary'                            => { 'initial_release' => 58 },
                         'LRG/Variation_LRG/Table'                => { 'initial_release' => 58 },
                         'LRG/Differences'                        => { 'initial_release' => 59 },
                         'LRG/Sequence_DNA'                       => { 'initial_release' => 62 },
                         'LRG/Sequence_cDNA'                      => { 'initial_release' => 62 },
                         'LRG/Sequence_Protein'                   => { 'initial_release' => 62 },
                         'LRG/Exons'                              => { 'initial_release' => 62 },
                         'LRG/ProteinSummary'                     => { 'initial_release' => 65 },
                         'LRG/Phenotype'                          => { 'initial_release' => 76 },
                         'LRG/StructuralVariation_LRG'            => { 'initial_release' => 76 },
                         'Phenotype/Locations'                    => { 'initial_release' => 64 },
                         'Phenotype/All'                          => { 'initial_release' => 69 },
                         'Marker/Details'                         => { 'initial_release' => 59 },
                         'Experiment/Sources'                     => { 'initial_release' => 65 },
                         'Search/New'                             => { 'initial_release' => 63 },       

);

sub get_redirect {
  my ($script, $type, $action) = @_;
  
  if ($script eq 'Page') {
    my $page = $type.'/'.$action;
    return undef unless exists $archive_mapping{$page} && $archive_mapping{$page}{'renamed'};
    return $archive_mapping{$page}{'renamed'};
  }
  else {
    return $script_mapping{$script};
  }
}

sub get_archive_redirect {
  my $url = shift;
  return $archive_mapping{$url};
}

1;
