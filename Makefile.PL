use strict;
use warnings;

use ExtUtils::MakeMaker;
use File::Copy;

my $eumm_version = $ExtUtils::MakeMaker::VERSION;
$eumm_version =~ s/_//;

my $sep = $^O =~ /MSWin/ ? ';' : ':';

if (! grep { -x "$_/sqlite3" } split /$sep/, $ENV{PATH}) {
    die "sqlite3 must be installed to continue\n";
}

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
        'Async::Event::Interval' => 0,
        'Dancer2'     => 0.203001,
        'Dancer2::Plugin::Database' => 0,
        'DBD::SQLite' => 0,
        'DateTime'  => 0,
        'JSON::XS' => 0,
        'RPi::DHT11' => '1.00',
        'RPi::WiringPi::Constant' => '0.02',
        'Test::More' => 0,
        'WiringPi::API' => '1.04',
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'wui-*' },
);
