package App::EnvUI;

use Dancer2;
use Dancer2::Plugin::Database;

our $VERSION = '0.1';

get '/' => sub {
        database->quick_insert('stats', {
                temp => 5,
                humidity => 10,
            }
        );
        return template 'main';
    };

get '/call/:aux/:state' => sub {
        my $aux = params->{aux};
        my $state = params->{state};
        return to_json {state => $state};
    };

true;
