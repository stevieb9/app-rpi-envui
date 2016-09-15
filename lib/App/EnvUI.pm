package App::EnvUI;

use Dancer2;

our $VERSION = '0.1';

get '/' => sub {
        return template 'main';
    };

get '/call/:aux/:state' => sub {
        my $aux = params->{aux};
        my $state = params->{state};
        return to_json {state => $state};
    };

true;

