package App::RPi::EnvUI::DB;

BEGIN {
    if (! exists $INC{'DateTime.pm'}){
        require DateTime;
        DateTime->import;
    }
    if (! exists $INC{'DBI.pm'}){
        require DBI;
        DBI->import;
    }
    if (! exists $INC{'Data/Dumper.pm'}){
        require Data::Dumper;
        Data::Dumper->import;
    }
    if (! exists $INC{'RPi/WiringPi/Constant.pm'}){
        require RPi::WiringPi::Constant;
        DateTime->import(qw(:all));
    }
}

our $VERSION = '0.26';

sub new {
    my ($class, %args) = @_;

    my $self = bless {%args}, $class;

    my $db_file = defined $self->{testing}
        ? 't/envui.db'
        : 'db/envui.db';

    $db_file = $self->{db_file} if defined $self->{db_file};

    warn "DB in test mode\n" if $self->{testing};

    $self->{db} = DBI->connect(
        "dbi:SQLite:dbname=$db_file",
        "",
        "",
        {
            #sqlite_use_immediate_transaction => 1,
            RaiseError => $self->{db_err},
            AutoCommit => 1
        }
    ) or die $DBI::errstr;

    return $self;
}
sub user {
    my ($self, $user) = @_;

    my $sth = $self->{db}->prepare(
        "SELECT * FROM auth WHERE user=?;"
    );

    $sth->execute($user);

    my $res = $sth->fetchrow_hashref();

    return ref $res ne 'HASH'
        ? {user => $user, pass => ''}
        : $res;
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

    if (! defined $where_col) {
        my $sth = $self->{db}->prepare( "UPDATE $table SET $col=?" );
        $sth->execute( $value );
    }
    else {
        my $sth = $self->{db}->prepare(
            "UPDATE $table SET $col=? WHERE $where_col=?"
        );
        $sth->execute( $value, $where_val );
    }
}
sub update_bulk {
    my ($self, $table, $col, $where_col, $data) = @_;

    my $sth = $self->{db}->prepare(
        "UPDATE $table SET $col=? WHERE $where_col=?"
    );

    for (@$data){
        $sth->execute(@$_);
    }
}
sub update_bulk_all {
    my ($self, $table, $col, $data) = @_;

    my $sth = $self->{db}->prepare(
        "UPDATE $table SET $col=?;"
    );

    $sth->execute(@$data);
}
sub config {
    $_[0]->{db}->begin_work;
}
sub commit {
    $_[0]->{db}->commit;
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

This is the database abstraction class for L<App::RPi::EnvUI>. It abstracts
away the database work from the API and the webapp itself.

=head1 METHODS

=head2 new(%args)

Returns a new L<App::RPi::EnvUI::DB> object. All parameters are sent in as a
hash structure.

Parameters:

    testing

Optional, Bool. C<1> to enable testing mode, C<0> to disable.

Default: C<0> (off)

=head2 user($user)

Fetches a user's information as found in the 'auth' database table.

Parameters:

    $user

Mandatory, String. The name of the user to fetch the password for.

Return: A hash reference containing the user's details.

=head2 aux($aux_id)

Fetches and returns a hash reference containing the details of an auxillary
channel.

Parameters:

    $aux_id

Mandatory, String. The string name of the auxillary channel (eg: C<aux1>)

Return: Hash reference (see above)

=head2 auxs

Fetches and returns a hash reference of hash references. The keys of the
top-level hash is a list of all the auxillary channel names, and each key has
a value of another hash reference, containing the details of that specific
aux channel. Takes no parameters.

=head2 config_control($want)

Fetches and returns the value of a specific C<control> configuration variable.

Parameters:

    $want

Mandatory, String. The name of the configuration variable to fetch the value
for.

Return: The value of the specified variable.

=head2 config_core($want)

Fetches and returns the value of a specific C<core> configuration variable.

Parameters:

    $want

Mandatory, String. The name of the configuration variable to fetch the value
for.

Return: The value of the specified variable.

=head2 config_light($want)

Fetches and returns either a specific C<light> configuration variable value, or
the entire C<light> configuration section.

Parameters:

    $want

Optional, String. If specified, we'll fetch only the value of this specific
configuration variable.

Return: Single scalar value if C<$want> is sent in, or a hash reference of the
entire configuration section where the keys are the variable names, and the
values are the configuration values.

=head2 config_water($want)

Works exactly the same as C<config_light()> above, but for the feeding
configuration.

=head2 env

Fetches and returns as a hash reference the last database entry of the C<stats>
(environment) database table. This hash contains the latest
temperature/humidity update, along with a timestamp and row ID. Takes no
parameters.

=head2 insert_env($temp, $humidity)

Inserts into the C<stats> database table a new row containing a row ID,
timestamp, and the values sent in with the parameters.

Parameters:

    $temp

Mandatory, Integer: The temperature.

    $humidity

Mandatory, Integer: The humidity.

=head2 last_id

Returns the ID of the last row entered into the C<stats> database table.

=head2 update($table, $column, $value, $where_col, $where_val)

Performs an update action on a given database table.

Parameters:

    $table

Mandatory, String: The name of the database table to act upon.

    $column

Mandatory, String: The column of the specified table to operate on.

    $value

Mandatory, depends: The value you want the column set to.

    $where_col

Optional, String: The name of the column to perform a C<WHERE> clause on. If
this is not sent in, we'll operate on all rows.

    $where_val

Optional, depends: The value of the column we're looking for in a C<WHERE>
clause. This value is ignored if C<$where_col> is not specified.

NOTE: If C<$where_col> is not sent in, we will operate on all rows in the
specified table.


=head1 AUTHOR

Steve Bertrand, E<lt>steveb@cpan.org<gt>

=head1 LICENSE AND COPYRIGHT

Copyright 2016 Steve Bertrand.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See L<http://dev.perl.org/licenses/> for more information.

