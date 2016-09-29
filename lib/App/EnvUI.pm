package App::EnvUI;

use Async::Event::Interval;
use Data::Dumper;
use DateTime;
use IPC::Shareable;
use Dancer2;
use Dancer2::Plugin::Database;
use JSON::XS;
use RPi::WiringPi::Constant qw(:all);

our $VERSION = '0.1';

_parse_config();
_reset();
_config_light();

my $event_env_to_db = Async::Event::Interval->new(
    _config_core('event_fetch_timer'),
    sub {
        my $temp = int(rand(100));
#        my $temp = 78;
        my $humidity = int(rand(100));
#        my $humidity = 21;
        db_insert_env($temp, $humidity);
    }
);

my $event_action_env = Async::Event::Interval->new(
    _config_core('event_action_timer'),
    sub {
        my $t_aux = env_temp_aux();
        my $h_aux = env_humidity_aux();

        action_temp($t_aux, temp());
        action_humidity($h_aux, humidity());
    }
);

$event_env_to_db->start;
$event_action_env->start;

get '/' => sub {
    # return template 'test';
    return template 'test';

    # the following events have to be referenced to within a route.
    # we do it after return as we don't need this code reached in actual
    # client calls

    my $evt_env_to_db = $event_env_to_db;
    my $evt_action_env = $event_action_env;
};

get '/light' => sub {
    return to_json _config_light();
};

get '/water' => sub {
    return to_json _config_water();
};

get '/get_config/:want' => sub {
    my $want = params->{want};
    my $value = _config_core($want);
    return $value;
};

get '/get_aux/:aux' => sub {
    return to_json aux(params->{aux});
};

get '/set_aux/:aux/:state' => sub {
    my $aux_id = params->{aux};

    my $state = _bool(params->{state});
    $state = aux_state($aux_id, $state);

    my $override = aux_override($aux_id) ? OFF : ON;
    $override = aux_override($aux_id, $override);

    return to_json {
        aux => $aux_id,
        state => $state,
    };
};

get '/fetch_env' => sub {
    my $data = env();
    return to_json {
        temp => $data->{temp},
        humidity => $data->{humidity}
    };
};

sub action_humidity {
    my ($aux_id, $humidity) = @_;

    my $min_run = _config('humidity_aux_on_time');
    my $limit = _config('humidity_limit');

    if ($humidity < $limit && aux_time($aux_id) == 0){
        aux_state($aux_id, HIGH);
        aux_time($aux_id, time);
    }
    elsif ($humidity >= $limit && aux_time($aux_id) >= $min_run){
        aux_state($aux_id, LOW);
        aux_time($aux_id, 0);
    }
}
sub action_temp {
    my ($aux_id, $temp) = @_;
    my $limit = _config('temp_limit');
    my $min_run = _config('temp_aux_on_time');

    if ($temp >= $limit && aux_time($aux_id) == 0){
        aux_state($aux_id, HIGH);
        aux_time($aux_id, time);
    }
    elsif ($temp < $limit && aux_time($aux_id) >= $min_run){
        aux_state($aux_id, LOW);
        aux_time($aux_id, 0);
    }
}
sub aux {
    my $aux_id = shift;

    my $aux_obj
        = database->selectrow_hashref("select * from aux where id='$aux_id'");

    return $aux_obj;
}
sub auxs {
    my $auxs = database->selectall_hashref("select * from aux", 'id');
    return $auxs;
}
sub aux_id {
    return $_[0]->{id};
}
sub aux_state {
    # maintains the auxillary state (on/off)

    my ($aux_id, $state) = @_;
    if (defined $state){
        db_update('aux', 'state', $state, 'id', $aux_id);
    }
    return aux($aux_id)->{state};
}
sub aux_time {
    # maintains the auxillary state (on/off)

    my ($aux_id, $time) = @_;

    if (defined $time) {
        db_update('aux', 'on_time', $time, 'id', $aux_id);
    }

    my $on_time = aux($aux_id)->{on_time};
    return $on_time == 0 ? 0 : time - $on_time;
}
sub aux_override {
    # sets a manual override flag if an aux is turned on manually (via button)

    my ($aux_id, $override) = @_;

    if (defined $override){
        db_update('aux', 'override', $override, 'id', $aux_id);
    }
    return aux($aux_id)->{override};
}
sub aux_pin {
    # returns the auxillary's GPIO pin number

    my ($aux_id, $pin) = @_;
    if (defined $pin){
        db_update('aux', 'pin', $pin, 'id', $aux_id);
    }
    return aux($aux_id)->{pin};
}
sub _config {
    my $want = shift;
    my $env_ctl = database->quick_select('control', {id => $want}, ['value']);
    return $env_ctl->{value};
}
sub _config_core {
    my $want = shift;
    my $core = database->quick_select('core', {id => $want}, ['value']);
    return $core->{value};
}
sub _config_light {
    my $light = database->selectall_hashref("select * from light;", 'id');

    my %conf;

    for (keys %$light) {
        $conf{$_} = $light->{$_}{value};
    }

    my ($on_hour, $on_min) = split /:/, $conf{on_at};

    my $now = DateTime->now(time_zone => _config_core('time_zone'));
    my $light_on = $now->clone;

    $light_on->set_hour($on_hour);
    $light_on->set_minute($on_min);

    my $dur = $now->subtract_datetime($light_on);
    $conf{on_in} = $dur->hours . ' hrs, ' . $dur->minutes . ' mins';

    return \%conf;
}
sub _config_water {
    my $water = database->selectall_hashref("select * from water;", 'id');

    my %conf;

    for (keys %$water){
        $conf{$_} = $water->{$_}{value};
    }

    return \%conf;
}
sub env {
    my $id = _get_last_id();

    my $row = database->quick_select(
        stats => {id => $id}
    );

    return $row;
}
sub temp {
    return env()->{temp};
}
sub humidity {
    return env()->{humidity};
}
sub env_humidity_aux {
    return _config('humidity_aux');
}
sub env_temp_aux {
    return _config('temp_aux');
}
sub db_insert_env {
    my ($temp, $hum) = @_;
    database->quick_insert(stats => {
            temp => $temp,
            humidity => $hum,
        }
    );
}
sub db_update {
    my ($table, $col, $value, $where_col, $where_val) = @_;
    if (! defined $where_col){
        database->do("UPDATE $table SET $col='$value'");
    }
    else {
        database->do(
            "UPDATE $table SET $col='$value' WHERE $where_col='$where_val'"
        );
    }
}
sub _parse_config {
    my $json;
    {
        local $/;
        open my $fh, '<', 'config/envui.json' or die $!;
        $json = <$fh>;
    }
    my $conf = decode_json $json;

    # auxillary channels

    for (1..8){
        my $aux_id = "aux$_";
        my $pin = $conf->{$aux_id}{pin};
        aux_pin($aux_id, $pin);
    }

    # aux

    for my $directive (keys %{ $conf->{aux} }){
        db_update('aux', 'value', $conf->{aux}{$directive}, 'id', $directive);
    }

    # environment control

    for my $directive (keys %{ $conf->{control} }){
        db_update(
            'control', 'value', $conf->{control}{$directive}, 'id', $directive
        );
    }

    # core configuration

    for my $directive (keys %{ $conf->{core} }){
        db_update('core', 'value', $conf->{core}{$directive}, 'id', $directive);
    }

    # light config

    for my $directive (keys %{ $conf->{light} }){
        db_update('light', 'value', $conf->{light}{$directive}, 'id', $directive);
    }
}
sub _reset {
    # reset dynamic db attributes
    aux_time('aux1', 0);
    aux_time('aux2', 0);
    aux_time('aux3', 0);
    aux_time('aux4', 0);
    aux_time('aux5', 0);
    aux_time('aux6', 0);
    aux_time('aux7', 0);
    aux_time('aux8', 0);
}
sub _bool {
    # translates javascript true/false to 1/0

    my $bool = shift;
    return $bool eq 'true' ? 1 : 0;
}
sub _get_last_id {
    my $id = database->selectrow_arrayref(
        "select seq from sqlite_sequence where name='stats';"
    )->[0];
    return $id;
}

true;
