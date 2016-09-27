use strict;
use warnings;

use ExtUtils::MakeMaker;
use File::Copy;

# Normalize version strings like 6.30_02 to 6.3002,
# so that we can do numerical comparisons on it.
my $eumm_version = $ExtUtils::MakeMaker::VERSION;
$eumm_version =~ s/_//;

if (! -e 'db/envui.db'){
    copy 'src/envui.db', 'db/' or die $!;
}

WriteMakefile(
    NAME                => 'App::EnvUI',
    AUTHOR              => q{Steve Bertrand <steveb@cpan.org>},
    VERSION_FROM        => 'lib/App/EnvUI.pm',
    ABSTRACT            => '',
    ($eumm_version >= 6.3001
        ? ('LICENSE'=> 'perl')
        : ()),
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More' => 0,
        'YAML'       => 0,
        'Dancer2'     => 0.203001,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'wui-*' },
);
