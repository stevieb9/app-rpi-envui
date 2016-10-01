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

# copy initial db and conf file

if (! -e 'db/envui.db'){
    print "copying default db...\n";
    copy 'src/envui-dist.db', 'db/envui.db' or die $!;
}
if (! -e 'config/envui.json'){
    print "copying default config...\n";
    copy 'src/envui-dist.json', 'config/envui.json' or die $1;
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
