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
use App::RPi::EnvUI::Event;
use Data::Dumper;
use Mock::Sub no_warnings => 1;
use Test::More;

#FIXME: add tests to test overrides for hum and temp

# mock out some subs that rely on external C libraries

my $mock = Mock::Sub->new;

my $temp_sub = $mock->mock(
    'RPi::DHT11::temp',
    return_value => 99
);

my $hum_sub = $mock->mock(
    'RPi::DHT11::humidity',
    return_value => 99
);

my $wp_sub = $mock->mock(
    'App::RPi::EnvUI::API::write_pin',
    return_value => 'ok'
);

my $api = App::RPi::EnvUI::API->new(
    testing => 2,
    config_file => 't/envui.json'
);

my $db = App::RPi::EnvUI::DB->new(testing => 2);
my $evt = App::RPi::EnvUI::Event->new;

is ref $evt, 'App::RPi::EnvUI::Event', "new() returns a proper object";
is $api->{testing}, 2, "testing param to new() ok";

$api->_parse_config;

{ # read_sensor()
    my @env = $api->read_sensor;

    is @env, 2, "mocked read_sensor() returns proper count of values";
    is $env[0], 99, "first elem of return ok (temp)";
    is $env[1], 99, "second elem of return ok (humidity)";
}

{ # env_to_db()

    my $event = $evt->env_to_db($api);

    $db->update('core', 'value', 1, 'id', 'event_fetch_timer');

    my $c = $api->_config_core('event_fetch_timer');

    $event->start;
    sleep 4;
    $event->stop;

    my @env = $api->env;

    print Dumper \@env;
}
unconfig();
db_remove();
done_testing();

