$(document).ready(function(){

    // setInterval(call, 3000);

    function call(){
            jQuery.get('http://localhost:5000/call/aux1/HIGH', function(data){
                var json = jQuery.parseJSON(data);
                alert(json.state);
            });
    };

    $(function(){
        $('.button').switchbutton({
            checked: false,
            onChange: function(checked){
                var id = $(this).attr('id') + '_msg';
                $('#' + id).css("color", state_colour(checked));
            }
        })
    });

    /*
        helper methods
    */

    // on/off colours

    function state_colour(state){
        if (state)
            return "green"
        else
            return "red"
    };
});
