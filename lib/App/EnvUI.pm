package App::EnvUI;

use Async::Event::Interval;
use Dancer2;
use Dancer2::Plugin::Database;

our $VERSION = '0.1';

my $auxs = _generate_aux();

my $event = Async::Event::Interval->new(
    5,
    sub {
        my $temp = int(rand(100));
        my $humidity = int(rand(100));
        insert($temp, $humidity);
    }
);

$event->start;

get '/' => sub {
        my $e = $event;
        return template 'main';
    };

get '/get_aux/:aux' => sub {
        my $aux = params->{aux};
        return _aux_state($aux);
    };

get '/set_aux/:aux/:state' => sub {
        my $aux = params->{aux};
        my $state = _bool(params->{state});

        _aux_state($aux, $state);

        my $override = $state ? 1 : 0;
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
sub _generate_aux {
    # generate the auxillary control objects

    my %auxillaries;

    for (1..4){
        my $name = "aux$_";

        $auxillaries{$name} = {
            state => 0,
            on_time => 0,
            override => 0,
            name => $name,
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

true;
