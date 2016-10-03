package TestBase;
use warnings;
use strict;

use Exporter qw(import);
our @EXPORT = qw(
    set_testing
    unset_testing
    db_create
    db_remove
);

use File::Copy;

my $orig_db = 'src/envui-dist.db';
my $test_db = 't/envui.db';
my $journal = 't/envui.db-journal';

sub db_create {
    unlink $test_db or die if -e $test_db;
    copy $orig_db, $test_db or die $!;
}
sub db_remove {
    unlink $test_db if -e $test_db;
    unlink $journal if -e $journal;
}
sub set_testing {
    open my $fh, '>', 't/testing.lck' or die $!;
    print $fh '1';
    close $fh;
}
sub unset_testing {
    unlink 't/testing.lck' or die if -e 't/testing.lck';
}

