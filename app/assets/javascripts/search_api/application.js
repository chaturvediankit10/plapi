// This is a manifest file that'll be compiled into application.js, which will include all the files
// listed below.
//
// Any JavaScript/Coffee file within this directory, lib/assets/javascripts, or any plugin's
// vendor/assets/javascripts directory can be referenced here using a relative path.
//
// It's not advisable to add code directly here, but if you do, it'll appear at the bottom of the
// compiled file. JavaScript code in this file should be added after the last require_* statement.
//
// Read Sprockets README (https://github.com/rails/sprockets#sprockets-directives) for details
// about supported directives.
//
//= require jquery3
//= require rails-ujs
// require activestorage
//= require turbolinks
// require datatables
// require popper
//= require bootstrap
//= require jquery.validate
// require select2
// require select2-full
//= require_tree ./channels

$(document).ready(function() {
  $("#dttb").dataTable({
    "fnRowCallback": function( nRow, aData, iDisplayIndex, iDisplayIndexFull ) {
      $(nRow).css('background', 'black')
    }
  });
});


// $(document).ready(function(){
// 	$("#sheet").on('click', function(e){
// 		$( "#sheet" ).select2({
// 		    theme: "bootstrap"
// 		});
// 		$(this).val()
// 	});
// });

function myFunction(){
  if($("#sub_sheets").is(':visible')){
    $("#sub_sheets").hide();
    $("h4#sheet-title").hide();
    $("#indication-arrow").removeClass("fa-caret-up");
    $("#indication-arrow").addClass("fa-caret-down");
  }
  else{
    $("#sub_sheets").show();
    $("h4#sheet-title").show();
    $("#indication-arrow").removeClass("fa-caret-down");
    $("#indication-arrow").addClass("fa-caret-up");
  }
}
