use strict;
use warnings;

BEGIN {
    use lib 't/';
    use TestBase;
    config();
    db_create();
}

use App::RPi::EnvUI::API;
use App::RPi::EnvUI::DB;
use Crypt::SaltedHash;
use Data::Dumper;
use Mock::Sub no_warnings => 1;
use Test::More;

my $api = App::RPi::EnvUI::API->new(
    testing => 1,
    config_file => 't/envui.json',
    debug_level => 7
);

is ref $api, 'App::RPi::EnvUI::API', "new() returns a proper object";
is $api->testing, 1, "testing param to new() ok";
is $api->debug_level, 7, "setting debug_level param in API->new() ok";
is $api->debug_level(6), 6, "setting API->debug_level(6) ok";

unconfig();
db_remove();

done_testing();

