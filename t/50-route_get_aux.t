use strict;
use warnings;

use Data::Dumper;
use Test::More;

BEGIN {
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
    my $i = 0;
    for (1..8){
        my $res = $test->request(GET "/get_control/$_");
        ok $res->is_success, "/get_control/$_ request ok";
        my $ret = $res->content;
        is $ret, $values[$i], "${_}'s value is returned correctly";
        $i++;
    }
}

unset_testing();
done_testing();

