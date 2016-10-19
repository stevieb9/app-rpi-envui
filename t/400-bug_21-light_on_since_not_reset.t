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
use Test::More;


my $api = App::RPi::EnvUI::API->new(
    testing => 1,
    config_file => 't/envui.json'
);

{ # _reset()

    $api->db()->update('light', 'value', 55, 'id', 'on_since');
    is $api->_config_light('on_since'), 55, "light on_since is set for testing";

    $api->_reset_light;

    is $api->_config_light('on_since'), 0, "light on_since is reset on _reset()";

}

unconfig();
db_remove();
done_testing();

