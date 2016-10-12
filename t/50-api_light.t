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

my $api = App::RPi::EnvUI::API->new(
    testing => 1,
    config_file => 't/envui.json'
);

my $db = App::RPi::EnvUI::DB->new(testing => 1);

{ # on_since, not hour same

    my $light = $api->_config_light;

    # light should be off

    is
        $api->_config_light('on_since'),
        0,
        "on_since not set, hours not same: light on_since is zero";

    is
        $api->aux_state( $api->_config_control( 'light_aux' ) ),
        0,
        "light aux is currently in state off";

    my $now = DateTime->now( time_zone => $api->_config_core( 'time_zone' ) );
    my ($now_hr, $now_min) = (split /:/, $now->hms)[0, 1];
    my ($on_hr, $on_min) = split /:/, $light->{on_at};

    $on_hr = $now_hr + 1;
    $on_min = $now_min == 0
        ? 0
        : $now_min - 1;

    my $on_time = "$on_hr:$on_min";
    $db->update( 'light', 'value', $on_time, 'id', 'on_at' );

    $api->action_light;

    # light should be off

    ok $api->_config_light( 'on_since' ) == 0, "light on_since is zero";

    is
        $api->aux_state( $api->_config_control( 'light_aux' ) ),
        0,
        "with on_since set and hours not matching, light doesn't turn on";
}

{ # on_since, hour same, mins not greater

    my $light = $api->_config_light;

    # light should be off

    is
        $api->_config_light('on_since'),
        0,
        "on_since, hour same, mins not same: light on_since is zero";

    is
        $api->aux_state( $api->_config_control( 'light_aux' ) ),
        0,
        "light aux is currently in state off";

    my $now = DateTime->now( time_zone => $api->_config_core( 'time_zone' ) );
    my ($now_hr, $now_min) = (split /:/, $now->hms)[0, 1];
    my ($on_hr, $on_min) = split /:/, $light->{on_at};

    $on_hr = $now_hr;
    $on_min = 59;

    my $on_time = "$on_hr:$on_min";
    $db->update( 'light', 'value', $on_time, 'id', 'on_at' );

    $api->action_light;

    # light should be off

    ok $api->_config_light('on_since') == 0, "light on_since is zero";

    is
        $api->aux_state( $api->_config_control( 'light_aux' ) ),
        0,
        "with on_since set, hours same but mins not gt, light doesn't turn on";
}
unconfig();
db_remove();
done_testing();

