use strict;
use warnings;

use Mock::Sub no_warnings => 1;
use Test::More;

BEGIN {
    #FIXME: temporarily turning test off until we fix the temp() mock call issue

#    plan skip_all => "need a fix for mocking subs due to errors...\n";
    use lib 't/';
    use TestBase;
    set_testing();


}

use FindBin;
use lib "$FindBin::Bin/../lib";

use HTTP::Request::Common;
use Plack::Test;
use App::RPi::EnvUI;

my $test = Plack::Test->create(App::RPi::EnvUI->to_app);

{
    my $res = $test->request(GET '/');
    ok $res->is_success, 'Successful request';
    like $res->content, qr/Temperature/, 'front page loaded ok';
}

#unset_testing();
done_testing();

