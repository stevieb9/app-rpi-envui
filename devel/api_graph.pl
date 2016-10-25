use warnings;
use strict;

use App::RPi::EnvUI::API;
use Data::Dumper;

my $api = App::RPi::EnvUI::API->new(testing => 1);

my $aref = $api->graph_data;

print Dumper $aref;

