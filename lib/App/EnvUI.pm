package App::EnvUI;

use Async::Event::Interval;
use Data::Dumper;
use IPC::Shareable;
use Dancer2;
use Dancer2::Plugin::Database;
use JSON::XS;

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
    2,
    sub {
        my $env = fetch_env();
    },
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
        my $aux = params->{aux};
        my $state = aux_state($aux);
        my $override = aux_override($aux);
        my $pin = aux_pin($aux);

        print "!!! $aux, $state, $override, $pin\n";
        return to_json {
                pin => $pin,
                state => $state,
                override => $override,
                pin => $pin,
        };
    };

get '/set_aux/:aux/:state' => sub {
        my $aux = params->{aux};

        my $state = _bool(params->{state});
        $state = aux_state($aux, $state);

        my $override = aux_override($aux) ? 0 : 1;
        $override = aux_override($aux, $override);

        return to_json {
            aux => $aux,
            state => $state,
        };
    };

get '/fetch_env' => sub {
        my $data = fetch_env();
        return to_json {
            temp => $data->{temp},
            humidity => $data->{humidity}
        };
    };

sub db_insert_env {
    my ($temp, $hum) = @_;
    database->quick_insert(stats => {
            temp => $temp,
            humidity => $hum,
        }
    );
}
sub fetch_env {
    my $id = _get_last_id();

    my $row = database->quick_select(
        stats => {id => $id}, ['temp', 'humidity']
    );

    return $row;
}
sub _bool {
    # translates javascript true/false to 1/0

    my $bool = shift;
    return $bool eq 'true' ? 1 : 0;
}
sub aux_state {
    # maintains the auxillary state (on/off)

    my ($aux, $state) = @_;
    if (defined $state){
        update_aux_db('state', $aux, $state);
    }
    return fetch_aux($aux)->{state};
}
sub aux_override {
    # sets a manual override flag if an aux is turned on manually (via button)

    my ($aux, $override) = @_;

    if (defined $override){
        update_aux_db('override', $aux, $override);
    }
    return fetch_aux($aux)->{override};
}
sub aux_pin {
    # returns the auxillary's GPIO pin number

    my ($aux, $pin) = @_;

    if (defined $pin){
        update_aux_db('aux', $aux, $pin);
    }
    return fetch_aux($aux)->{pin};
}
sub update_aux_db {
    my ($col, $aux, $value) = @_;
    my $table = 'aux';

    database->do("UPDATE $table SET $col='$value' where id='$aux'");
#    $sth->execute($value, $aux);
}
sub _get_last_id {
    my $id = database->selectrow_arrayref(
        "select seq from sqlite_sequence where name='stats';"
    )->[0];
    return $id;
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
        update_aux_db('pin', $aux, $conf->{$aux}{pin});
    }
}
sub fetch_aux {
    my $aux = shift;
    my $aux_obj = database->selectrow_hashref("select * from aux where id='$aux'");
}
true;
