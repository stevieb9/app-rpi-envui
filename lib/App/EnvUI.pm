package App::EnvUI;

use Dancer2;
use Dancer2::Plugin::Database;

our $VERSION = '0.1';

my $id = _get_last_id();

get '/' => sub {
        insert(10,20);
        return template 'main';
    };

get '/call/:aux/:state' => sub {
        my $aux = params->{aux};
        my $state = params->{state};
        return to_json {state => $state};
    };

get '/fetch' => sub {
        my $data = fetch();
        open my $fh, '>', 'a.txt' or die $!;
        print $fh $data->{temp};
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
    $id++;
}
sub fetch {
    my $row = database->quick_select(
        stats => {id => $id}, ['temp', 'humidity']
    );
    return $row;
}
sub _get_last_id {
    # fetches and returns the most recent row id in the DB

    my @rows = database->quick_select('stats', {}, ['id']);
    return $rows[-1]->{id};
}
true;
