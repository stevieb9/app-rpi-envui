$(document).ready(function(){
        $('#aux1').switchButton({
            labels_placement: "right",
        });

        $('#aux1').on('change', function(){
            if ($('#aux1').prop('checked')){
                $('.switch-button-background').css("background", "green");
            }
            else {
                $('.switch-button-background').css("background", "#c0c0c0");
            }
        })
});
