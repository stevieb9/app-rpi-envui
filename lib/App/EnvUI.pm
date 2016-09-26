package App::EnvUI;

use Async::Event::Interval;
use Data::Dumper;
use IPC::Shareable;
use Dancer2;
use Dancer2::Plugin::Database;
use JSON::XS;

our $VERSION = '0.1';

my $conf = parse_config();

my $auxs;
$auxs = _generate_aux();
tie $auxs, 'IPC::Shareable', undef, {destroy => 1};

my $event_env_to_db = Async::Event::Interval->new(
    5,
    sub {
        my $temp = int(rand(100));
        my $humidity = int(rand(100));
        insert($temp, $humidity);
    }
);

my $event_action_env = Async::Event::Interval->new(
    2,
    sub {
        my $env = fetch_env();
        print "*** $auxs->{aux3}{pin}, $auxs->{aux3}{state} ***\n";
    }
);

$event_env_to_db->start;
$event_action_env->start;

get '/' => sub {
        $auxs = _generate_aux();
        return template 'main';

        # the following events have to be referenced to within a route.
        # we do it after return as we don't need this code reached in actual
        # client calls

        my $evt_env_to_db = $event_env_to_db;
        my $evt_action_env = $event_action_env;
    };

get '/get_aux/:aux' => sub {
        my $aux = params->{aux};
        my $state = _aux_state($aux);
        my $override = _aux_override($aux);
        my $pin = _aux_pin($aux);
        return to_json {
                pin => $pin,
                state => $state,
                override => $override,
                pin => $auxs->{$aux}{pin},
        };
    };

get '/set_aux/:aux/:state' => sub {
        my $aux = params->{aux};
        my $state = _bool(params->{state});

        _aux_state($aux, $state);

        my $override = _aux_override($aux) ? 0 : 1;
        _aux_override($aux, $override);

        return to_json {
            aux => $aux,
            state => $auxs->{$aux}{state}
        };
    };

get '/fetch_env' => sub {
        my $data = fetch_env();
        return to_json {
            temp => $data->{temp},
            humidity => $data->{humidity}
        };
    };

sub insert {
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
sub _aux_state {
    # maintains the auxillary state (on/off)

    my ($aux, $state) = @_;
    return $auxs->{$aux}{state} if ! defined $state;
    $auxs->{$aux}{state} = $state;
    return $state;
}
sub _aux_override {
    # sets a manual override flag if an aux is turned on manually (via button)

    my ($aux, $override) = @_;
    return $auxs->{$aux}{override} if ! defined $override;
    $auxs->{$aux}{override} = $override;
    return $override;
}
sub _aux_pin {
    # returns the auxillary's GPIO pin number

    my $aux = shift;
    return $auxs->{$aux}{pin};
}
sub _generate_aux {
    # generate the auxillary control objects

    my %auxillaries;

    for (1..4){
        my $aux = "aux$_";
        $auxillaries{$aux} = {
            pin => $conf->{$aux}{pin},
            default => $conf->{$aux}{default},
            state => 0,
            on_time => 0,
            override => 0,
            name => $aux,
        };
    }
    return \%auxillaries;
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
    return $conf;
}
true;
