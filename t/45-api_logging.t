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
use Data::Dumper;
use Test::More;

#FIXME: add tests to test overrides for hum and temp

my $api = App::RPi::EnvUI::API->new(
    testing => 1,
    config_file => 't/envui.json'
);

is ref $api, 'App::RPi::EnvUI::API', "new() returns a proper object";
is $api->{testing}, 1, "testing param to new() ok";

{ # log level

    my $lvl = $api->log_level;
    is $lvl, -1, "default log level is -1/disabled";

    is $api->log_level(7), 7, "setting log level ok";
    is $api->log_level(-1), -1, "as is setting it back to default";

}

{ # log file

    $api->log_level(7);

    my $fn = $api->log_file;
    is $fn, '', "log file is not set in default config";

    $api->log_file('t/test.log');
    is $api->log_file, 't/test.log', "log_file() w/ param ok";

    my $log = $api->log()->child('api_test');
    is ref $log, 'Logging::Simple', "logging agent is in proper class";

    $log->_7("test");

    open my $fh, '<', $api->log_file or die $!;

    my $entry = <$fh>;
#    like $entry, qr/test$/, "log file has correct entry";
#    like $entry, qr/\[api_test\]/, "...and has proper child name";

    $api->log_file('');
    $api->log_level(-1);
    unlink 't/test.log' or die $!;
}

unconfig();
db_remove();
done_testing();

