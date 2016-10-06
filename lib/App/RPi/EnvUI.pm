package App::RPi::EnvUI;

use App::RPi::EnvUI::API;
use Data::Dumper;
use Dancer2;
use Dancer2::Plugin::Database;
use Mock::Sub no_warnings => 1;

our $VERSION = '0.22';
    # if testing the webapp portion, we need to mock out some stuff

        my $mock = Mock::Sub->new;

        my $temp_sub = $mock->mock(
            'RPi::DHT11::temp',
            return_value => 80
        );

        my $hum_sub = $mock->mock(
            'RPi::DHT11::humidity',
            return_value => 20
        );

        my $wp_sub = $mock->mock(
            'App::RPi::EnvUI::API::write_pin',
            return_value => 'ok'
        );

my $api = App::RPi::EnvUI::API->new;

$api->_reset();
$api->_config_light();
$api->env($api->read_sensor);
$api->events;

get '/' => sub {
    # return template 'main';
    return template 'test';
};

get '/light' => sub {
    return to_json $api->_config_light();
};

get '/water' => sub {
    return to_json $api->_config_water();
};

get '/get_config/:want' => sub {
    my $want = params->{want};
    my $value = $api->_config_core($want);
    return $value;
};

get '/get_control/:want' => sub {
    my $want = params->{want};
    my $value = $api->_config_control($want);
    return $value;
};

get '/get_aux/:aux' => sub {
    my $aux_id = params->{aux};
    $api->switch($aux_id);
    return to_json $api->aux($aux_id);
};

get '/set_aux/:aux/:state' => sub {
    my $aux_id = params->{aux};

    my $state = $api->_bool(params->{state});
    $state = $api->aux_state($aux_id, $state);

    my $override = $api->aux_override($aux_id) ? 0 : 1;
    $override = $api->aux_override($aux_id, $override);

    $api->switch($aux_id);

    return to_json {
        aux => $aux_id,
        state => $state,
    };
};

get '/fetch_env' => sub {
    my $data = $api->env();
    return to_json {
        temp => $data->{temp},
        humidity => $data->{humidity}
    };
};

true;
__END__

=head1 NAME

App::RPi::EnvUI - One-page asynchronous grow room environment control web
application

=for html
<a href="http://travis-ci.org/stevieb9/app-rpi-envui"><img src="https://secure.travis-ci.org/stevieb9/app-rpi-envui.png"/></a>
<a href='https://coveralls.io/github/stevieb9/app-rpi-envui?branch=master'><img src='https://coveralls.io/repos/stevieb9/app-rpi-envui/badge.svg?branch=master&service=github' alt='Coverage Status' /></a>

=head1 SYNOPSIS

    cd ~/envui
    sudo plackup bin/app.pl

Now direct your browser at your Pi, on port 3000:

    http://raspberry.pi:3000

=head1 DESCRIPTION

This distribution is alpha. It does not install the same way most CPAN modules
install, and has some significant requirements Most specifically, the
L<wiringPi|http://wiringpi.com> libraries, and the fact it can only run on a
Raspberry Pi (except for unit testing).

When installed, it'll install all of the relevant information in a directory
named C<envui> in your home directory.

Test coverage is only about 50%, and there's really no documentation as of yet.

This is my first web app in many, many years, so the technologies (jQuery,
L<Dancer2> etc) are brand new to me, so as I go, I'll be refactoring heavily as
I continue to learn.

=head1 WHAT IT DOES

Reads temperature and humidity data via a hygrometer sensor through the
L<RPi::DHT11> distribution.

It then allows, through a one-page asynchronous web UI to turn on and off
120/240v devices through buttons, timers and reached threshold limits.

For example. We have a max temperature limit of 80F. We assign an auxillary
(GPIO pin) that is connected to a relay to a 120v exhaust fan. Through the
configuration file, we load the temp limit, and if the temp goes above it, we
enable the fan via the GPIO pin.

To prevent the fan from going on/off repeatedly if the temp hovers at the limit,
a minimum "on time" is also set, so by default, if the fan turns on, it'll stay
on for 30 minutes, no matter if the temp drops back below the limit.

Each auxillary has a manual override switch in the UI, and if overridden in the
UI, it'll remain in the state you set.

We also include a grow light scheduler, so that you can connect your light, set
the schedule, and we'll manage it. The light has an override switch in the UI,
but that can be disabled to prevent any accidents.

...manages auto-feeding too, but that's not any where near complete yet.


=head1 AUTHOR

Steve Bertrand, E<lt>steveb@cpan.org<gt>

=head1 LICENSE AND COPYRIGHT

Copyright 2016 Steve Bertrand.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See L<http://dev.perl.org/licenses/> for more information.

