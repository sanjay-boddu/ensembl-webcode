package EnsEMBL::Web::Component::Transcript::SupportingEvidenceAlignment;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Transcript);
use EnsEMBL::Web::ExtIndex;
use EnsEMBL::Web::Document::HTML::TwoCol;


#use Data::Dumper;
#$Data::Dumper::Maxdepth = 3;

sub _init {
    my $self = shift;
    $self->cacheable( 1 );
    $self->ajaxable(  1 );
}

sub caption {
    return undef;
}

sub content {
    my $self = shift;
    my $object = $self->object;
    my $table  = new EnsEMBL::Web::Document::HTML::TwoCol;
    my $tsi = $object->stable_id;
    my $input = $object->input;

    my $hit_id = $input->{'sequence'}->[0];
    my $hit_db_name = $object->get_hit_db_name($hit_id);

    #get external sequence and type (DNA or PEP) - refseq try with and without version
    my ($query_db, $ext_seq);
    my @hit_ids = ( $hit_id );
    if ($hit_db_name =~ /^RefSeq/) {
	$query_db = 'RefSeq';
	$hit_id =~ s/\.\d+//;
	push @hit_ids, $hit_id;
    }
    else {
	$query_db = $hit_db_name;
    }

    foreach my $id ( @hit_ids ) {
	$ext_seq = $object->get_ext_seq( $id,uc($query_db) );
	if ($ext_seq) {
	    $hit_id = $id;
	    last;
	}
    }
    unless( $ext_seq ) {
	$object->problem( 'fatal', "External Feature Alignment Does Not Exist", "The sequence for feature $hit_id could not be retrieved.");
	return;
    }

    #munge hit name for the display
    if ($hit_db_name =~ /^RefSeq/) {
	$ext_seq =~ s/\w+\|\d+\|ref\|//;
	$ext_seq =~ s/\|.+//m;
    }
    if ($hit_db_name =~ /Uniprot/i) {
	$ext_seq =~ s/ .+$//m;
    }

    $ext_seq =~ s /^ //mg; #remove white space from the beginning of each line of sequence

    my $hit_url = $object->get_ExtURL_link( $hit_id, $hit_db_name, $hit_id );

    #working with DNA or PEP ?
    my $seq_type = $object->determine_sequence_type( $ext_seq );

    my $ext_seq_length = length($ext_seq);
    my $label = $seq_type eq 'PEP' ? 'aa' : 'bp';

    $table->add_row('External record',
		    "$hit_url ($hit_db_name), length = $ext_seq_length $label",
		    1, );
    my $trans_length = $object->Obj->length;
    my $e_count = scalar(@{$object->Obj->get_all_Exons});
    my $cds_length = '';
    if ( ($seq_type eq 'PEP') && (my $tl = $object->Obj->translation)) {
	$cds_length = ' Translation length: '.$tl->length.' aa';
    }
    $table->add_row('Transcript details',
		    "<p>Exons: $e_count. Length: $trans_length bp.$cds_length</p>",
		    1, );
    my $e_alignment;
    my $html;

    #exon alignment (if exon ID is in the URL)
    if (my $exon_id = $input->{'exon'}->[0]) {
	my $exon;
	#get cached exon off the transcript
	foreach my $e (@{$object->Obj->get_all_Exons()}) {
	    if ($e->stable_id eq $exon_id) {
		$exon = $e;
		last;
	    }
	}
	my $e_length = $exon->length;

	#get exon sequence
	my $e_sequence  = $object->get_int_seq( $exon, $seq_type, $object->Obj);

	#position of exon in the transcript
	my $trmapper = Bio::EnsEMBL::TranscriptMapper->new($object->Obj);
	my @cdna_coords = $trmapper->genomic2cdna($exon->start, $exon->end, $exon->strand);
	my ($cdna_start,$cdna_end);
	foreach my $map (@cdna_coords) {
	    $cdna_start = $map->start;
	    $cdna_end   = $map->end;
	}

	#get exon alignment
	my $e_alignment = $object->get_alignment( $ext_seq, $e_sequence, $seq_type );
	$table->add_row('Exon Information',
			"<p>$exon_id</p><p>Length: $e_length bp. Transcript coordinates: $cdna_start-$cdna_end bp</p>",
			1, );
	$table->add_row('Exon alignment',
			"<p><pre>$e_alignment</pre></p>",
			1, );
    }

    #get transcript sequence
    my $trans_sequence = $object->get_int_seq( $object->Obj, $seq_type);

    #get transcript alignment
    my $trans_alignment =  $object->get_alignment( $ext_seq, $trans_sequence, $seq_type );
    $table->add_row('Transcript alignment',
		    "<p><pre>$trans_alignment</pre></p>",
		    1, );

    return $table->render;
}		

1;

