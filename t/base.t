use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../lib";

use App::EnvUI;
use HTTP::Request::Common;
use Plack::Test;
use Test::More;


my $test = Plack::Test->create( App::EnvUI->to_app );

subtest 'Sample test' => sub {
        my $res = $test->request( GET '/' );
        ok( $res->is_success, 'Successful request' );
        is( $res->content, '{}', 'Empty response back' );
    };

done_testing();

