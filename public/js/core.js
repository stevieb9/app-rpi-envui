$(document).ready(function(){

    setInterval(fetch, 3000);

    function fetch(){
        $.get('http://localhost:5000/fetch', function(data){
            var json = $.parseJSON(data);
            display_temp(json.temp);
            display_humidity(json.humidity);
            //alert(json.temp +':'+ json.humidity);
        });
    };

    $(function(){
        $('.button').switchbutton({
            checked: false,
            onChange: function(checked){
                // code here
            }
        });
    });

    /*
        helper methods
    */

    // on/off colours

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
