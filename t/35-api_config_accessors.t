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

{ # env_temp_aux
    is $api->env_temp_aux, 'aux1', "aux1 is the temp aux by default";
    $db->update('control', 'value', 'aux9', 'id', 'temp_aux');
    is $api->env_temp_aux, 'aux9', "setting the value works ok";
    $db->update('control', 'value', 'aux1', 'id', 'temp_aux');
    is $api->env_temp_aux, 'aux1', "...and works ok going back too";
}

{ # env_temp_humidity
    is $api->env_humidity_aux, 'aux2', "aux2 is the humidity aux by default";
    $db->update('control', 'value', 'aux9', 'id', 'humidity_aux');
    is $api->env_humidity_aux, 'aux9', "setting the value works ok";
    $db->update('control', 'value', 'aux2', 'id', 'humidity_aux');
    is $api->env_humidity_aux, 'aux2', "...and works ok going back too";
}

unconfig();
db_remove();
done_testing();
