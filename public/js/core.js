$(document).ready(function(){

    var host = 'http://localhost:5000';
    var aux1 = aux_state('aux1');
    alert(aux1);
    //setInterval(fetch, 3000);

    $(function(){
        $('#aux1').switchbutton({
            checked: aux1,
            onChange: function(checked){
                $.get(host +'/set_aux/aux1/'+ checked, function(data){
                    var json = $.parseJSON(data);
                    //alert(json.state);
                });
            }
        });
    });

    /*
        helper methods
    */

    function fetch(){
        $.get(host +'/fetch', function(data){
            var json = $.parseJSON(data);
            display_temp(json.temp);
            display_humidity(json.humidity);
        });
    };

    function aux_state(aux){
        var data;
        $.get(host +'/get_aux/' + aux, function(state){
            data = state;
        });
        return data;
    }

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
