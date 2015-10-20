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

package EnsEMBL::Draw::GlyphSet::flat_file;

### Module for drawing features parsed from a non-indexed text file (such as 
### user-uploaded data)

use strict;

use EnsEMBL::Web::File::User;
use EnsEMBL::Web::IOWrapper;

use parent qw(EnsEMBL::Draw::GlyphSet::UserData);


sub features {
  my $self         = shift;
  my $container    = $self->{'container'};
  my $hub          = $self->{'config'}->hub;
  my $species_defs = $self->species_defs;
  my $sub_type     = $self->my_config('sub_type');
  my $format       = $self->my_config('format');
  my $data         = [];
  my $legend       = {};

  ## Get the file contents
  my %args = (
              'hub'     => $hub,
              'format'  => $format,
              );

  if ($sub_type eq 'url') {
    $args{'file'} = $self->my_config('url');
    $args{'input_drivers'} = ['URL'];
  }
  else {
    $args{'file'} = $self->my_config('file');
    if ($args{'file'} !~ /\//) { ## TmpFile upload
      $args{'prefix'} = 'user_upload';
    }
  }

  my $file  = EnsEMBL::Web::File::User->new(%args);
  my $iow   = EnsEMBL::Web::IOWrapper::open($file, 
                                            'hub'         => $hub, 
                                            'config_type' => $self->{'config'}{'type'},
                                            'track'       => $self->{'my_config'}{'id'},
                                            );

  if ($iow) {
    ## Parse the file, filtering on the current slice
    $data = $iow->create_tracks($container);

    ## Override colourset based on format here, because we only want to have to do this in one place
    my $colourset   = $iow->colourset || 'userdata';
    $self->{'my_config'}->set('colours', $hub->species_defs->colour($colourset));
    $self->{'my_config'}->set('default_colour', $self->my_colour('default'));
  } else {
    #return $self->errorTrack(sprintf 'Could not read file %s', $self->my_config('caption'));
    warn "!!! ERROR CREATING PARSER FOR $format FORMAT";
  }
  #$self->{'config'}->add_to_legend($legend);

  return $data;
}

1;
