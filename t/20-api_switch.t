use strict;
use warnings;

BEGIN {
    use lib 't/';
    use TestBase;
    config();
    db_create();
}

use App::RPi::EnvUI::API;
use App::RPi::EnvUI::DB;
use Data::Dumper;
use Test::More;

#FIXME: add tests to test overrides for hum and temp

my $api = App::RPi::EnvUI::API->new(
    testing => 1,
    config_file => 't/envui.json'
);

my $db = App::RPi::EnvUI::DB->new(testing => 1);

is ref $api, 'App::RPi::EnvUI::API', "new() returns a proper object";
is $api->{testing}, 1, "testing param to new() ok";

{ # read_sensor()
    my @env = $api->read_sensor;

    is @env, 2, "mocked read_sensor() returns proper count of values";
    is $env[0], 80, "first elem of return ok (temp)";
    is $env[1], 20, "second elem of return ok (humidity)";
}

{ # switch()

    for (1..8){
        my $id = "aux$_";
        $api->aux_pin($id, 0);
        my $ret = $api->switch($id);

        is $api->aux_pin($id), 0, "aux $id pin set to 0";

        is $App::RPi::EnvUI::API::wp_sub->called, 1, "switch(): wp called if pin isn't -1";
        is $ret, 'ok', "switch(): if pin isn't -1, we call write_pin(), $id";

        $api->aux_pin($id, -1);

        is $api->aux_pin($id), -1, "successfully reset $id pin to -1";
    }

    $App::RPi::EnvUI::API::wp_sub->reset;

    for (1..8){
        my $id = "aux$_";
        my $ret = $api->switch($id);

        is
            $App::RPi::EnvUI::API::wp_sub->called,
            0,
            "switch(): write_pin() not called if pin state is -1: $id";
        is $ret, '', "switch(): if pin is -1, we don't call write_pin(), $id";
    }
}

unconfig();
db_remove();
done_testing();
