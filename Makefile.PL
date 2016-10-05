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

sub MY::postamble {
return <<EOF;

install:: all local

local:

	rm -rf ~/envui
	mkdir ~/envui

	mkdir ~/envui/bin
	cp bin/* ~/envui/bin

	mkdir ~/envui/config
	cp config/* ~/envui/config

	mkdir ~/envui/db
	cp db/* ~/envui/db

	mkdir ~/envui/public
	mkdir ~/envui/public/js
	mkdir ~/envui/public/css
	cp public/js/* ~/envui/public/js
	cp public/css/* ~/envui/public/css

	mkdir ~/envui/src
	cp src/* ~/envui/src
	mkdir ~/envui/views
	cp views/* ~/envui/views

EOF
}

WriteMakefile(
    NAME                => 'App::RPi::EnvUI',
    AUTHOR              => q{Steve Bertrand <steveb@cpan.org>},
    VERSION_FROM        => 'lib/App/RPi/EnvUI.pm',
    ABSTRACT            => '',
    ($eumm_version >= 6.3001
        ? ('LICENSE'=> 'perl')
        : ()),
    META_MERGE => {
        'meta-spec' => { version => 2 },
        resources   => {
            bugtracker => {
                web => 'https://github.com/stevieb9/app-rpi-envui/issues',
            },
            repository => {
                type => 'git',
                url => 'https://github.com/stevieb9/app-rpi-envui.git',
                web => 'https://github.com/stevieb9/app-rpi-envui',
            },
        },
    },
    PL_FILES            => {},
    PREREQ_PM => {
        'Async::Event::Interval' => 0,
        'Dancer2'     => 0.203001,
        'Dancer2::Plugin::Database' => 0,
        'DBD::SQLite' => 0,
        'DateTime'  => 0,
        'JSON::XS' => 0,
        'Mock::Sub' => 0,
        'Plack::Test' => 0,
        'RPi::DHT11' => '1.00',
        'RPi::WiringPi::Constant' => '0.02',
        'Test::More' => 0,
        'WiringPi::API' => '1.04',
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'wui-*' },
);
