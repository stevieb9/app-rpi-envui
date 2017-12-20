use strict;
use warnings;

use Data::Dumper;
use JSON::XS;
use Test::More;

BEGIN {
    use lib 't/';
    use TestBase;
    config();
    set_testing();
    db_create();
}

use Mock::Sub no_warnings => 1;

#my $m = Mock::Sub->new;
#my $switch_sub = $m->mock('App::RPi::EnvUI::API::switch');

use FindBin;
use lib "$FindBin::Bin/../lib";

use App::RPi::EnvUI::API;
use HTTP::Request::Common;
use Plack::Test;
use App::RPi::EnvUI;

my $api = App::RPi::EnvUI::API->new(testing => 1);
my $test = Plack::Test->create(App::RPi::EnvUI->to_app);

{ # /set_aux_override route
    my $p;

    # no params
    my $res = $test->request( GET "/set_aux_override" );
    like $res->content, qr/Not Found/, "/set_aux_override 404s if no params sent in";

    # one param
    $res = $test->request( GET "/set_aux_override/aux1" );
    like $res->content, qr/Not Found/, "/set_aux_override 404s if only one param sent";

    # good call
    $res = $test->request( GET "/set_aux_override/aux1/0" );
    is $res->is_success, 1, "with two valid params, /set_aux_override ok";
    $p = decode_json $res->content;
  
    is ref $p, 'HASH', "and is a href";
    is keys %$p, 2, "...and has proper key count";
    is exists $p->{override}, 1, "and override key exists";
    is $p->{override}, 0, "and override has correct default value";
    is exists $p->{aux}, 1, "and aux key exists";
    is $p->{aux}, 'aux1', "and aux has correct default value";
    
    # loop over all auxs

    for (1..8){
        my $id = "aux$_";

        my $override = aux($id)->{override};
        is $override, 0, "$id has proper default override";

        $res = $test->request( GET "/set_aux_override/$id/1" );
        is $res->is_success, 1, "/set_aux_override $id ok";
    }
}

sub aux {
    my $res = $test->request(GET "/get_aux/$_[0]");
    my $perl = decode_json $res->content;

    return {
        aux => $perl->{id},
        state => $perl->{state},
        override => $perl->{override}
    };
}

unset_testing();
db_remove();
unconfig();
done_testing();

