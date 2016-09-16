$(document).ready(function(){

    setInterval(call, 3000);

    function call(){
            jQuery.get('http://localhost:5000/call/aux1/HIGH', function(data){
                var json = jQuery.parseJSON(data);
                alert(json.state);
            });
    };

    $(function(){
        $('#aux1_toggle').switchbutton({
            checked: false,
            onChange: function(checked){
                $("#aux1").css("color", state_colour(checked));
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
