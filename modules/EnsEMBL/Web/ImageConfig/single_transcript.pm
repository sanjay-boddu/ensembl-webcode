package EnsEMBL::Web::ImageConfig::single_transcript;

use strict;
use warnings;
no warnings 'uninitialized';

use base qw(EnsEMBL::Web::ImageConfig);

sub init {
  my $self = shift;

  $self->set_parameters({
    'title'         => 'Transcript panel',
    'show_buttons'  => 'no',  # do not show +/- buttons
    'show_labels'   => 'no',  # show track names on left-hand side
    'label_width'   => 113,   # width of labels on left-hand side
    'margin'        => 5,     # margin
    'spacing'       => 2,     # spacing
  });

  $self->create_menus(
    'lrg'        => 'LRG transcripts',
    'transcript' => 'Other genes',
    'prediction' => 'Prediction transcripts',
    'other'      => 'Decorations',
  );

  $self->add_tracks( 'other',
    [ 'ruler',     '', 'ruler',     { 'display' => 'normal',  'strand' => 'r', 'name' => 'Ruler' } ],
    [ 'draggable', '', 'draggable', { 'display' => 'normal',  'strand' => 'b', 'menu' => 'no'    } ],
  );

  $self->load_tracks();

  # FIXME - should surely come from db?
  $self->add_tracks('lrg',
    [ 'lrg_transcript',  'LRG', '_lrg_transcript',
      { display => 'normal',
  name => 'LRG transcripts', 
  description => 'Shows LRG transcripts',
  logicnames=>['LRG_download'],
  logic_name=>'LRG_download',
        'colours'     => $self->species_defs->colour( 'gene' ),
        'label_key'   => '[display_label]',
}],
  );

  $self->modify_configs(
    [qw(transcript prediction)],
    {qw(display off height 32 non_coding_scale 0.5)}
  );
}
1;

