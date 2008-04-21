package EnsEMBL::Web::Data;

use strict;
use warnings;
use EnsEMBL::Web::Cache;
use base qw/EnsEMBL::Web::DBSQL::MySQLAdaptor/;
use Data::Dumper qw//;


#----------------------------------------------------------------------
# Our Class Data
#----------------------------------------------------------------------
__PACKAGE__->mk_classdata(data_fields      => {});
__PACKAGE__->mk_classdata(queriable_fields => {});
__PACKAGE__->mk_classdata(relations        => {});
__PACKAGE__->mk_classdata('__type');

##
## Enhancement for our MySQLAdaptor (Class::DBI), which doesn't have new constructor by default
## arguments:
## LIST of primery keys - will be looked up in DB
## OR!
## HASHREF of values for new object
##
sub new {
  my $class = shift; 
  my $data  = shift;

  if ($data && !ref($data)) {
    if ($class->__type) {
      my $key = $class->get_primary_key;
      return $class->retrieve(
        $key => $data,
        type => $class->__type,
      );
    } else {
      return $class->retrieve($data);
    }
  } else {
  	$class->normalize_column_values($data) if ref $data;
  	$class->validate_column_values($data)  if ref $data;
    return $class->_init($data);
  }
}

sub save {
  my $self = shift;

  if ($self->id) {
    $self->update(@_);
  } else {
    $self->insert_blessed(@_);
  }
}

##
## Fix for insert, to work with new() and save()
##
sub insert_blessed {
	my $self = shift;

  if ( $self->cache ) {
      $self->cache->set( $self->_staleness_cache_key, time() );
  }

	$self->call_trigger('before_create');
	$self->call_trigger('deflate_for_create');

	$self->_prepopulate_id if $self->_undefined_primary;

	# Reinstate data
	my ($real, $temp) = ({}, {});
	foreach my $col (grep $self->_attribute_exists($_), $self->all_columns) {
		($self->has_real_column($col) ? $real : $temp)->{$col} =
			$self->_attrs($col);
	}

	$self->_insert_row($real);

	my @primary_columns = $self->primary_columns;
	$self->_attribute_store(
		$primary_columns[0] => $real->{ $primary_columns[0] })
		if @primary_columns == 1;

	delete $self->{__Changed};

	my %primary_columns;
	@primary_columns{@primary_columns} = ();
	my @discard_columns = grep !exists $primary_columns{$_}, keys %$real;
	$self->call_trigger('create', discard_columns => \@discard_columns);   # XXX

	# Empty everything back out again!
	$self->_attribute_delete(@discard_columns);
	$self->call_trigger('after_create');
	return $self;
}
##/Class::DBI enhancements


sub set_primary_key {
  my $class = shift;
  $class->columns(Primary => @_);
}


sub get_primary_key {
  my $class = shift;
  my @keys = $class->columns(Primary => @_);
  return wantarray ? @keys : $keys[0];
}


sub add_fields {
  my $class = shift;

  $class->add_queriable_field(data => 'data');
  $class->data_fields({
    %{ $class->data_fields },
    @_,
  });
  
  $class->columns(TEMP => keys %{ $class->data_fields });

  $class->add_trigger(select        => \&withdraw_data);
  $class->add_trigger(before_create => \&fertilize_data);
  $class->add_trigger(before_update => \&fertilize_data);
}


sub add_queriable_fields {
  my $class = shift;
  $class->queriable_fields({
    %{ $class->queriable_fields },
    @_,
  });
  
  $class->columns(Essential => keys %{ $class->queriable_fields });
}
*add_queriable_field = \&add_queriable_fields;


sub get_all_fields {
  my $class = shift;

  return {
  %{ $class->data_fields },
  %{ $class->queriable_fields },
  };
}


sub withdraw_data {
  my $self = shift;
  my $hash = eval ($self->data);
  foreach my $field (keys %{ $self->data_fields }) {
    $self->$field($hash->{$field});
  }
}


sub fertilize_data {
  my $self = shift;
  my $hash = {};
  foreach my $field (keys %{ $self->data_fields }) {
    $hash->{$field} = $self->$field;
  }
  $self->data(dump_data($hash));
}


sub dump_data {
  my $data = shift;
  my $temp_fields = {};
  foreach my $key (keys %{ $data }) {
    $temp_fields->{$key} = $data->{$key};
    $temp_fields->{$key} =~ s/'/\\'/g;
  }
  my $dumper = Data::Dumper->new([$temp_fields]);
  $dumper->Indent(0);
  my $dump = $dumper->Dump();
  #$dump =~ s/'/\\'/g;
  $dump =~ s/^\$VAR1 = //;
  return $dump;
}


sub has_a {
  my $class    = shift;
  my $accessor = shift;
  
  $accessor .= '_id';
  
  $class->add_queriable_fields($accessor => 'int');
  return $class->SUPER::has_a($accessor => @_);
}


sub add_has_many {
  my $class = shift;
  my %args  = @_;
  while (my ($key, $value) = each %args) {
    $class->has_many($key => $value);
  }
}


sub has_many {
  my $class    = shift;
  my $accessor = shift;
  my ($relation_class) = @_;
  no strict 'refs';

  my ($owner) = $class =~ /::(\w+)$/;
    
  if (!ref($relation_class) && $relation_class =~ /^EnsEMBL::Web::Data::Record/) {

    $class->_require_class($relation_class);
    $relation_class = $relation_class->add_owner($owner);
    
    $class->relations({
      %{ $class->relations },
      $accessor => $relation_class,
    });

    my $real_accessor = '_'. $accessor;
    $class->SUPER::has_many($real_accessor => $relation_class);

    *{$class."::$accessor"} =
      sub {
        my $self = shift;
        return $self->$real_accessor(@_, type => $relation_class->__type);
      };
    *{$class."::add_to_$accessor"} =
      sub {
        my $self = shift;
        my $add_to_real_accessor = 'add_to_' . $real_accessor;
        return $self->$add_to_real_accessor(@_);
      };

  } else {
    return $class->SUPER::has_many($accessor => @_);
  }
}


sub _type {
  my $class = shift;
  my $type  = shift;
  
  $class->__type($type);
  $class->add_queriable_fields(type => 'string');
  $class->add_trigger(before_create => sub { my $self = shift; $self->type($self->__type) });
}

## 
## Like has_a, but imports all relative properties into our object
## so they both represented together as one entity
##
sub tie_a {
  my $class = shift;
  my ($rel_obj, $rel_class) = @_;
  no strict 'refs';
  
  $class->has_a(@_);
  $class->add_trigger( after_update => sub { shift->$rel_obj->update } );
  foreach my $column (keys %{ $rel_class->get_all_fields }) {
    *{$class."::$column"} = sub { shift->$rel_obj->$column(@_) }
      unless $class->find_column($column);
  }
}

sub find_all { shift->retrieve_all(@_) }
sub find     { shift->retrieve(@_) }
sub destroy  { shift->delete(@_) }

## Set caching object
## Any cache object that has a get, set, and remove method is supported
__PACKAGE__->cache(
  new EnsEMBL::Web::Cache
);

#__PACKAGE__->default_search_attributes( { use_resultset_cache => 1 } );

1;