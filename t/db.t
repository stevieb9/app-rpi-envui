use strict;
use warnings;

BEGIN {
    use lib 't/';
    use TestBase;
    db_remove();
    db_create();
}

use App::RPi::EnvUI::DB;
use Data::Dumper;
use Test::More;

my $db = App::RPi::EnvUI::DB->new(testing => 1);

subtest 'object' => sub {
    is ref $db, 'App::RPi::EnvUI::DB', "new() returns a proper object";
};

# auxs()

subtest 'auxs()' => sub {

        my $auxs = $db->auxs;

        is ref $auxs, 'HASH', "auxs() returns a href";
        is keys %$auxs, 8, "auxs(): proper number of auxs returned";

        for (keys %$auxs) {
            like $_, qr/aux\d{1}/, "auxs() $_ has a 'auxN' name";
        }

        for (1..8){
            my $name = "aux$_";
            my $aux = $auxs->{$name};

            if ($name eq 'aux1' || $name eq 'aux2'){
                is $aux->{pin}, 0, "$name aux has proper pin default";
            }
            else {
                is $aux->{pin}, -1, "$name aux has proper pin default";
            }
            is $aux->{state}, 0, "$name has proper default state";
            is $aux->{override}, 0, "$name has proper default override";
            is $aux->{on_time}, 0, "$name has proper default on_time";
        }
    };

subtest 'aux()' => sub {
    for (1..8){
        my $name = "aux$_";
        my $aux = $db->aux($name);
        is ref $aux, 'HASH', "aux() returns an href for $name";
        is keys %$aux, 6, "$name has proper count keys";
    }
};
db_remove();
done_testing();

