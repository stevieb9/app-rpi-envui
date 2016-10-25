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

my $m = Mock::Sub->new;
my $switch_sub = $m->mock('App::RPi::EnvUI::API::switch');

use FindBin;
use lib "$FindBin::Bin/../lib";

use HTTP::Request::Common;
use Plack::Test;
use App::RPi::EnvUI;


my $test = Plack::Test->create(App::RPi::EnvUI->to_app);

{ # /set_aux route
    my $p;

    # no params
    my $res = $test->request( GET "/set_aux" );
    like $res->content, qr/Not Found/, "/set_aux 404s if no params sent in";

    # one param
    $res = $test->request( GET "/set_aux/aux1" );
    like $res->content, qr/Not Found/, "/set_aux 404s if only one param sent";


    # good call
    $res = $test->request( GET "/set_aux/aux1/0" );
    is $res->is_success, 1, "with two valid params, /set_aux ok";
    $p = decode_json $res->content;

    is ref $p, 'HASH', "and is a href";
    is keys %$p, 2, "...and has proper key count";
    is exists $p->{state}, 1, "and state key exists";
    is $p->{state}, 0, "and state has correct default value";
    is exists $p->{aux}, 1, "and aux key exists";
    is $p->{aux}, 'aux1', "and aux has correct default value";

    # loop over all auxs

    for (1..8){
        my $id = "aux$_";

        my $state = aux($id)->{state};
        is $state, 0, "$id has proper default state";

        $res = $test->request( GET "/set_aux/$id/1" );
        is $res->is_success, 1, "/set_aux $id ok";

        is $switch_sub->called, 1, "switch() called for $id in /set_aux";
        $switch_sub->reset;
        is $switch_sub->called, 0, "switch() mock reset for next test";
    }

    $res = $test->request( GET "/set_aux/aux1" );
    like $res->content, qr/Not Found/, "/set_aux 404s if only one param sent";

    $res = $test->request( GET "/set_aux/aux1" );
    like $res->content, qr/Not Found/, "/set_aux 404s if only one param sent";
}

{ # not auth'd

    $ENV{UNIT_TEST} = 1;

    my $res = $test->request( GET "/set_aux/aux1/0" );
    is $res->is_success, 1, "with two valid params, /set_aux ok";
    my $p = decode_json $res->content;

    is ref $p, 'HASH', "not-auth return ok";
    like $p->{error}, qr/unauthorized request/, "...with sane error key/msg";

    delete $ENV{UNIT_TEST};
}

sub aux {
    my $res = $test->request(GET "/get_aux/$_[0]");
    my $perl = decode_json $res->content;

    return {
        aux => $perl->{id},
        state => $perl->{state},
    };
}

unset_testing();
db_remove();
unconfig();
done_testing();

