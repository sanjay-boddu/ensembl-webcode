package EnsEMBL::Web::Document::HTML::SpeciesList;

use strict;
use warnings;
use Data::Dumper;

use EnsEMBL::Web::RegObj;

{

sub render {
  my ($class, $request) = @_;

  my $species_defs = $EnsEMBL::Web::RegObj::ENSEMBL_WEB_REGISTRY->species_defs;

  my @valid_species = $species_defs->valid_species;
  my $species_check;
  foreach my $sp (@valid_species) {
    $species_check->{$sp}++;
  }

  my %species_info;
  foreach my $species (@valid_species) {
    my $info = $species_defs->get_config($species, "SPECIES_INFO");
    $species_info{$species} = $species_defs->get_config($species, "SPECIES_INFO"); 
  }

  my %species_description = _setup_species_descriptions(\%species_info);

  my $user = $EnsEMBL::Web::RegObj::ENSEMBL_WEB_REGISTRY->get_user;

  my $html = '';
  if ($request && $request eq 'fragment') {
    $html .= _render_species_list($user, $species_defs, \%species_info, \%species_description); 
  } else {
    $html .= qq(<div class="white boxed">
<div id='reorder_species' style='display: none;'>);
    $html .= _render_ajax_reorder_list($user, $species_defs, \%species_info); 
    $html .= qq(</div>\n<div id="full_species">
<p>The <a href="http://www.ensembl.org">Ensembl</a> project produces genome databases
  for vertebrates and other eukaryotic species, and makes this information
  freely available online.</p>

<p>Click on a species name below to browse the data.</p>);
    $html .= _render_species_list($user, $species_defs, \%species_info, \%species_description); 
    $html .= qq(</div>
<p>Other pre-build species are available in <a href="http://pre.ensembl.org" rel="external">Ensembl <em>Pre<span class="red">!</span></em> &rarr;</a></p>
</div>);
  }
  return $html;

}
sub _render_species_list {
  my ($user, $species_defs, $species_info, $description) = @_;
  my ($html, $species_name, $species_dir, $id, $group);

  my @favourites = @{_get_favourites($user, $species_defs, $species_info)};
  my %check_faves;
  foreach my $fave (@favourites) {
    $check_faves{$fave}++;
  }

  ## output list
  $html .= "<div id='static_favourite_species'>\n";
  $html .= "<div class='favourites-species-list'>\n";
  $html .= _render_with_images(\@favourites, $species_defs, $description);

  if (!$user) {
    if ($species_defs->ENSEMBL_LOGINS) {
      $html .= '<a href="javascript:login_link()">Log in to customize this list</a>';
    }
  } else {
    if ($species_defs->ENSEMBL_LOGINS) {
      $html .= 'You are logged in as '. $user->name .' &middot; <a href="#" onclick="toggle_reorder();">Change favourites</a>';
    }
  }
  $html .= "</div>\n";
  $html .= "</div>\n";

  $html .= qq(<div id='static_all_species'>
<form action="#">
<h2>All genomes</h2>
<select name="species"  id="species_dropdown" onchange="dropdown_redirect('species_dropdown');">
  <option value="/">-- Select a species --</option>
);

  my @all_species = keys %$species_info;

  ## sort out labels
  my $labels = $species_defs->TAXON_LABEL;
  my @group_order;
  my %label_check;
  foreach my $taxon (@{$species_defs->TAXON_ORDER}) {
    my $label = $labels->{$taxon} || $taxon;
    push @group_order, $label unless $label_check{$label};
    $label_check{$label}++;
  }

  ## Sort species into desired groups
  my %phylo_tree;
  foreach $species_name (@all_species) {
    my $taxon_group = $species_defs->get_config($species_name, "SPECIES_GROUP");
    my $group = $labels->{$taxon_group} || $taxon_group;
    if (!$group) {
      ## Allow for non-grouped species lists
      $group = 'no_group';
    }
    if ($phylo_tree{$group}) {
      push @{$phylo_tree{$group}}, $species_name;
    }
    else {
      $phylo_tree{$group} = [$species_name];
    }
  }  

  ## Output in taxonomic groups, ordered by common name
  my $others = 0;
  foreach my $group_name (@group_order) {
    my $optgroup = 0;
    my @sorted_by_common; 
    my $species_list = $phylo_tree{$group_name};
    if ($species_list && ref($species_list) eq 'ARRAY' && scalar(@$species_list) > 0) {
      if ($group_name eq 'no_group') {
        if (scalar(@group_order) > 1) {
          $html .= '<optgroup label="Other species">'."\n";
          $optgroup = 1;
          $others = 1;
        }
      }
      else {
        (my $group_text = $group_name) =~ s/&/&amp;/g;
        $html .= '<optgroup label="'.$group_text.'">'."\n";
        $optgroup = 1;
      }
      @sorted_by_common = sort {
                          $species_defs->get_config($a, "SPECIES_COMMON_NAME")
                          cmp
                          $species_defs->get_config($b, "SPECIES_COMMON_NAME")
                          } @$species_list;
    }
    foreach $species_name (@sorted_by_common) {
      $html .= '<option value="/'.$species_name.'/">'.$species_defs->get_config($species_name, "SPECIES_COMMON_NAME");
      $html .= $description->{$species_name}[1] if $description->{$species_name}[1];
      $html .= '</option>'."\n";
    }

    $html .= '</optgroup>'."\n" if $optgroup == 1;
  }

  $html .= '<optgroup label="Other species">'."\n" if !$others;

  $html .= qq(
  <option value="/species.html">-- Find a species --</option>
</select>
</form>
);
  
  $html .= qq(</div>\n);
  return $html;
}

sub _render_ajax_reorder_list {
  my ($user, $species_defs, $species_info) = @_;
  my ($html, $species_name, $species_dir, $id);

  $html .= "For easy access to commonly used genomes, drag from the bottom list to the top one &middot; <a href='#' onClick='toggle_reorder();'>Done</a><br /><br />\n";

  $html .= "<div id='favourite_species'>\n<b>Favourites</b>";
  my @favourites = @{_get_favourites($user, $species_defs, $species_info)};

  $html .= "<ul id='favourites_list'>\n";
  foreach $species_name (@favourites) {
    $species_dir = $species_name;
    $id = $species_info->{$species_name}{'id'};
    $species_name =~ s/_/ /;
    my $common = $species_defs->get_config($species_dir, 'SPECIES_COMMON_NAME');
    $html .= "<li id='favourite_$id'>$common (<em>" .$species_name."</em>)</li>\n" if $id;
  }

  $html .= "</ul></div>\n";
  $html .= "<div id='all_species'>\n<b>Other available species</b>";
  $html .= "<ul id='species_list'>\n";


  my %sp_to_sort = %$species_info;
  foreach my $fave (@favourites) {
    delete $sp_to_sort{$fave};
  }
  my @sorted_by_common = sort {
                          $species_defs->get_config($a, "SPECIES_COMMON_NAME")
                          cmp
                          $species_defs->get_config($b, "SPECIES_COMMON_NAME")
                          } keys %sp_to_sort;
  foreach $species_name (@sorted_by_common) {
    $species_dir = $species_name;
    $species_name =~ s/_/ /;
    $id = $sp_to_sort{$species_dir}->{'id'};
    my $common = $species_defs->get_config($species_dir, 'SPECIES_COMMON_NAME');
    $html .= "<li id='species_$id'>$common (<em>" . $species_name . "</em>)</li>\n" if $id;
  }

  $html .= "</ul></div>\n";
  $html .= "<a href='javascript:void(0);' onclick='toggle_reorder();'>Finished reordering</a> &middot; <a href='/common/user/reset_favourites'>Restore default list</a>";

  return $html;
}

sub _setup_species_descriptions {
  my $species_info = shift;
  my %description = ();

  my $updated = '<strong class="alert">NEW ASSEMBLY</strong>';
  my ($html, $dropdown);

  while (my ($species, $info) = each (%$species_info)) {
    $html = qq( <span class="small normal">);
    $html .= $info->{'assembly'} if $info->{'assembly'};
    if (!$info->{'prev_assembly'}) {
      $dropdown = ' - NEW SPECIES';
    } elsif ($info->{'prev_assembly'} && $info->{'prev_assembly'} ne $info->{'assembly'}) {
      $html .= ' '.$updated;
      $dropdown = ' - NEW ASSEMBLY';
    }
    else {
      $dropdown = '';
    }
    $html  .= qq(</span>);
    if ($species) {
      $description{$species} = [$html, $dropdown];
    }
  }

  return %description;
}


sub _get_favourites {
  ## Returns a list of species as Genus_species strings
  my ($user, $species_defs, $species_info) = @_;

  my %id_to_species;
  while (my ($species, $info) = each (%$species_info)) {
    next unless keys %$info;
    $id_to_species{$info->{'id'}} = $species if $info->{'id'};
  }

  my @specieslists = ();
  if ($user) {
    @specieslists = $user->specieslists;
  }
  my @favourites = ();

  if (scalar(@specieslists) > 0 && $specieslists[0]) {
    my $list = $specieslists[0];
    my @all_favourites = split(/,/, $list->favourites);
    ## Omit any species not currently online
    foreach my $fave (@all_favourites) {
      push @favourites, $id_to_species{$fave} if $id_to_species{$fave};
    }
  }
  else {
    @favourites = @{$species_defs->DEFAULT_FAVOURITES};
    if (scalar(@favourites) < 1) {
      @favourites = ($species_defs->ENSEMBL_PRIMARY_SPECIES, $species_defs->ENSEMBL_SECONDARY_SPECIES);
    }
  }

  return \@favourites;
}

sub _render_with_images {
  my ($species_list, $species_defs, $description) = @_;

  my $html .= "<dl class='species-list'>\n";

  foreach my $species_name (@$species_list) {
    my $species_dir = $species_name;
    my $common_name = $species_defs->get_config($species_dir, "SPECIES_COMMON_NAME");
    $species_name =~ s/_/ /g;
    $html .= "<dt class='species-list'><a href='/$species_dir/'><img src='/img/species/thumb_$species_dir.png' alt='$species_name' title='Browse $species_name' class='sp-thumb' height='40' width='40' /></a><a href='/$species_dir/' title='$species_name'>$common_name</a></dt>\n";
    $html .= "<dd>" . $description->{$species_dir}[0] . "</dd>\n" if $description->{$species_dir}[0];
  }
  $html .= "</dl>\n";
  
  return $html;
}

}

1;
