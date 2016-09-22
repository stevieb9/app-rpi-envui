package App::EnvUI::Database;
use warnings;
use strict;

use Dancer2;
use Dancer2::Plugin::Database;

sub insert {
    my ($temp, $hum) = @_;
    Dancer2::Plugin::Database::database->quick_insert(stats => {
            temp => $temp,
            humidity => $hum,
        }
    );
}
1;