/***********************************************************************
**                                                                    **
**  Makes the list of transcripts collapsible                         **
**                                                                    **
**  Public functions: None...                                         **
**                                                                    **
***********************************************************************/

  function __init_table_dropdown(table_id) {
/** Initialize link to either collapse or expand transcript list.

    PRIVATE - should only be executed once on page load
**/

// If no transcripts OR already generated link so return....
    if( !$(table_id) || $(table_id + '_link') ) return;

    var initial_open = $(table_id).visible();
    var txt_on       = 'show ' + table_id;
    var txt_off      = 'hide ' + table_id;

    $(table_id + '_text').appendChild(
      Builder.node( 'div',
        { id: table_id + '_link' }, 
        [ initial_open ? txt_off : txt_on ]
      )
    );

    Event.observe($(table_id + '_link'),'click',function(event){
      $(table_id).toggle();
      $(table_id+'_link').remove();
      __init_table_dropdown(table_id);
    });
  }
  function __init_transcript_dropdown() { __init_table_dropdown('transcripts'); }
  function __init_location_dropdown()   { __init_table_dropdown('locations'); }

  addLoadEvent( __init_transcript_dropdown );
  addLoadEvent( __init_location_dropdown  );
