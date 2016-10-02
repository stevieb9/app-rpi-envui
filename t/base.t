use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../lib";

use Test::More;

BEGIN {
    if (! $ENV{PI_BOARD}){
        plan skip_all => "not on a raspberry pi board\n";
    }
}
use App::RPi::EnvUI;
use HTTP::Request::Common;
use Plack::Test;



my $test = Plack::Test->create( App::RPi::EnvUI->to_app );

{
        my $res = $test->request( GET '/' );
        ok( $res->is_success, 'Successful request' );
        is( $res->content, '{}', 'Empty response back' );
    };

done_testing();

