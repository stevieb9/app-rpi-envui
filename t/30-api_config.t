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

{ # config_control()

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
        my $value = $api->_config_control($_);
        is $value, $values[$i], "control $_ has value $values[$i] by default";
        $i++;
    }
}

{ # config_core()

    my @directives = qw(
        event_fetch_timer event_action_timer event_display_timer
        sensor_pin testing time_zone
        );

    my @values = qw(
        15 3 4 -1 0 America/Edmonton
        );

    my $i = 0;

    for (@directives){
        my $value = $api->_config_core($_);
        is $value, $values[$i], "core $_ has value $values[$i] by default";
        $i++;
    }
}

{ # config_light()

    my @directives = qw(
        on_at on_in on_hours on_since toggle enable
        );

    my @values = qw(
        18:00 00:00 12 0 disabled 0
        );

    is @directives, @values, "config_light() test is set up equally";

    my $c = $api->_config_light;

    print Dumper $c;

    is ref $c, 'HASH', "_config_light() returns a hashref w/o params";
    is keys %$c, 6, "...and has proper count of keys";

    for my $k (keys %$c){
        my $ok = grep {$_ eq $k} @directives;
        is $ok, 1, "$k is a directive";
    }

    for my $d (@directives){
        is exists $c->{$d}, 1, "$d directive exists in conf";
    }

    my $i = 0;

    for (@directives){
        my $value = $api->_config_light($_);
        if ($_ eq 'on_in'){
            isnt
                $value,
                '00:00',
                "_config_light() on_in value is properly set from the default";
            $i++;
            next;
        }
        is $value, $values[$i], "light $_ has value $values[$i] by default";
        $i++;
    }
}
{ # config_water()

    my @directives = qw(
        enable
        );

    my @values = qw(
        0
        );

    is @directives, @values, "config_water() test is set up equally";

    my $conf = $api->_config_water;

    is ref $conf, 'HASH', "config_water() is an href with no params";

    for my $k (keys %$conf){
        my $ok = grep {$_ eq $k} @directives;
        is $ok, 1, "$k is a directive";
    }

    for my $d (@directives){
        is exists $conf->{$d}, 1, "$d directive exists in conf";
    }

    my $i = 0;

    for (@directives){
        my $value = $api->_config_water($_);
        is $value, $values[$i], "water $_ has value $values[$i] by default";
        $i++;
    }
}

unconfig();
db_remove();
done_testing();

