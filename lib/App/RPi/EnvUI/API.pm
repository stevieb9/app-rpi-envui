package App::RPi::EnvUI::API;

use App::RPi::EnvUI::DB;
use App::RPi::EnvUI::Event;
use Carp qw(confess);
use Data::Dumper;
use DateTime;
use JSON::XS;
use Logging::Simple;
use Mock::Sub no_warnings => 1;
use RPi::WiringPi::Constant qw(:all);

our $VERSION = '0.24';

# mocked sub handles for when we're in testing mode

my ($temp_sub, $hum_sub, $wp_sub, $pm_sub);

# class variables

my $master_log;
my $log;
my $sensor;

sub new {
    my $self = bless {}, shift;
    %$self = @_;

    $self->_log;
    $self->_config;
    $self->_init;

    $log->_6("using $self->{config_file} as the config file");

    $self->_parse_config($self->{config_file});

    $log->_7("successfully parsed the config file");

    $self->events if ! $self->{testing};

    return $self;
}
sub events {
    my $self = shift;

    my $log = $self->log('events');

    my $events = App::RPi::EnvUI::Event->new($self->{testing});

    $self->{events}{env_to_db} = $events->env_to_db;
    $self->{events}{env_action} = $events->env_action;

    $self->{events}{env_to_db}->start;
    $self->{events}{env_action}->start;

    $log->_7("events successfully started");
}
sub read_sensor {
    my $self = shift;

    my $log = $log->child('read_sensor');

    if (! defined $self->{sensor}){
        confess "\$self->{sensor} is not defined";
    }
    my $temp = $self->{sensor}->temp('f');
    my $hum = $self->{sensor}->humidity;

    $log->_5("temp: $temp, humidity: $hum");

    return ($temp, $hum);
}
sub switch {
    my ($self, $aux_id) = @_;

    my $log = $log->child('switch');

    my $state = $self->aux_state($aux_id);
    my $pin = $self->aux_pin($aux_id);

    if ($pin != -1){
        if ($state){
            $log->_5("set $pin state to HIGH");
            pin_mode($pin, OUTPUT);
            write_pin($pin, HIGH);
        }
        else {
            $log->_5("set $pin state to LOW");
            pin_mode($pin, OUTPUT);
            write_pin($pin, LOW);
        }
    }
}
sub action_light {
    my ($self) = @_;

    my $log = $log->child('action_light');

    my $now = DateTime->now(
        time_zone => $self->_config_core('time_zone')
    );

    my ($on_hour, $on_min) = split /:/, $self->_config_light('on_at');

    $log->_7("on_hour: $on_hour, on_min: $on_min");

    my $timer = $now->clone;
    $timer->set(hour => $on_hour);
    $timer->set(minute => $on_min);

    my $hour_same = $now->hour == $timer->hour;
    my $min_geq = $now->minute >= $timer->minute;

    my $on_since = $self->_config_light('on_since');

    if (! $on_since  && $hour_same && $min_geq){
        $self->{db}->update('light', 'value', time(), 'id', 'on_since');
        $self->aux_state($self->_config_control('light_aux'), ON);
        pin_mode($self->_config_control('light_aux'),  OUTPUT);
        write_pin($self->aux_pin($self->_config_control('light_aux')), HIGH);
    }

    if ($on_since) {
        my $on_hours = $self->_config_light( 'on_hours' );
        my $on_secs = $on_hours * 60 * 60;

        my $t = time();
        my $diff = $t - $on_since;

        if ($diff > $on_secs) {
            $self->{db}->update( 'light', 'value', 0, 'id', 'on_since' );
            $self->aux_state( $self->_config_control( 'light_aux' ), OFF );
            pin_mode($self->_config_control('light_aux'),  OUTPUT);
            write_pin($self->aux_pin($self->_config_control('light_aux')), LOW);
        }
    }
}
sub action_humidity {
    my $self = shift;
    my ($aux_id, $humidity) = @_;

    my $log = $log->child('action_humidity');
    $log->_5("aux: $aux_id, humidity: $humidity");

    my $limit = $self->_config_control('humidity_limit');
    my $min_run = $self->_config_control('humidity_aux_on_time');

    $log->_5("limit: $limit, minimum runtime: $min_run");

    if (! $self->aux_override($aux_id)) {
        if ($humidity < $limit && $self->aux_time($aux_id) == 0) {
            $log->_5("humidity limit reached turning $aux_id to HIGH");
            $self->aux_state($aux_id, HIGH);
            $self->aux_time($aux_id, time());
        }
        if ($humidity >= $limit && $self->aux_time($aux_id) >= $min_run) {
            $log->_5("humidity above limit setting $aux_id to LOW");

            $self->aux_state($aux_id, LOW);
            $self->aux_time($aux_id, 0);
        }
    }
}
sub action_temp {
    my $self = shift;
    my ($aux_id, $temp) = @_;

    my $log = $log->child('action_temp');

    my $limit = $self->_config_control('temp_limit');
    my $min_run = $self->_config_control('temp_aux_on_time');

    $log->_5("limit: $limit, minimum runtime: $min_run");

    if (! $self->aux_override($aux_id)){
        if ($temp > $limit && $self->aux_time($aux_id) == 0){
            $log->_5("temp limit reached turning $aux_id to HIGH");
            $self->aux_state($aux_id, HIGH);
            $self->aux_time($aux_id, time);
        }
        elsif ($temp <= $limit && $self->aux_time($aux_id) >= $min_run){
            $log->_5("temp below limit setting $aux_id to LOW");
            $self->aux_state($aux_id, LOW);
            $self->aux_time($aux_id, 0);
        }
    }
}
sub aux {
    my ($self, $aux_id) = @_;

    my $log = $log->child('aux');

    $log->_7("getting aux information for $aux_id");

    my $aux = $self->{db}->aux($aux_id);
    return $aux;
}
sub auxs {
    my $self = shift;

    my $log = $log->child('auxs');
    $log->_7("retrieving all auxs");

    return $self->{db}->auxs;
}
sub aux_id {
    my ($self, $aux) = @_;

    my $log = $log->child('aux_id');
    $log->_7("aux ID is $aux->{id}");

    return $aux->{id};
}
sub aux_state {
    my $self = shift;
    # maintains the auxillary state (on/off)

    my ($aux_id, $state) = @_;

    my $log = $log->child('aux_state');

    if ($aux_id !~ /^aux/){
        die "aux_state() requires an aux ID as its first param\n";
    }

    if (defined $state){
        $log->_5("setting state to $state for $aux_id");
        $self->{db}->update('aux', 'state', $state, 'id', $aux_id);
    }

    $state = $self->aux($aux_id)->{state};
    $log->_5("$aux_id state = $state");
    return $state;
}
sub aux_time {
    my $self = shift;
    # maintains the auxillary state (on/off)

    my ($aux_id, $time) = @_;

    if ($aux_id !~ /^aux/){
        die "aux_time() requires an aux ID as its first param\n";
    }

    if (defined $time) {
        $self->{db}->update('aux', 'on_time', $time, 'id', $aux_id);
    }

    my $on_time = $self->aux($aux_id)->{on_time};
    my $on_length = time() - $on_time;
    return $on_time == 0 ? 0 : $on_length;
}
sub aux_override {
    my $self = shift;
    # sets a manual override flag if an aux is turned on manually (via button)

    my ($aux_id, $override) = @_;

    if ($aux_id !~ /^aux/){
        die "aux_override() requires an aux ID as its first param\n";
    }

    if (defined $override){
        $self->{db}->update('aux', 'override', $override, 'id', $aux_id);
    }
    return $self->aux($aux_id)->{override};
}
sub aux_pin {
    my $self = shift;
    # returns the auxillary's GPIO pin number

    my ($aux_id, $pin) = @_;

    if ($aux_id !~ /^aux/){
        die "aux_pin() requires an aux ID as its first param\n";
    }

    if (defined $pin){
        $self->{db}->update('aux', 'pin', $pin, 'id', $aux_id);
    }
    return $self->aux($aux_id)->{pin};
}
sub _config_control {
    my $self = shift;
    my $want = shift;
    return $self->{db}->config_control($want);
}
sub _config_core {
    my $self = shift;
    my $want = shift;
    return $self->{db}->config_core($want);
}
sub _config_light {
    my $self = shift;
    my $want = shift;

    my $light = $self->{db}->config_light;

    my %conf;

    for (keys %$light) {
        $conf{$_} = $light->{$_}{value};
    }

    my ($on_hour, $on_min) = split /:/, $conf{on_at};

    my $now = DateTime->now(time_zone => $self->{db}->config_core('time_zone'));
    my $light_on = $now->clone;

    $light_on->set_hour($on_hour);
    $light_on->set_minute($on_min);

    my $dur = $now->subtract_datetime($light_on);
    $conf{on_in} = $dur->hours . ' hrs, ' . $dur->minutes . ' mins';

    if (defined $want){
        return $conf{$want};
    }

    return \%conf;
}
sub _config_water {
    my $self = shift;
    my $want = shift;

    my $water = $self->{db}->config_water;

    if (defined $want){
        return $water->{$want}{value};
    }

    my %conf;

    for (keys %$water){
        $conf{$_} = $water->{$_}{value};
    }

    return \%conf;
}
sub env {
    my ($self, $temp, $hum) = @_;

    if (@_ != 1 && @_ != 3){
        die "env() requires either zero params, or two\n";
    }

    if (defined $temp){
        if ($temp !~ /^\d+$/){
            die "env() temp param must be an integer\n";
        }
        if ($hum !~ /^\d+$/){
            die "env() humidity param must be an integer\n";
        }
    }

    if (defined $temp){
        $self->{db}->insert_env($temp, $hum);
    }

    my $ret = $self->{db}->env;
    return {temp => 0, humidity => 0} if ! defined $ret;
    return $self->{db}->env;
}
sub temp {
    my $self = shift;
    return $self->env()->{temp};
}
sub humidity {
    my $self = shift;
    return $self->env()->{humidity};
}
sub env_humidity_aux {
    my $self = shift;
    return $self->_config_control('humidity_aux');
}
sub env_temp_aux {
    my $self = shift;
    return $self->_config_control('temp_aux');
}
sub _parse_config {
    my $self = shift;

    my $json;
    {
        local $/;
        open my $fh, '<', $self->{config_file} or die $!;
        $json = <$fh>;
    }
    my $conf = decode_json $json;

    # auxillary channels

    for (1..8){
        my $aux_id = "aux$_";
        my $pin = $conf->{$aux_id}{pin};
        $self->aux_pin($aux_id, $pin);
    }

    for my $conf_section (qw(control core light water)){
        for my $directive (keys %{ $conf->{$conf_section} }){
            $self->{db}->update(
                $conf_section,
                'value',
                $conf->{$conf_section}{$directive},
                'id',
                $directive
            );
        }
    }
}
sub _reset {
    my $self = shift;
    # reset dynamic db attributes

    for (1..8){
        my $aux_id = "aux$_";
        $self->aux_time($aux_id, 0);
        $self->aux_state($aux_id, 0);
        $self->aux_override($aux_id, 0);
    }
}
sub _bool {
    # translates javascript true/false to 1/0

    my ($self, $bool) = @_;
    die "bool() needs either 'true' or 'false' as param\n" if ! defined $bool;
    return $bool eq 'true' ? 1 : 0;
}
sub log {
    return $master_log;
}
sub _init {
    my ($self) = @_;

    my $log = $log->child('_init()');

    if (-e 't/testing.lck' || $self->{testing}){
        $log->_6("testing mode");

        $self->{config_file} = 't/envui.json';

        if (-e 't/testing.lck') {
            $log->_6("UI testing mode");

            $self->{testing} = 1;

            my $mock = Mock::Sub->new;

            $temp_sub = $mock->mock(
                'RPi::DHT11::temp',
                return_value => 80
            );

            $log->_7("mocked RPi::DHT11::temp");

            $hum_sub = $mock->mock(
                'RPi::DHT11::humidity',
                return_value => 20
            );

            $log->_7("mocked RPi::DHT11::humidity");

            $pm_sub = $mock->mock(
                'App::RPi::EnvUI::API::pin_mode',
                return_value => 'ok'
            );

            $wp_sub = $mock->mock(
                'App::RPi::EnvUI::API::write_pin',
                return_value => 'ok'
            );

            $log->_7(
                "mocked WiringPi::write_pin as App::RPi::EnvUI::API::write_pin"
            );
        }

        warn "API in test mode\n";

        $self->{sensor} = bless {}, 'RPi::DHT11';

        $log->_7("blessed a fake sensor");

        $self->{db} = App::RPi::EnvUI::DB->new(
            testing => $self->{testing}
        );

        $log->_7("created a DB object with testing enabled");
    }
    else {
        if (! exists $INC{'WiringPi/API.pm'}){
            require WiringPi::API;
            WiringPi::API->import(qw(:perl));
        }
        if (! exists $INC{'RPi/DHT11.pm'}){
            require RPi::DHT11;
            RPi::DHT11->import;
        }
        $log->_6("required/imported WiringPi::API and RPi::DHT11");

        $sensor =  RPi::DHT11->new(
            #FIXME: new param to new() for DHT11 debug
            $self->_config_core('sensor_pin'), 1
        );
        $self->{sensor} = $sensor;
        $log->_6("instantiated a new RPi::DHT11 sensor object");
    }
}
sub _config {
    my ($self) = @_;
    $self->{config_file} = defined $self->{config_file}
        ? $self->{config_file}
        : 'config/envui.json';
}
sub _log {
    my ($self) = @_;

    my $file = defined $self->{log_file}
        ? $self->{log_file}
        : undef;

    $master_log = Logging::Simple->new(
        name => 'EnvUI',
        print => 0,
        file => $file,
        level => defined $self->{log_level} ? $self->{log_level} : 4
    );

    $log = $master_log->child('API');
}

true;
__END__

=head1 NAME

App::RPi::EnvUI - One-page asynchronous grow room environment control web
application

=head1 SYNOPSIS

    sudo plackup ./envui

=head1 DESCRIPTION

This distribution is alpha. It does not install the same way most CPAN modules
install, and has some significant requirements Most specifically, the
L<wiringPi|http://wiringpi.com> libraries, and the fact it can only run on a
Raspberry Pi. To boot, you have to have an elaborate electrical relay
configuration set up etc.

Right now, I'm testing an L<App::FatPacker> install method, where the packed 
web app is bundled into a single file called C<envui>, and placed in your
current working directory. See L</SYNOPSIS> for running the app. I doubt this
will work as expected on my first try.

It's got no tests yet, and barely any documentation. It's only here so I can
begin testing the installation routine.

This is my first web app in many, many years, so the technologies (jQuery,
L<Dancer2> etc) are brand new to me, so as I go, I'll be refactoring heavily as
I continue to learn.

At this stage, after I sort the installer, I will be focusing solely on tests.
After tests are done, I'll clean up the code (refactor), then complete the
existing non-finished functionality, and add the rest of the functionality I
want to add.

I'll then add pictures, diagrams and schematics of my physical layout of the Pi
all electrical components, and the electrical circuits.

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

