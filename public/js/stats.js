"use strict";

var temp_limit = -1;
var humidity_limit = -1;

$(document).on('pagebeforeshow', "#stats.tt", function(){

    // authentication

    var logged_in;

    $.ajax({
        async: false,
        type: 'GET',
        url: '/logged_in',
        success: function(data){
            var json = $.parseJSON(data);
            logged_in = json.status;
        }
    });

    $('#auth').addClass('a');

    if (logged_in){
        $('#auth').text('Logout');
        $('#auth').attr('href', '/logout');
    }
    else {
        $('#auth').text('Login');
        $('#auth').attr('href', '/login');
    }

    // aux buttons

    for (var i = 1; i < 3; i++){
        var aux = 'aux' + i;

        // hide the auxs if necessary

        $.ajax({
            async: false,
            type: 'GET',
            url: '/get_aux/' + aux,
            success: function(data){
                var json = $.parseJSON(data);
                if (parseInt(json.pin) == '-1'){
                    // $('#'+aux+'_widget').hide();
                }
            }
        });
    }

    // main menu

    $('.myMenu ul li').hover(function() {
        $(this).children('ul').stop(true, false, true).slideToggle(300);
    });

    // draggable widgets

    var s_positions = localStorage.positions || "{}";
    var positions = $.parseJSON(s_positions);

    $.each(positions, function (id, pos){
        $('#'+ id).css(pos);
    })

    $('.drag').draggable({
        handle: 'p.widget_handle',
        grid: [10, 1],
        scroll: false,
        opacity: 0.5,
        cursor: "move",
        drag: function(){

        },
        stop: function(event, ui){
            positions[this.id] = ui.position;
            console.log(positions);
            localStorage.positions = JSON.stringify(positions)
        }
    });

    // set variables

    $.get('/get_control/temp_limit', function(data){
        temp_limit = data;
    });
    $.get('/get_control/humidity_limit', function(data){
        humidity_limit = data;
    });

    // initialization

    display_interval();
    display_environment();
});

// external functions

// events

function display_interval(){
    $.get('/get_config/event_display_timer', function(interval){
        interval = interval * 1000;
        setInterval(display_environment, interval);
    });
}

// core functions

function show_time(){
    console.log('time');
    $.get('/time', function(data){
        $('#time').text(data);
    });
}

function display_graphs(){
    $.get('/graph_data', function(data){
        var graph_data = $.parseJSON(data);
        create_graphs(graph_data);
    });
}

function display_environment(){
    $.get('/fetch_env', function(data){
        var json = $.parseJSON(data);
        show_temp(json.temp);
        show_humidity(json.humidity);
    });

    show_time();
    display_graphs();
}

function show_temp(temp){
    if (temp > temp_limit && temp_limit != -1){
        $('#temp').css('color', 'red');
    }
    else {
        $('#temp').css('color', 'green');
    }
    $('#temp').text(temp +' F');
}

function show_humidity(humidity){
    if (humidity < humidity_limit && humidity_limit != -1){
        $('#humidity').css('color', 'red');
    }
    else {
        $('#humidity').css('color', 'green');
    }
    $('#humidity').text(humidity +' %');
}

//graphs

function create_graphs(data){
    var info = {
        temp: {
            above_colour: 'red',
            below_colour: 'green',
            name: '#temp_chart',
            limit: temp_limit
        },
        humidity: {
            above_colour: 'green',
            below_colour: 'red',
            name: '#humidity_chart',
            limit: humidity_limit
        }
    };

    var graphs = ['temp', 'humidity'];

    $.each(graphs, function(index, graph){
        $.plot($(info[graph].name), [
            {
                data: data[graph],
                threshold: {
                    below: info[graph].limit,
                    color: info[graph].below_colour
                }
            }],
            {
                grid: {
                    hoverable: true,
                    borderWidth: 1
                },
                xaxis: {
                    ticks: []
                },
                    colors: [ info[graph].above_colour ]
                }
            );
        });

    info = null;
    graphs = null;
}
