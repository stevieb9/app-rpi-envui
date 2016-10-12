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

our $VERSION = '0.25';

# mocked sub handles for when we're in testing mode

our ($temp_sub, $hum_sub, $wp_sub, $pm_sub);

# class variables

my $master_log;
my $log;
my $sensor;

# public environment methods

sub new {
    my $self = bless {}, shift;

    my $caller = (caller)[0];
    $self->_args(@_, caller => $caller);

    $self->_log;
    $self->_init;

    $log->_7("successfully initialized the system");

    $self->events if ! $self->testing;

    $log->_7("successfully started the async events");

    return $self;
}
sub action_humidity {
    #FIXME: this, and action_temp() should retrieve their own aux id
    # from the db directly, instead of having it passed in?

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
        $self->db()->update('light', 'value', time(), 'id', 'on_since');
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
            $self->db()->update( 'light', 'value', 0, 'id', 'on_since' );
            $self->aux_state( $self->_config_control( 'light_aux' ), OFF );
            pin_mode($self->_config_control('light_aux'),  OUTPUT);
            write_pin($self->aux_pin($self->_config_control('light_aux')), LOW);
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
        $self->db()->update('light', 'value', time(), 'id', 'on_since');
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
            $self->db()->update( 'light', 'value', 0, 'id', 'on_since' );
            $self->aux_state( $self->_config_control( 'light_aux' ), OFF );
            pin_mode($self->_config_control('light_aux'),  OUTPUT);
            write_pin($self->aux_pin($self->_config_control('light_aux')), LOW);
        }
    }
}
sub aux {
    my ($self, $aux_id) = @_;

    my $log = $log->child('aux');

    $log->_7("getting aux information for $aux_id");

    my $aux = $self->db()->aux($aux_id);
    return $aux;
}
sub auxs {
    my $self = shift;

    my $log = $log->child('auxs');
    $log->_7("retrieving all auxs");

    return $self->db()->auxs;
}
sub aux_id {
    my ($self, $aux) = @_;

    my $log = $log->child('aux_id');
    $log->_7("aux ID is $aux->{id}");

    return $aux->{id};
}
sub aux_override {
    my $self = shift;
    # sets a manual override flag if an aux is turned on manually (via button)

    my ($aux_id, $override) = @_;

    if ($aux_id !~ /^aux/){
        confess "aux_override() requires an aux ID as its first param\n";
    }

    if (defined $override){
        $self->db()->update('aux', 'override', $override, 'id', $aux_id);
    }
    return $self->aux($aux_id)->{override};
}
sub aux_pin {
    my $self = shift;
    # returns the auxillary's GPIO pin number

    my ($aux_id, $pin) = @_;

    if ($aux_id !~ /^aux/){
        confess "aux_pin() requires an aux ID as its first param\n";
    }

    if (defined $pin){
        $self->db()->update('aux', 'pin', $pin, 'id', $aux_id);
    }
    return $self->aux($aux_id)->{pin};
}
sub aux_state {
    my $self = shift;
    # maintains the auxillary state (on/off)

    my ($aux_id, $state) = @_;

    my $log = $log->child('aux_state');

    if ($aux_id !~ /^aux/){
        confess "aux_state() requires an aux ID as its first param\n";
    }

    if (defined $state){
        $log->_5("setting state to $state for $aux_id");
        $self->db()->update('aux', 'state', $state, 'id', $aux_id);
    }

    $state = $self->aux($aux_id)->{state};
    $log->_5("$aux_id state = $state");
    return $state;
}
sub aux_time {
    my $self = shift;
    # maintains the auxillary on time

    my ($aux_id, $time) = @_;

    if ($aux_id !~ /^aux/){
        confess "aux_time() requires an aux ID as its first param\n";
    }

    if (defined $time) {
        $self->db()->update('aux', 'on_time', $time, 'id', $aux_id);
    }

    my $on_time = $self->aux($aux_id)->{on_time};
    my $on_length = time() - $on_time;
    return $on_time == 0 ? 0 : $on_length;
}
sub env {
    my ($self, $temp, $hum) = @_;

    if (@_ != 1 && @_ != 3){
        confess "env() requires either zero params, or two\n";
    }

    if (defined $temp){
        if ($temp !~ /^\d+$/){
            confess "env() temp param must be an integer\n";
        }
        if ($hum !~ /^\d+$/){
            confess "env() humidity param must be an integer\n";
        }
    }

    if (defined $temp){
        $self->db()->insert_env($temp, $hum);
    }

    my $ret = $self->db()->env;
    return {temp => 0, humidity => 0} if ! defined $ret;
    return $self->db()->env;
}
sub humidity {
    my $self = shift;
    return $self->env()->{humidity};
}
sub read_sensor {
    my $self = shift;

    my $log = $log->child('read_sensor');

    if (! defined $self->sensor){
        confess "\$self->{sensor} is not defined";
    }
    my $temp = $self->sensor()->temp('f');
    my $hum = $self->sensor()->humidity;

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
sub temp {
    my $self = shift;
    return $self->env()->{temp};
}

# public core operational methods

sub events {
    my $self = shift;

    my $log = $self->log('events');

    my $events = App::RPi::EnvUI::Event->new($self->testing);

    $self->{events}{env_to_db} = $events->env_to_db;
    $self->{events}{env_action} = $events->env_action;

    $self->{events}{env_to_db}->start;
    $self->{events}{env_action}->start;

    $log->_7("events successfully started");
}
sub log {
    my $self = shift;
    $master_log->file($self->log_file) if $self->log_file;
    $master_log->level($self->log_level);
    return $master_log;
}

# public configuration getters

sub env_humidity_aux {
    my $self = shift;
    return $self->_config_control('humidity_aux');
}
sub env_temp_aux {
    my $self = shift;
    return $self->_config_control('temp_aux');
}

# public instance variable methods

sub config {
    $_[0]->{config_file} = $_[1] if defined $_[1];
    return $_[0]->{config_file} || 'config/envui.json';
}
sub db {
    my ($self, $db) = @_;
    $self->{db} = $db if defined $db;
    return $self->{db};
}
sub debug_sensor {
    my ($self, $bool) = @_;

    if (defined $bool){
        $self->{debug_sensor} = $bool;
    }

    return $self->{debug_sensor};
}
sub log_file {
    my ($self, $fn) = @_;

    if (defined $fn){
        $self->{log_file} = $fn;
    }

    return $self->{log_file};
}
sub log_level {
    my ($self, $level) = @_;

    if (defined $level){
        if ($level < -1 || $level > 7){
            warn "log level has to be between 0 and 7... disabling logging\n";
            $level = -1;
        }
        $self->{log_level} = $level;
    }

    return $self->{log_level};
}
sub sensor {
    my ($self, $sensor) = @_;
    $self->{sensor} = $sensor if defined $sensor;
    return $self->{sensor};
}
sub testing {
    my ($self, $bool) = @_;

    if (defined $bool){
        $self->{testing} = $bool;
    }
    return $self->{testing};
}

sub test_mock {
    my ($self, $mock) = @_;

    if (defined $mock){
        $self->{test_mock} = $mock;
    }
    $self->{test_mock} = 1 if ! defined $self->{test_mock};
    return $self->{test_mock};
}

# private

sub _args {
    my ($self, %args) = @_;
    $self->debug_sensor($args{debug_sensor});
    $self->config($args{config_file});
    $self->log_file($args{log_file});
    $self->log_level($args{log_level});
    $self->testing($args{testing});
    $self->test_mock($args{test_mock});
}
sub _bool {
    # translates javascript true/false to 1/0

    my ($self, $bool) = @_;
    confess
      "bool() needs either 'true' or 'false' as param\n" if ! defined $bool;
    return $bool eq 'true' ? 1 : 0;
}
sub _config_control {
    my $self = shift;
    my $want = shift;
    return $self->db()->config_control($want);
}
sub _config_core {
    my $self = shift;
    my $want = shift;
    if (! defined $self->db()){
        confess "API's DB object is not defined.";
    }
    return $self->db()->config_core($want);
}
sub _config_light {
    my $self = shift;
    my $want = shift;

    my $light = $self->db()->config_light;

    my %conf;

    for (keys %$light) {
        $conf{$_} = $light->{$_}{value};
    }

    my ($on_hour, $on_min) = split /:/, $conf{on_at};

    my $now = DateTime->now(time_zone => $self->db()->config_core('time_zone'));
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

    my $water = $self->db()->config_water;

    if (defined $want){
        return $water->{$want}{value};
    }

    my %conf;

    for (keys %$water){
        $conf{$_} = $water->{$_}{value};
    }

    return \%conf;
}
sub _init {
    my ($self) = @_;

    my $log = $log->child('_init()');

    $self->db(
        App::RPi::EnvUI::DB->new(
            testing => $self->testing
        )
    );

    if ($self->_ui_test_mode || $self->testing){
        $self->_test_mode
    }
    else {
        $self->_prod_mode;
    }
}
sub _test_mode {
    my ($self) = @_;

    my $log = $log->child('_test_mode');
    $log->_6("testing mode");

    $self->config('t/envui.json');
    $self->_parse_config;

    $self->testing(1);

    if ($self->test_mock) {
        my $mock = Mock::Sub->new;

        $temp_sub = $mock->mock(
            'RPi::DHT11::temp',
            return_value => 80
        );

        $log->_7( "mocked RPi::DHT11::temp" );

        $hum_sub = $mock->mock(
            'RPi::DHT11::humidity',
            return_value => 20
        );

        $log->_7( "mocked RPi::DHT11::humidity" );

        $pm_sub = $mock->mock(
            'App::RPi::EnvUI::API::pin_mode',
            return_value => 'ok'
        );

        $wp_sub = $mock->mock(
            'App::RPi::EnvUI::API::write_pin',
            return_value => 'ok'
        );
    }

    $log->_7(
        "mocked WiringPi::write_pin as App::RPi::EnvUI::API::write_pin"
    );

    warn "API in test mode\n";

    $self->sensor(bless {}, 'RPi::DHT11');

    $log->_7("blessed a fake sensor");

}
sub _prod_mode {
    my ($self) = @_;

    my $log = $log->child('_prod_mode');

    $self->_parse_config;

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
        $self->_config_core('sensor_pin'), $self->debug_sensor
    );
    $self->sensor($sensor);
    $log->_6("instantiated a new RPi::DHT11 sensor object");
}
sub _log {
    my ($self) = @_;

    # configures the class-level log

    $master_log = Logging::Simple->new(
        name => 'EnvUI',
        print => 1,
        file => $self->log_file,
        level => $self->log_level
    );

    $log = $master_log->child('API');
}
sub _parse_config {
    my ($self, $config) = @_;

    $config = $self->config if ! defined $config;

    my $json;
    {
        local $/;
        open my $fh, '<', $config or confess $!;
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
            $self->db()->update(
                $conf_section,
                'value',
                $conf->{$conf_section}{$directive},
                'id',
                $directive
            );

            # populate some internal variables from the 'core'
            # config section

            if ($conf_section eq 'core'){
                next if $directive eq 'testing';
                $self->{$directive} = $conf->{$conf_section}{$directive};
            }
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
sub _ui_test_mode {
    return -e 't/testing.lck';
}

true;
__END__

=head1 NAME

App::RPi::EnvUI::API - Core API abstraction class for the
App::RPi::EnvUI web app

=head1 SYNOPSIS

    my $api = App::RPi::EnvUI::API->new;

    ... #FIXME: add a real example

=head1 DESCRIPTION

This class can be used outside of the L<App::RPi::EnvUI> web application to
update settings, read statuses, perform analysis and generate reports.

It's primary purpose is to act as an intermediary between the web app itself,
the asynchronous events that run within their own processes, the environment
sensors, and the application database.

=head1 METHODS

=head2 new(%args)

Instantiates a new core API object. Send any/all parameters in within hash
format (eg: C< testing =\> 1)).

Parameters:

    config

Optional, String. Name of the configuration file to use. Very rarely required.

Default: C<config/envui.json>

    testing

Optional, Bool. Send in C<1> to enable testing, C<0> to disable it.

Default: C<0>

    test_mock

This flag is only useful when C<testing> param is set to true, and should only
be used when writing unit tests for the L<App::RPi::EnvUI::Event> class. Due to
the way the system works, the API has to avoid mocking out items in test mode,
and the mocks have to be set within the test file itself. Do not use this flag
unless you are writing unit tests.

    log_level

Optional, Integer. Send in a level of C<0-7> to enable logging.

Default: C<-1> (logging disabled)

    log_file

Optional, String. Name of file to log to. We log to C<STDOUT> by default. The
C<log_level> parameter must be changed from default for this parameter to have
any effect.

Default: C<undef>

    debug_sensor

Optional, Bool. Enable/disable debug print output from the L<RPi::DHT11> sensor
code. Send in C<1> to enable, and C<0> to disable.

Default: C<0> (off)

=head2 action_humidity($aux_id, $humidity)

Performs the check of the current humidity against the configured set limit, and
enables/disables any devices attached to the humidity auxillary GPIO pin, if
set.

Parameters:

    $aux_id

Mandatory, String. The string name representation of the humidity auxillary. By
default, this will be C<aux2>.

    $humidity

Mandatory: Integer. The integer value of the current humidity (typically
supplied by the C<RPi::DHT11> hygrometer sensor.

=head2 action_light

Performs the time calculations on the configured light on/off event settings,
and turns the GPIO pin associated with the light auxillary channel on and off as
required.

Takes no parameters.

=head2 action_temp($aux_id, $temperature)

Performs the check of the current temperature against the configured set limit,
and enables/disables any devices attached to the temp auxillary GPIO pin, if
set.

Parameters:

    $aux_id

Mandatory, String. The string name representation of the temperature auxillary.
By default, this will be C<aux1>.

=head2 aux($aux_id)

Retrieves from the database a hash reference that contains the details of a
specific auxillary channel, and returns it.

Parameters:

    $aux_id

Mandatory, String. The string name representation of the auxillary channel to
retrieve (eg: C<aux1>).

Returns: Hash reference with the auxillary channel details.

=head2 auxs

Fetches the details of all the auxillary channels from the database. Takes no
parameters.

Return: A hash reference of hash references, where each auxillary channel name
is a key, and the value is a hash reference containing that auxillary channel's
details.

=head2 aux_id($aux)

Extracts the name/ID of a specific auxillary channel.

Parameters:

    $aux

Mandatory, href. A hash reference as returned from a call to C<aux()>.

Return: String. The name/ID of the specified auxillary channel.

=head2 aux_override($aux_id, $override)

Sets/gets the override status of a specific aux channel.

The override functionality is a flag in the database that informs the system
that automated triggering of an auxillary GPIO pin should be bypassed due to
user override.

Parameters:

    $aux_id

Mandatory, String. The string name of an auxillary channel (eg: C<aux1>).

    $state

Optional, Bool. C<0> to disable an aux pin override, C<1> to enable it.

Return: Bool. Returns the current status of the aux channel's override flag.

=head2 aux_pin($aux_id, $pin)

Associates a GPIO pin to a specific auxillary channel.

Parameters:

    $aux_id

Mandatory, String. The string name of an auxillary channel (eg: C<aux1>).

    $pin

Optional, Integer. The GPIO pin number that you want associated with the
specified auxillary channel.

Return: The GPIO pin number associated with the auxillary channel specified.

=head2 aux_state($aux_id, $state)

Sets/gets the state (ie. on/off) value of a specific auxillary channel's GPIO
pin.

Parameters:

    $aux_id

Mandatory, String. The string name of an auxillary channel (eg: C<aux1>).

    $state

Optional, Bool. C<0> to turn the pin off (C<LOW>), or C<1> to turn it on
(C<HIGH>).

Return: Bool. Returns the current state of the aux pin.

=head2 aux_time($aux_id, $time)

Sets/gets the length of time an auxillary channel's GPIO pin has been C<HIGH>
(on). Mainly used to determine timers.

Parameters:

    $aux_id

Mandatory, String. The string name of an auxillary channel (eg: C<aux1>).

    $time

Optional, output from C<time()>. If sent in, we'll set the start time of a pin
on event to this.

Return, Integer (seconds). Returns the elapsed time in seconds since the last
timestamp was sent in with the C<$time> parameter, after being subtracted with
a current C<time()> call. If C<$time> has not been sent in, or an internal timer
has reset this value, the return will be zero (C<0>).

=head2 config($conf_file)

Sets/gets the currently loaded configuration file.

Parameters:

    $conf_file

Optional, String. The name of a configuration file. This is only useful on
instantiation of a new object.

Default: C<config/envui.json>

Returns the currently loaded configuration file name.

=head2 db($db_object)

Sets/gets the internal L<App::RPi::EnvUI::DB> object. This method allows you to
swap DB objects (and thereby DB handles) within separate processes.

Parameters:

    $db_object

Optional, L<App::RPi::EnvUI::DB> object instance.

Returns: The currently loaded DB object instance.

=head2 debug_sensor($bool)

Enable/disable L<RPi::DHT11> sensor's debug print output.

Parameters:

    $bool

Optional, Bool. C<1> to enable debugging, C<0> to disable.

Return: Bool. The current state of the sensor's debug state.

Default: False (C<0>)

=head2 env($temp, $humidity)

Sets/gets the current temperature and humidity pair.

Parameters:

All parameters are optional, but if one is sent in, both must be sent in.

    $temp

Optional, Integer. The current temperature.

    $humidity

Optional, Integer. The current humidity .

Return: A hash reference in the format C<{temp => Int, humidity => Int}>

=head2 env_humidity_aux

Returns the string name of the humidity auxillary channel (default: C<aux2>).
Takes no parameters.

=head2 env_temp_aux

Returns the string name of the temperature auxillary channel (default: C<aux1>).
Takes no parameters.

=head2 events

Initializes and starts the asynchronous timed events that operate in their own
processes, performing actions outside of the main thread.

Takes no parameters, has no return.

=head2 humidity

Returns as an integer, the current humidity level.

=head2 temp

Returns as an integer, the current temperature level.

=head2 log

Returns a pre-configured L<Logging::Simple> object, ready to be cloned with its
C<child()> method.

=head2 log_file($filename)

Sets/gets the log file for the internal logger.

Parameters:

    $filename

Optional, String. The name of the log file to use. Note that this won't have any
effect when used in user space, and is mainly a convenience method. It's used
when instantiating a new object.

Return: The string name of the currently in-use log file, if set.

=head2 log_level($level)

Sets/gets the current logging level.

Parameters:

    $level

Optional, Integer. Sets the logging level between C<0-7>.

Return: Integer, the current level.

Default: C<-1> (logging disabled)

=head2 read_sensor

Retrieves and returns the current temperature and humidity within an array of
two integers.

=head2 sensor($sensor)

Sets/gets the current hygrometer sensor object. This method is here so that for
testing, we can send in mocked sensor objects.

Parameters:

    $sensor

Optional, L<RPi::DHT11> object instance.

Return: The sensor object.

=head2 switch($aux_id)

Enables/disables the GPIO pin associated with the specified auxillary channel,
based on what the current state of the pin is. If it's currently off, it'll be
turned on, and vice-versa.

Parameters:

    $aux_id

Mandatory, String. The string name of the auxillary channel to have it's GPIO
pin switched (eg: C<aux1>).

Return: none

=head2 testing($bool)

Used primarily internally, sets/gets whether we're in testing mode or not.

Parameters:

    $bool

Optional, Bool. C<0> for production mode, and C<1> for testing mode.

Return: Bool, whether we're in testing mode or not.

=head1 AUTHOR

Steve Bertrand, E<lt>steveb@cpan.org<gt>

=head1 LICENSE AND COPYRIGHT

Copyright 2016 Steve Bertrand.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See L<http://dev.perl.org/licenses/> for more information.

