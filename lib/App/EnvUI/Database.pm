package App::EnvUI::Database;
use warnings;
use strict;

use Dancer2::Plugin::Database;

my $db_file = 'db/stats.db';
my $dbh = Dancer2::Plugin::Database::database({ driver => 'SQLite', database => $db_file });
my $table = 'stats';

sub insert {
    my ($temp, $hum) = @_;
    database->quick_insert($table, {
            id => '',
            datetime => '',
            temp => $temp,
            humidity => $hum,
        });
}
1;