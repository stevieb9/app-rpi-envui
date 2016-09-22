$(document).ready(function(){

    var host = 'http://localhost:5000';

    setInterval(fetch, 3000);

    function fetch(){
        $.get(host +'/fetch', function(data){
            var json = $.parseJSON(data);
            display_temp(json.temp);
            display_humidity(json.humidity);
        });
    };

    $(function(){

        $('.button').switchbutton({
            checked: false,
            onChange: function(checked){
                var id = $(this).attr('id');
                $.get(host +'/set_aux/'+ id +'/'+ checked, function(data){
                    var json = $.parseJSON(data);
                    alert(json.aux +':'+ json.state);
                });
            }
        });
    });

    /*
        helper methods
    */

    function display_temp(temp){
        if (temp > 15){
            $('#temp').css('color', 'red');
        }
        else {
            $('#temp').css('color', 'green')
        }
        $('#temp').text(temp);
    }

    function display_humidity(humidity){
        if (humidity < 22){
            $('#humidity').css('color', 'red');
        }
        else {
            $('#humidity').css('color', 'green')
        }
        $('#humidity').text(humidity);
    }

});
