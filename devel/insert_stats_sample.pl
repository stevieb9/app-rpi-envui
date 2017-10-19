use strict;
use warnings;

use App::RPi::EnvUI::DB;

my $db = App::RPi::EnvUI::DB->new(testing => 1);

for (0..6000){
    $db->insert_env(5, 5);
}
