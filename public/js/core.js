$(document).ready(function(){
    $('.myMenu ul li').hover(function() {
        $(this).children('ul').stop(true, false, true).slideToggle(300);
    });

    // draggable widgets

    $(function(){
        $('.drag').draggable()
    });

    $('#temp_widget').draggable({
        start: function(event, ui){
            var startpos = $(this).position();
            console.write(startpos);
            alert(startpos.left + " " + startpos.top);
        },
        stop: function(event, ui){
            var stoppos = $(this).position();
            alert(stoppos.left + " " + stoppos.top);
        },
    });

    event_interval();
    display_env();
    temp_graph();
    humidity_graph();
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

            $('#'+ aux).switchbutton({
                onText: ontxt,
                offText: offtxt,
                checked: parseInt(json.state),
                onChange: function(checked){
                    $.get('/set_aux/'+ aux +'/'+ checked, function(data){

                        // ...
                    });
                }
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
                $('#aux3').switchbutton('disable');
            }
            else {
                $('#aux3').switchbutton('enable');
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

    function display_env(){
        $.get('/fetch_env', function(data){
            var json = $.parseJSON(data);
            display_temp(json.temp);
            display_humidity(json.humidity);
        });

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

    function temp_graph(){
        var temp_ctx = $('#temp_chart')
        var temp_chart = new Chart(temp_ctx, {
            type: 'line',
            data: {
                labels: ["Mon", "Tues", "Wed", "Thurs", "Fri", "Sat", "Sun"],
                datasets: [{
                    pointBackgroundColor: [
                        'rgba(255, 0, 0, 10)',
                        'rgba(0, 128, 0, 2)',
                        'rgba(255, 206, 86, 0.2)',
                        'rgba(75, 192, 192, 0.2)',
                        'rgba(153, 102, 255, 0.2)',
                        'rgba(255, 159, 64, 0.2)',
                        'rgba(153, 102, 255, 0.2)'
                    ],
                    label: 'Temperature (F)',
                    data: [12, 19, 3, 5, 2, 3, 9],
                    fill: false,
                    /*
                    backgroundColor: [
                        'rgba(255, 0, 0, 1)',
                        'rgba(54, 162, 235, 0.2)',
                        'rgba(255, 206, 86, 0.2)',
                        'rgba(75, 192, 192, 0.2)',
                        'rgba(153, 102, 255, 0.2)',
                        'rgba(255, 159, 64, 0.2)',
                        'rgba(153, 102, 255, 0.2)'
                    ],
                    borderColor: [
                        'rgba(254, 0, 0, 1)',
                        'rgba(54, 162, 235, 1)',
                        'rgba(255, 206, 86, 1)',
                        'rgba(75, 192, 192, 1)',
                        'rgba(153, 102, 255, 1)',
                        'rgba(255, 159, 64, 1)',
                        'rgba(153, 102, 255, 1)'
                    ],
                    */
                    borderWidth: 1
                }]
            },
            options: {
                scales: {
                    xAxes: [{
                        display: false
                    }],
                    yAxes: [{
                        ticks: {
//                            max: 30,
//                            min: 20,
//                            stepSize 0.5,
                            beginAtZero:true
                        }
                    }]
                }
            }
        });
    }

    // humidity graph

    function humidity_graph(){
        var humidity_ctx = $('#humidity_chart')
        var humidity_chart = new Chart(humidity_ctx, {
            type: 'line',
            data: {
                labels: ["Mon", "Tues", "Wed", "Thurs", "Fri", "Sat", "Sun"],
                datasets: [{
                    label: 'Humidity %',
                    fill: false,
                    data: [12, 19, 3, 5, 2, 3, 9]
                }]
            },
            options: {
                scales: {
                    xAxes: [{
                        display: false
                    }],
                    yAxes: [{
                        ticks: {
                            beginAtZero:true
                        }
                    }]
                }
            }
        });
    }
});
