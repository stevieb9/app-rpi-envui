use warnings;
use strict;

system("fatpack trace bin/app.pl");

system("fatpack packlists-for `cat fatpacker.trace` > packlists");

system("fatpack tree `cat packlists`");

system("(fatpack file; cat bin/app.pl) > bin/envui");

unlink 'fatpacker.trace' or warn "can't delete fatpacker.trace\n";

unlink 'packlists' or warn "can't delete packlists file\n";

rmdir 'fatlib' or warn "can't remove fatlib directory\n";


