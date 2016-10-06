use strict;
use warnings;
use Test::More;

my $tfile = 't/envui.db';
my $cfile = 't/envui.json';

for ($tfile, $cfile){
    if (-e $_){
        unlink $_ or die $!;
        is -e $_, 0, "$_ temp test file removed ok";
    }
}

done_testing();

