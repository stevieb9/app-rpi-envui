$(document).ready(function(){

        var logged_in;

        $.ajax({
            async: false,
            type: 'GET',
            url: '/logged_in',
            success: function(data){
                var json = $.parseJSON(data);
                logged_in = json.status;
                console.log("auth: " + logged_in);
            }
        });

        for(i = 1; i < 9; i++){
            var aux = '#aux'+ i;
            if (! logged_in){
                $(aux).flipswitch("option", "disabled", true);
            }
            else {
                $(aux).flipswitch();
            }
        }

    $('.myMenu ul li').hover(function() {
        $(this).children('ul').stop(true, false, true).slideToggle(300);
    });

    // draggable widgets

    $(function(){

        $('.drag').each(function(i, table){
            console.log(
                $(table).attr('id') + " " +
                $(table).position().top + " " +
                $(table).position().left
            );

        });

        $('.drag').draggable({
            handle: 'p.widget_handle',
            grid: [10, 1],
            scroll: false,
            opacity: 0.5,
            //helper: 'clone',
            cursor: "move",
            drag: function(){
                console.log($(this).position().top);
            },
            stop: function(){
                var top = $(this).position().top;
                var left = $(this).position().left;
                console.log($(this).attr('id') + " t: " + top + " l: " + left);
            }
        });
    });

    event_interval();
    display_env();
    aux_update();
    display_water();
    display_light();

    function event_interval(){
        $.get('/get_config/event_display_timer', function(interval){
            interval = interval * 1000;
            setInterval(display_env, interval);
        });
    };

    var temp_limit = -1;
    var humidity_limit = -1;

    $.get('/get_control/temp_limit', function(data){
        temp_limit = data;
    });
    $.get('/get_control/humidity_limit', function(data){
        humidity_limit = data;
    });

    function aux_update(){

        display_time();
        display_light();
        display_water();

        for(i = 1; i < 9; i++){
            var aux = 'aux'+ i;
            aux_state(aux);
        }
    }

    function aux_state(aux){
        $.get('/get_aux/' + aux, function(data){
            var json = $.parseJSON(data);

            if (parseInt(json.pin) == '-1'){
                return;
            }

            var ontxt;
            var offtxt;

            if (parseInt(json.override) == 1 && (aux == 'aux1' || aux == 'aux2')){
                ontxt = 'OVERRIDE';
                offtxt = 'OVERRIDE';
            }
            else {
                ontxt = 'ON';
                offtxt = 'OFF';
            }

            //var checked = parseInt(json.state);
            $('#'+ aux).on('change', function(){
                var checked = $('#'+aux).prop('checked');
                $.get('/set_aux/'+ aux +'/'+ checked, function(data){
                    var json = $.parseJSON(data);
                    if (json.error){
                        console.log(json.error);
                    }
                });
            });
        });
    }

    function display_time(){
         $.get('/time', function(data){
            $('#time').text(data);
        });
    }

    function display_light(){
        $.get('/light', function(data){
            var light = $.parseJSON(data);
            if (light.enable == "0"){
                $('.light').hide();
                return;
            }
            if (light.toggle == 'disabled'){
                $('#aux3').flipswitch('option', 'disable', true);
            }
            else {
                $('#aux3').flipswitch();
            }
            $('#light_on_hours').text(light.on_hours);
            $('#light_on_at').text(light.on_at);
        });
    }

    function display_water(){
        $.get('/water', function(data){
            var water = $.parseJSON(data);
            if (water.enable == "0"){
                $('.water').hide();
                return;
            }
        });
    }

    function display_graphs(){
        $.get('/graph_data', function(data){
            var graph_data = $.parseJSON(data);
            temp_graph(graph_data.temp);
            humidity_graph(graph_data.humidity);
        });
    }

    function display_env(){
        $.get('/fetch_env', function(data){
            var json = $.parseJSON(data);
            display_temp(json.temp);
            display_humidity(json.humidity);
        });

        display_graphs();
        aux_update();
    };

    function display_temp(temp){
        if (temp > temp_limit && temp_limit != -1){
            $('#temp').css('color', 'red');
        }
        else {
            $('#temp').css('color', 'green')
        }
        $('#temp').text(temp +' F');
    }

    function display_humidity(humidity){
        if (humidity < humidity_limit && humidity_limit != -1){
            $('#humidity').css('color', 'red');
        }
        else {
            $('#humidity').css('color', 'green')
        }
        $('#humidity').text(humidity +' %');
    }

    // temperature graph

    function temp_graph(data){
        $.plot($("#temp_chart"), [{
            data: data,
            threshold: {
                below: temp_limit,
                color: "green"
            }
            }],
            {
            grid: {
                hoverable: true,
                borderWidth: 1,
            },
            xaxis: {
                ticks: []
            },
            colors: ["red"]
        });
    }

    // humidity graph

    function humidity_graph(data){
        $.plot($("#humidity_chart"), [{
            data: data,
            threshold: {
                below: humidity_limit,
                color: "red"
            }
            }],
            {
            grid: {
                hoverable: true,
                borderWidth: 1,
            },
            xaxis: {
                ticks: []
            },
            colors: ["green"]
        });
    }
});
