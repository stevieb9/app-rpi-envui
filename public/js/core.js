$(document).ready(function(){

    var host = 'http://localhost:5000';
    //setInterval(fetch, 3000);

    for(i = 1; i < 5; i++){
        var aux = 'aux'+ i;
        aux_state(aux);
    }

    function fetch(){
        $.get(host +'/fetch', function(data){
            var json = $.parseJSON(data);
            display_temp(json.temp);
            display_humidity(json.humidity);
        });
    };

    function aux_state(aux){
        $.get(host +'/get_aux/' + aux, function(state){
            $('#'+ aux).switchbutton({
                checked: state,
                onChange: function(checked){
                    $.get(host +'/set_aux/'+ aux +'/'+ checked, function(data){
                        // ...
                    });
                }
            });
        });
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
