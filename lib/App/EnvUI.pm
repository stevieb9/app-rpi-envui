package App::EnvUI;

use Async::Event::Interval;
use Data::Dumper;
use IPC::Shareable;
use Dancer2;
use Dancer2::Plugin::Database;
use JSON::XS;
use RPi::WiringPi::Constant qw(:all);

our $VERSION = '0.1';

parse_config();

my $event_env_to_db = Async::Event::Interval->new(
    5,
    sub {
        my $temp = int(rand(100));
        my $humidity = int(rand(100));
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

        my $t_limit = 50;
        print "****** ". aux_time($t_aux->{id}) . "\n";
        if ($env->{temp} > $t_limit && (aux_time($t_aux->{id}) == 0)){
            aux_state($t_aux->{id}, HIGH);
            aux_time($t_aux->{id}, time);
        }
        elsif ($env->{temp} < $t_limit && aux_time($t_aux->{id}) >= 900){
            aux_state($t_aux->{id}, LOW);
            aux_time($t_aux->{id}, 0);
        }

        if ($env->{humidity} < 50){
            aux_state($h_aux->{id}, HIGH);
        }
        else {
            aux_state($h_aux->{id}, LOW);
        }
    }
);

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
        db_update_aux('state', $aux, $state);
    }
    return aux($aux)->{state};
}
sub aux_time {
    # maintains the auxillary state (on/off)

    my ($aux, $time) = @_;
    if (defined $time){
        db_update_aux('on_time', $aux, $time);
    }
    my $on_time = aux($aux)->{on_time};
    return $on_time == 0 ? 0 : time - $on_time;
}
sub aux_override {
    # sets a manual override flag if an aux is turned on manually (via button)

    my ($aux, $override) = @_;

    if (defined $override){
        db_update_aux('override', $aux, $override);
    }
    return aux($aux)->{override};
}
sub aux_pin {
    # returns the auxillary's GPIO pin number

    my ($aux, $pin) = @_;

    if (defined $pin){
        update_aux_db('aux', $aux, $pin);
    }
    return aux($aux)->{pin};
}
sub env {
    my $id = _get_last_id();

    my $row = database->quick_select(
        stats => {id => $id}, ['temp', 'humidity']
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
sub db_update_aux {
    my ($col, $aux, $value) = @_;
    my $table = 'aux';

    database->do("UPDATE $table SET $col='$value' where id='$aux'");
#    $sth->execute($value, $aux);
}
sub parse_config {
    my $json;
    {
        local $/;
        open my $fh, '<', 'config/envui.json' or die $!;
        $json = <$fh>;
    }
    my $conf = decode_json $json;

    for (1..4){
        my $aux = "aux$_";
        db_update_aux('pin', $aux, $conf->{$aux}{pin});
    }
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
