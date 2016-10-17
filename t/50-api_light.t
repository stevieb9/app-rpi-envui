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

{ # default state, and on time not yet reached

    # light should be off by default

    is
        $api->_config_light('on_since'),
        0,
        "on_since not set, hours not same: light on_since is zero";

    is
        $api->aux_state( $api->_config_control( 'light_aux' ) ),
        0,
        "light aux is currently in state off";

    my $now = DateTime->now(time_zone => $api->_config_core('time_zone'));

    my ($on_dt, $off_dt);
    $on_dt = $now->clone()->set_minute($now->minute);
    $on_dt->add(minutes => 2);
    $on_dt = light_on($on_dt);
    $off_dt = $api->light_off($on_dt);

    $api->action_light;

    # light should be off

    ok $api->_config_light('on_since') == 0, "light on_since is zero";

    is
        $api->aux_state( $api->_config_control( 'light_aux' ) ),
        0,
        "light on time not reached, light is off";
}

{ # on_since

    # light should be off for the test

    is
        $api->_config_light('on_since'),
        0,
        "light is off for the test";

    is
        $api->aux_state( $api->_config_control( 'light_aux' ) ),
        0,
        "light aux is currently in state off for the test";

    my $now = DateTime->now(time_zone => $api->_config_core('time_zone'));

    my ($on_dt, $off_dt);
    $on_dt = $now->clone()->set_minute($now->minute);
    $on_dt->subtract(minutes => 2);
    $on_dt = light_on($on_dt);
    $off_dt = $api->light_off($on_dt);

    $api->action_light;

    # light should be on

    ok $api->_config_light('on_since') > 0, "light on_since is non-zero";

    is
        $api->aux_state( $api->_config_control( 'light_aux' ) ),
        1,
        "light on time reached, light is on";


    $on_dt->subtract(hours => 12);
    $on_dt = light_on($on_dt);

     $api->action_light;

    # light should be off

    ok $api->_config_light('on_since') == 0, "light on_since zero";

    is
        $api->aux_state( $api->_config_control( 'light_aux' ) ),
        0,
        "light off time reached, light is off";
}

{ # on_hours == 0 and == 24

    my $aux = $api->_config_control('light_aux');

    # 24

    $db->update('light', 'value', 24, 'id', 'on_hours');
    $api->action_light;
    is $api->aux_state($aux), 1, "when on_hours is 24, light goes on";
    is $App::RPi::EnvUI::API::pm_sub->called, 1, "pin_mode() called";
    is $App::RPi::EnvUI::API::wp_sub->called, 1, "write_pin() called";

    $App::RPi::EnvUI::API::pm_sub->reset;
    $App::RPi::EnvUI::API::wp_sub->reset;

    is $App::RPi::EnvUI::API::pm_sub->called, 0, "pin_mode() reset";
    is $App::RPi::EnvUI::API::wp_sub->called, 0, "write_pin() reset";

    # 24 state on

    $db->update('light', 'value', 24, 'id', 'on_hours');
    $api->action_light;
    is $api->aux_state($aux), 1, "when on_hours is 24, light goes on";
    is $App::RPi::EnvUI::API::pm_sub->called, 0, "pin_mode() not called if 24 hrs and state";
    is $App::RPi::EnvUI::API::wp_sub->called, 0, "write_pin() not called if 24 hrs and state";

    $App::RPi::EnvUI::API::pm_sub->reset;
    $App::RPi::EnvUI::API::wp_sub->reset;

    is $App::RPi::EnvUI::API::pm_sub->called, 0, "pin_mode() reset";
    is $App::RPi::EnvUI::API::wp_sub->called, 0, "write_pin() reset";

    $db->update('light', 'value', 0, 'id', 'on_hours');
    $api->action_light;
    is $api->aux_state($aux), 0, "when on_hours is 0, light goes/stays off";
    is $App::RPi::EnvUI::API::pm_sub->called, 0, "pin_mode() *not* called";
    is $App::RPi::EnvUI::API::wp_sub->called, 1, "write_pin() *is* called";

    $db->update('light', 'value', 12, 'id', 'on_hours');
    is $api->_config_light('on_hours'), 12, "on_hours reset back to default ok";
}

sub light_on {
    my ($on_dt) = @_;
    my $time = $on_dt->hms;
    $time =~ s/:\d+$//;
    $db->update( 'light', 'value', $time, 'id', 'on_at' );

    return $api->light_on;
}

unconfig();
db_remove();
done_testing();

