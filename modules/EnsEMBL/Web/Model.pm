package EnsEMBL::Web::Model;

### NAME: EnsEMBL::Web::Model
### The M in the MVC design pattern - a container for domain objects

### PLUGGABLE: No

### STATUS: Under development
### Currently being developed, along with its associated moduled E::W::Hub,
### as a replacement for Proxy/Proxiable code

### DESCRIPTION:
### Model is a container for domain objects such as Location, Gene, 
### and User and for a single helper module, Hub (see separate 
### documentation on Hub).
### Domain objects are stored as a hash of key-arrayref pairs, since 
### theoretically a page can have more than one domain object of a 
### given type.
### Note: Currently, domain objects are Proxy::Object objects, but an
### alternative implementation is under development 

use strict;
use warnings;
no warnings 'uninitialized';

use URI::Escape qw(uri_escape);

use EnsEMBL::Web::Hub;
use EnsEMBL::Web::Proxy::Factory;

use base qw(EnsEMBL::Web::Root);

sub new {
  my ($class, $args) = @_;
  my $self = { 
    '_objects' => {}, 
  };

  ## Create the hub - a mass of connections to databases, Apache, etc
  $self->{'_hub'} = EnsEMBL::Web::Hub->new(
    '_apache_handle'  => $args->{'_apache_handle'},
    '_input'          => $args->{'_input'},
  );

  bless $self, $class;
  
  $self->hub->parent = $self->_parse_referer;
  
  return $self; 
}

sub hub { return $_[0]->{'_hub'}; }
sub all_objects { return $_[0]->{'_objects'}};

sub objects {
### Getter/setter for domain objects - acts on the default data type 
### for this page if none is specified
### Returns an array of objects of the appropriate type
  my ($self, $type, $objects) = @_;
  $type ||= $self->type;
  if ($objects) {
    my $m = $self->{'_objects'}{$type} || [];
    my @a = ref($objects) eq 'ARRAY' ? @$objects : ($objects); 
    push @$m, @a;
    $self->{'_objects'}{$type} = $m;
  }
  return @{$self->{'_objects'}{$type}};
}

sub object {
### Getter/setter for data objects - acts on the default data type 
### for this page if none is specified
### Returns the first object in the array of the appropriate type
  my ($self, $type, $object) = @_;
  $type ||= $self->hub->type;
  if ($object) {
    my $m = $self->{'_objects'}{$type} || [];
    push @$m, $object; 
    $self->{'_objects'}{$type} = $m;
  }
  return $self->{'_objects'}{$type}[0];
}

sub add_objects {
### Adds domain objects created by the factory to this Model
  my ($self, $data) = @_;
  return unless $data;

  ### Proxy Object(s)
  if (ref($data) eq 'ARRAY') {
    foreach my $proxy_object (@$data) {
      $self->object($proxy_object->__objecttype, $proxy_object);
    }
  }
  ### Other object type
  elsif (ref($data) eq 'HASH') {
    while (my ($key, $object) = each (%$data)) {
      $self->object($key, $object);
    }
  }
}

sub create_objects {
## Currently uses Proxy::Factory
  my ($self, $type) = @_;
  my $factory = $self->_create_proxy_factory($type);
  my $problem;

  if ($factory->has_fatal_problem) {
    $problem = $factory->problem('fatal', 'Fatal problem in the factory')->{'fatal'};
  } else {
    eval {
      $factory->createObjects;
    };
    $factory->problem('fatal', "Unable to execute createObject on Factory of type ".$self->type, $@) if $@;
    # $factory->handle_problem returns string 'redirect', or array ref of EnsEMBL::Web::Problem object
    if ($factory->has_a_problem) {
      $problem = $factory->handle_problem; 
    }
    else {
      $self->add_objects($factory->DataObjects);
    }
  }
  return $problem;
}

sub _create_proxy_factory {
### Creates a Factory object which can then generate one or more 
### domain objects
  my ($self, $type) = @_;
  return unless $type;
  
  return EnsEMBL::Web::Proxy::Factory->new($type, {
    _input         => $self->hub->input,
    _apache_handle => $self->hub->apache_handle,
    _databases     => $self->hub->databases,
    _core_objects  => $self->hub->core_objects,
    _parent        => $self->hub->parent,
  });
}

=pod
## Direct accessors to hub contents, to make life easier!
sub apache_handle     :lvalue { return $_[0]->hub->apache_handle; }
sub type              :lvalue { return $_[0]->hub->type; }
sub function          :lvalue { return $_[0]->hub->function;  }
sub script            :lvalue { return $_[0]->hub->script;  }
sub species           :lvalue { return $_[0]->hub->species; }
sub species_defs      :lvalue { return $_[0]->hub->species_defs }
sub DBConnection      :lvalue { return $_[0]->hub->databases; }
sub ExtURL            :lvalue { return $_[0]->hub->ext_url; } 
sub session           :lvalue { return $_[0]->hub->session; }
sub get_session       :lvalue { return $_[0]->session; }
sub param             :lvalue { return $_[0]->hub->param(@_); }
sub delete_param      :lvalue { my $self = shift; $self->hub->input->delete(@_); }
sub get_databases     :lvalue { my $self = shift; $self->hub->DBConnection->get_databases(@_); }
sub databases_species :lvalue { my $self = shift; $self->hub->DBConnection->get_databases_species(@_); }

sub species_path      :lvalue { my $self = shift; $self->hub->species_defs->species_path(@_); }
sub core_objects      :lvalue { return $_[0]->hub->core_objects; }
sub cache             :lvalue { return $_[0]->hub->cache; }
sub parent            :lvalue { return $_[0]->hub->parent; }

sub url             { return $_[0]->hub->url(@_); }
sub _url            { return $_[0]->hub->url(@_); }
sub viewconfig      { return $_[0]->hub->viewconfig; }
sub get_viewconfig  { return $_[0]->hub->get_viewconfig(@_); }
=cut

1;

