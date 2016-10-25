package App::RPi::EnvUI;

use App::RPi::EnvUI::API;
use App::RPi::EnvUI::Auth;
use Data::Dumper;
use Dancer2;
use Dancer2::Plugin::Auth::Extensible;
use Dancer2::Core::Request;
#use Dancer2::Session::JSON;
use Mock::Sub no_warnings => 1;
use POSIX qw(tzset);

our $VERSION = '0.26';

my $db = App::RPi::EnvUI::DB->new;
my $api = App::RPi::EnvUI::API->new(db => $db);

$ENV{TZ} = $api->_config_core('time_zone');
tzset();

my $log = $api->log()->child('webapp');

$api->_config_light();

#
# fetch routes
#

get '/' => sub {
        my $log = $log->child('/');
        $log->_7("entered");

        # return template 'main';
        return template 'test', {requester => request->address};
        # return template 'switch';
        # return template 'switch2';
        # return template 'menu';
        # return template 'drag';
        # return template 'flip';
        # return template 'graph';
        # return template 'graph_live';
    };

# fetch graph code

get '/graph_data' => sub {
        return to_json $api->graph_data;
    };

post '/login' => sub {
        my $user = params->{username};
        my $pass = params->{password};

        my ($success, $realm) = authenticate_user($user, $pass);

        if ($success){
            session logged_in_user => $user;
            session logged_in_user_realm => $realm;
            redirect '/';
        }
    };

any '/logout' => sub {
        app->destroy_session;
    };

get '/logged_in' => sub {
        if (session 'logged_in_user'){
            return to_json { status => 1 };
        }
        return to_json {status => 0};
    };

get '/time' => sub {
        return join ':', (localtime)[2, 1];
    };

get '/stats' => sub {
        return template 'stats';
    };

get '/light' => sub {
        my $log = $log->child('/light');
        $log->_7("entered");
        return to_json $api->_config_light();
    };
get '/water' => sub {
        my $log = $log->child('/water');
        $log->_7("entered");
        return to_json $api->_config_water();
    };
get '/get_config/:want' => sub {
        my $want = params->{want};

        my $log = $log->child('/get_config');

        my $value = $api->_config_core($want);

        $log->_5("param: $want, value: $value");

        return $value;
    };
get '/get_control/:want' => sub {
        my $want = params->{want};

        my $log = $log->child('/get_control');

        my $value = $api->_config_control($want);

        $log->_5("param: $want, value: $value");

        return $value;
    };
get '/get_aux/:aux' => sub {
        my $aux_id = params->{aux};

        my $log = $log->child('/get_aux');
        $log->_5("fetching aux object for $aux_id");

        $api->switch($aux_id);

        return to_json $api->aux($aux_id);
    };
get '/fetch_env' => sub {
        my $log = $log->child('/fetch_env');

        my $data = $api->env();

        $log->_5("temp: $data->{temp}, humidity: $data->{humidity}");
        return to_json {
            temp => $data->{temp},
            humidity => $data->{humidity}
        };
    };

#
# set routes
#

get '/set_aux/:aux/:state' => sub {

        if ((request->address ne '127.0.0.1' && ! session 'logged_in_user') || $ENV{UNIT_TEST}){
            return to_json {
                    error => 'unauthorized request. You must be logged in'
            };
        }

        my $aux_id = params->{aux};
        my $state = $api->_bool(params->{state});

        my $log = $log->child('/fetch_env');
        $log->_5("aux_id: $aux_id, state: $state");

        $state = $api->aux_state($aux_id, $state);

        $log->_6("$aux_id updated state: $state");

        my $override = $api->aux_override($aux_id) ? 0 : 1;
        $log->_6("$aux_id override: $override");

        $override = $api->aux_override($aux_id, $override);
        $log->_6("$aux_id new override: $override");

        $api->switch($aux_id);

        return to_json {
            aux => $aux_id,
            state => $state,
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

A self-contained web application that runs on a Raspberry Pi and monitors and
manages an indoor grow room environment, with an API that can be used external
to the web app itself.

***NOTE*** This distribution is still in heavy development. It will unit test
on any *nix PC, but at this time, it will only run correctly on a Raspberry Pi
with L<wiringPi|http://wiringpi.com> installed. We also require C<sudo> to run
the webapp, due to limitations in other software I rely upon, but I've got fixes
in the works to eliminate the C<sudo> requirement.

This distribution reads environmental sensors, turns on/off devices based on
specific thresholds, contains an adjustable grow light timer, as well as
feeding timers.

The software connects to Raspberry Pi GPIO pins for each C<"auxillary">, and at
specific times or thresholds, turns on and or off the 120/240v devices that
you've relayed to that voltage (if you choose to use this functionality).

Whether or not you connect/use the automation functionality, the web UI is a
one-page app that relies on jQuery/Javascript to pull updates from the server,
push changes to the server, and display up-to-date live information relating to
all functionality.

Buttons are present to manually override devices (turn on/off) outside of their
schedule or whether they've hit thresholds or not. Devices that have been
overridden through the web UI will not be triggered by automation until the
override is lifted.

The current temperature and humidity is prominently displayed as are all of the
other features/statistics.

This is pretty much a singleton application, meaning that all web browsers open
to the app's UI page will render updates at the same time, regardless if another
browser or the automation makes any changes.

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

=head1 HOW IT WORKS

Upon installation of this module, a new directory C<envui> will be created in
your home directory. All of the necessary pieces of code required for this web
app to run are copied into that directory. You simply change into that
directory, and run C<sudo plackup bin/app.pl>, then point your browser to
C<http://raspberry.pi:3000>.

=head1 ROUTES

=head2 /

Use: Browser

Returns the pre-populated template to the UI. Once the browser loads it, it does
not have to be reloaded again.

Return: L<Template::Toolkit> template in HTML

=head2 /light

Use: Internal

Returns a JSON string containing the configuration for the C<light> section of
the page.

Return: JSON

=head2 /water

Use: Internal

Returns a JSON string containing the configuration for the C<water> (feeding)
section of the page.

Return: JSON

=head2 /get_config/:want

Use: Internal

Fetches and returns a value from the C<core> section of a configuration file.

Parameters:

    :want

The C<core> configuration directive to retrieve the value for.

Return: String. The value for the specified directive.

=head2 /get_control/:want

Use: Internal

Fetches and returns a value from the C<control> section of a configuration file.

Parameters:

    :want

The C<control> configuration directive to retrieve the value for.

Return: String. The value for the specified directive.

=head2 /get_aux/:aux

Use: Internal

Fetches an auxillary channel's information, and on the way through, makes an
L<App::RPi::EnvUI::API> C<switch()> call, which turns on/off the auxillary
channel if necessary.

Parameters:

    :aux

Mandatory, String. The string name of the auxillary channel to fetch
(eg: C<aux1>).

Return: JSON. The JSON stringified version of an auxillary channel hashref.

=head2 /fetch_env

Use: Internal

Fetches the most recent enviromnent details from the database (temperature and
humidity). Takes no parameters.

Return: JSON. A JSON string in the form C<{"temp": "Int", "humidity": "Int"}>

=head2 /set_aux/:aux/:state

Use: Internal

Sets the state of an auxillary channel, when an on-change event occurs to a
button that is associated with an auxillary.

Parameters:

    :aux

Mandatory: String. The string name of the auxillary channel to change state on
(eg: C<aux1>).

    :state

Mandatory: Bool. The state of the auxillary after the button change.

Return: JSON. Returns the current state of the auxillary in the format
C<>{"aux": "aux_name", "state": "bool"}>.

=head1 AUTHOR

Steve Bertrand, E<lt>steveb@cpan.org<gt>

=head1 LICENSE AND COPYRIGHT

Copyright 2016 Steve Bertrand.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See L<http://dev.perl.org/licenses/> for more information.

