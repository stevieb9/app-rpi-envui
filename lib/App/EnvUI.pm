package App::EnvUI;

use Async::Event::Interval;
use Data::Dumper;
use IPC::Shareable;
use Dancer2;
use Dancer2::Plugin::Database;
use JSON::XS;
use RPi::WiringPi::Constant qw(:all);

our $VERSION = '0.1';

_parse_config();
_reset();

my $event_env_to_db = Async::Event::Interval->new(
    5,
    sub {
        #my $temp = int(rand(100));
        my $temp = 78;
        #my $humidity = int(rand(100));
        my $humidity = 21;
        db_insert_env($temp, $humidity);
    }
);

my $event_action_env = Async::Event::Interval->new(
    3,
    sub {
        my $env = env();
        my $auxs = auxs();
        my $t_aux = $auxs->{'aux1'};
        my $h_aux = $auxs->{'aux2'};

        my $env_ctl = database->quick_select('control', {id => 1});

        action_temp($t_aux, $env->{temp}, $env_ctl);
        action_humidity($h_aux, $env->{humidity}, $env_ctl);
    }
);
sub action_humidity {
    my ($aux, $humidity, $env_ctl) = @_;

    my $min_run = $env_ctl->{humidity_aux_on_time};
    my $limit = $env_ctl->{humidity_limit};

    if ($humidity < $limit && aux_time($aux->{id}) == 0){
        print "h on\n";
        aux_state($aux->{id}, HIGH);
        aux_time($aux->{id}, time);
    }
    elsif ($humidity >= $limit && aux_time($aux->{id}) >= $min_run){
        print "h off\n";
        aux_state($aux->{id}, LOW);
        aux_time($aux->{id}, 0);
    }
}
sub action_temp {
    my ($aux, $temp, $env_ctl) = @_;
    my $limit = $env_ctl->{temp_limit};
    my $min_run = $env_ctl->{temp_aux_on_time};

    print "$temp ::::: $limit\n";
    if ($temp >= $limit && aux_time($aux->{id}) == 0){
        print "t on\n";
        aux_state($aux->{id}, HIGH);
        aux_time($aux->{id}, time);
    }
    elsif ($temp < $limit && aux_time($aux->{id}) >= $min_run){
        print "t off\n";
        aux_state($aux->{id}, LOW);
        aux_time($aux->{id}, 0);
    }
}

$event_env_to_db->start;
$event_action_env->start;

get '/' => sub {
        return template 'main';

        # the following events have to be referenced to within a route.
        # we do it after return as we don't need this code reached in actual
        # client calls

        my $evt_env_to_db = $event_env_to_db;
        my $evt_action_env = $event_action_env;
    };

get '/get_aux/:aux' => sub {
        return to_json aux(params->{aux});
    };

get '/set_aux/:aux/:state' => sub {
        my $aux = params->{aux};

        my $state = _bool(params->{state});
        $state = aux_state($aux, $state);

        my $override = aux_override($aux) ? OFF : ON;
        $override = aux_override($aux, $override);

        return to_json {
            aux => $aux,
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

sub aux {
    my $aux = shift;
    my $aux_obj
        = database->selectrow_hashref("select * from aux where id='$aux'");
    print Dumper $aux_obj;
    return $aux_obj;
}
sub auxs {
    my $auxs = database->selectall_hashref("select * from aux", 'id');
    return $auxs;
}
sub aux_state {
    # maintains the auxillary state (on/off)

    my ($aux, $state) = @_;
    if (defined $state){
        db_update('aux', 'state', $state, 'id', $aux);
    }
    return aux($aux)->{state};
}
sub aux_time {
    # maintains the auxillary state (on/off)

    my ($aux, $time) = @_;
    if (defined $time){
        db_update('aux', 'on_time', $time, 'id', $aux);
    }
    my $on_time = aux($aux)->{on_time};
    my $x = time - $on_time;
    print "$aux: $x\n";
    return $on_time == 0 ? 0 : time - $on_time;
}
sub aux_override {
    # sets a manual override flag if an aux is turned on manually (via button)

    my ($aux, $override) = @_;

    if (defined $override){
        db_update('aux', 'override', $override, 'id', $aux);
    }
    return aux($aux)->{override};
}
sub aux_pin {
    # returns the auxillary's GPIO pin number

    my ($aux, $pin) = @_;

    if (defined $pin){
        update_db('aux', $aux, $pin);
    }
    return aux($aux)->{pin};
}
sub env {
    my $id = _get_last_id();

    my $row = database->quick_select(
        stats => {id => $id}
    );

    return $row;
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

    for (1..4){
        my $aux = "aux$_";
        db_update('aux', 'pin', $conf->{$aux}{pin});
    }

    for my $opt (keys %{ $conf->{control} }){
        db_update('control', $opt, $conf->{control}{$opt});
    }
}
sub _reset {
    # reset dynamic db attributes
    aux_time('aux1', 0);
    aux_time('aux2', 0);
    aux_time('aux3', 0);
    aux_time('aux4', 0);
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
