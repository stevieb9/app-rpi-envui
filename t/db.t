use strict;
use warnings;

BEGIN {
    use lib 't/';
    use TestBase;
    db_remove();
    db_create();
    config();
}

use App::RPi::EnvUI::API;
use App::RPi::EnvUI::DB;
use Data::Dumper;
use Test::More;

my $db = App::RPi::EnvUI::DB->new(testing => 1);

is ref $db, 'App::RPi::EnvUI::DB', "new() returns a proper object";

{ # auxs()

    my $auxs = $db->auxs;

    is ref $auxs, 'HASH', "auxs() returns a href";
    is keys %$auxs, 8, "auxs(): proper number of auxs returned";

    for (keys %$auxs) {
        like $_, qr/aux\d{1}/, "auxs() $_ has a 'auxN' name";
    }

    for (1..8){
        my $name = "aux$_";
        my $aux = $auxs->{$name};

        if ($name eq 'aux1' || $name eq 'aux2'){
            is $aux->{pin}, 0, "$name aux has proper pin default";
        }
        else {
            is $aux->{pin}, -1, "$name aux has proper pin default";
        }
        is $aux->{state}, 0, "$name has proper default state";
        is $aux->{override}, 0, "$name has proper default override";
        is $aux->{on_time}, 0, "$name has proper default on_time";
    }
}

{
    for (1..8){
        my $name = "aux$_";
        my $aux = $db->aux($name);
        is ref $aux, 'HASH', "aux() returns an href for $name";
        is keys %$aux, 6, "aux() $name has proper count keys";
    }
}

{ # config_control()

    my $api = App::RPi::EnvUI::API->new(
        testing => 1,
        config_file => 't/envui.json'
    );
    $api->_parse_config;

    my @directives = qw(
        temp_limit humidity_limit temp_aux_on_time humidity_aux_on_time
        temp_aux humidity_aux light_aux water1_aux water2_aux
    );

    my @values = qw(
        80 20 1800 1800 aux1 aux2 aux3 aux4 aux5
    );

    is @directives, @values, "directives match number of values";
    
    my $i = 0;

    for (@directives){
        my $value = $db->config_control($_);
        is $value, $values[$i], "control $_ has value $values[$i] by default";
        $i++;
    }
}

{ # config_core()

    my $api = App::RPi::EnvUI::API->new(
        testing => 1,
        config_file => 't/envui.json'
    );
    $api->_parse_config;

    my @directives = qw(
        event_fetch_timer event_action_timer event_display_timer
        sensor_pin testing time_zone
    );

    my @values = qw(
        15 3 4 0 0 local
    );

    my $i = 0;

    for (@directives){
        my $value = $db->config_core($_);
        is $value, $values[$i], "core $_ has value $values[$i] by default";
        $i++;
    }
};

db_remove();
unconfig();

done_testing();

