package App::RPi::EnvUI::DB;

use Data::Dumper;
use DateTime;
use DBI;
use RPi::WiringPi::Constant qw(:all);

our $VERSION = '0.24';

sub new {
    my ($class, %args) = @_;

    my $self = bless {%args}, $class;

    my $db_file = defined $self->{testing}
        ? 't/envui.db'
        : 'db/envui.db';

        warn "DB in test mode\n" if $self->{testing};

        $self->{db} = DBI->connect(
            # file db testing (events)
            "dbi:SQLite:dbname=$db_file",
            "",
            "",
            {RaiseError => 1}
        ) or die $DBI::errstr;

    return $self;
}
sub aux {
    my ($self, $aux_id) = @_;

    my $sth = $self->{db}->prepare(
        'SELECT * from aux WHERE id=?'
    );
    $sth->execute($aux_id);
    my $aux = $sth->fetchrow_hashref;
    return $aux;
}
sub auxs {
    my ($self) = @_;

    return $self->{db}->selectall_hashref(
        'SELECT * from aux',
        'id'
    );
}
sub config_control {
    my ($self, $want) = @_;

    my $sth = $self->{db}->prepare(
        'SELECT value FROM control WHERE id=?'
    );

    $sth->execute($want);
    return $sth->fetchrow_hashref->{value};
}
sub config_core {
    my ($self, $want) = @_;

    my $sth = $self->{db}->prepare(
        'SELECT * FROM core WHERE id = ?'
    );

    $sth->execute($want);
    return $sth->fetchrow_hashref->{value};
}
sub config_light {
    my ($self, $want) = @_;

    my $light = $self->{db}->selectall_hashref(
        'SELECT * FROM light',
        'id'
    );

    if (defined $want){
        return $light->{$want}{value};
    }
    else {
        return $light;
    }
}
sub config_water {
    my ($self, $want) = @_;

    my $water = $self->{db}->selectall_hashref(
        'SELECT * from water',
        'id'
    );

    if (defined $want){
        return $water->{$want}{value};
    }
    return $water;
}
sub env {
    my ($self) = @_;

    my $id = $self->last_id;

    my $sth = $self->{db}->prepare(
        'SELECT * FROM stats WHERE id=?'
    );

    $sth->execute($id);
    return $sth->fetchrow_hashref;
}
sub insert_env {
    my ($self, $temp, $hum) = @_;

    my $sth = $self->{db}->prepare(
        'INSERT INTO stats VALUES (?, CURRENT_TIMESTAMP, ?, ?)'
    );
    $sth->execute(undef, $temp, $hum);
}
sub last_id {
    my $self = shift;
    my $id_list = $self->{db}->selectrow_arrayref(
        "select seq from sqlite_sequence where name='stats';"
    );

    return defined $id_list ? $id_list->[0] : 0;
}
sub update {
    my ($self, $table, $col, $value, $where_col, $where_val) = @_;

    if (! defined $where_col){
        my $sth = $self->{db}->prepare("UPDATE $table SET $col=?");
        $sth->execute($value);
    }
    else {
        my $sth = $self->{db}->prepare(
            "UPDATE $table SET $col=? WHERE $where_col=?"
        );
        $sth->execute($value, $where_val);
    }
}

true;
__END__

=head1 NAME

App::RPi::EnvUI::DB - Database manager for App::RPi::EnvUI environment control
sysytem

=head1 SYNOPSIS
    use App::RPi::EnvUI::DB;

    my $db = App::RPi::EnvUI::DB->new;

    $db->method(@args);

=head1 DESCRIPTION

This is the database interaction class for L<App::RPi::EnvUI>. It abstracts
away the database work from the API and the webapp itself.

=head1 METHODS

=head2 new

Returns a new C<App::RPi::EnvUI::DB> object.

=head1 AUTHOR

Steve Bertrand, E<lt>steveb@cpan.org<gt>

=head1 LICENSE AND COPYRIGHT

Copyright 2016 Steve Bertrand.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See L<http://dev.perl.org/licenses/> for more information.

