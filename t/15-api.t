use strict;
use warnings;

BEGIN {
    use lib 't/';
    use TestBase;
    config();
}

use App::RPi::EnvUI::API;
use App::RPi::EnvUI::DB;
use Data::Dumper;
use Test::More;

my $db = App::RPi::EnvUI::DB->new(testing => 1);

my $api = App::RPi::EnvUI::API->new(
    testing => 1,
    config_file => 't/envui.json'
);

is ref $api, 'App::RPi::EnvUI::API', "new() returns a proper object";
is $api->{testing}, 1, "testing param to new() ok";
is $api->{config_file}, 't/envui.json', "config_file param to new() ok";

$api->_parse_config;

{ # read_sensor()
    my @env = $api->read_sensor;

    is @env, 2, "mocked read_sensor() returns proper count of values";
    is $env[0], 80, "first elem of return ok (temp)";
    is $env[1], 20, "second elem of return ok (humidity)";
}

{ # aux()

    for (1..8){
        my $name = "aux$_";
        my $aux = $api->aux($name);

        is ref $aux, 'HASH', "aux() returns $name as an href";
        is keys %$aux, 6, "$name has proper key count";

        for (qw(id desc pin state override on_time)){
            is exists $aux->{$_}, 1, "$name has directive $_";
        }
    }

    my $aux = $api->aux('aux9');
    is $aux, undef, "only 8 auxs available";

    $aux = $api->aux('aux0');
    is $aux, undef, "aux0 doesn't exist";
}
{ # auxs()

    my $db_auxs = $db->auxs;
    my $api_auxs = $api->auxs;

    is keys %$api_auxs, 8, "eight auxs() total from auxs()";

    for my $db_k (keys %$db_auxs) {
        for (keys %{ $db_auxs->{$db_k} }) {
            is $db_auxs->{$db_k}{$_}, $api_auxs->{$db_k}{$_},
                "db and api return the same auxs() ($db_k => $_)";
        }
    }
}

unconfig();

done_testing();

