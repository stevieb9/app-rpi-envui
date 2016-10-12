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
use Hook::Output::Tiny;
use Test::More;

#FIXME: add tests to test overrides for hum and temp

my $api = App::RPi::EnvUI::API->new(
    testing => 1,
    config_file => 't/envui.json'
);

is ref $api, 'App::RPi::EnvUI::API', "new() returns a proper object";
is $api->{testing}, 1, "testing param to new() ok";

{ # read_sensor()

    my @env = $api->read_sensor;

    is @env, 2, "mocked read_sensor() returns proper count of values";
    is $env[0], 80, "first elem of return ok (temp)";
    is $env[1], 20, "second elem of return ok (humidity)";

    # sensor not defined

    my $sensor = $api->{sensor};
    $api->{sensor} = undef;

    my $ok = eval { $api->read_sensor; 1; };

    is $ok, undef, "without a sensor object, we die";
    like $@, qr/is not defined/, "...and coughs the proper error message";

    $api->{sensor} = $sensor;

    $ok = eval { $api->read_sensor; 1; };

    is $ok, 1, "re-assigned the sensor object ok";

}

{ # bool()

    my $ok = eval { $api->_bool; 1; };
    is $ok, undef, "bool() dies if a param isn't sent in";
    like $@, qr/'true' or 'false'/, "...and the error is correct";

    is $api->_bool('true'), 1, "bool('true') ok";
    is $api->_bool('false'), 0, "bool('false') ok";

}

{ # _reset()

    for (1..8){
        my $id = "aux$_";
        $api->aux_time($id, 99);
        my $time = $api->aux_time($id);
        ok $time > 0, "_reset() test setup ok for $id";
    }

    $api->_reset;

    for (1..8){
        my $id = "aux$_";
        my $time = $api->aux_time($id);
        is $time, 0, "_reset() sets $id back to 0 on_time";
    }
}

unconfig();
db_remove();
done_testing();

