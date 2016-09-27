$(document).ready(function(){

//    var host = 'http://192.168.1.147:5000';
    var host = 'http://10.0.48.1:5000';
    display_env();
    setInterval(display_env, 4000);

    $(function(){
        aux_update();
    });

    // temperature graph

    var temp_ctx = $('#temp_chart')
    var temp_chart = new Chart(temp_ctx, {
        type: 'line',
        data: {
            labels: ["Red", "Blue", "Yellow", "Green", "Purple", "Orange"],
            datasets: [{
                label: '# of Votes',
                data: [12, 19, 3, 5, 2, 3]
                /*
                backgroundColor: [
                    'rgba(255, 99, 132, 0.2)',
                    'rgba(54, 162, 235, 0.2)',
                    'rgba(255, 206, 86, 0.2)',
                    'rgba(75, 192, 192, 0.2)',
                    'rgba(153, 102, 255, 0.2)',
                    'rgba(255, 159, 64, 0.2)'
                ],
                borderColor: [
                    'rgba(255,99,132,1)',
                    'rgba(54, 162, 235, 1)',
                    'rgba(255, 206, 86, 1)',
                    'rgba(75, 192, 192, 1)',
                    'rgba(153, 102, 255, 1)',
                    'rgba(255, 159, 64, 1)'
                ],
                borderWidth: 1
            */
            }]
        },
        options: {
            scales: {
                yAxes: [{
                    ticks: {
                        beginAtZero:true
                    }
                }]
            }
        }
    });

    // humidity graph

    var humidity_ctx = $('#humidity_chart')
    var humidity_chart = new Chart(humidity_ctx, {
        type: 'line',
        data: {
            labels: ["Red", "Blue", "Yellow", "Green", "Purple", "Orange"],
            datasets: [{
                label: '# of Votes',
                data: [12, 19, 3, 5, 2, 3]
            }]
        },
        options: {
            scales: {
                yAxes: [{
                    ticks: {
                        beginAtZero:true
                    }
                }]
            }
        }
    });

    function aux_update(){
        for(i = 1; i < 5; i++){
            var aux = 'aux'+ i;
            aux_state(aux);
        }
    }
    function aux_state(aux){
        $.get(host +'/get_aux/' + aux, function(data){
            var json = $.parseJSON(data);
            if (parseInt(json.pin) == '-1'){
                $('.opt_'+aux).hide();
                //return;
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
                    $.get(host +'/set_aux/'+ aux +'/'+ checked, function(data){

                        // ...
                    });
                }
            });
        });
    }

    function display_env(){
        $.get(host +'/fetch_env', function(data){
            var json = $.parseJSON(data);
            display_temp(json.temp);
            display_humidity(json.humidity);
        });

        aux_update();
    };

    function display_temp(temp){
        if (temp > 78){
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
