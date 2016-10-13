package App::RPi::EnvUI::Auth;

use warnings;
use strict;

use Moo;
with 'Dancer2::Plugin::Auth::Extensible::Role::Provider';

sub authenticate_user {
    my ($self, $username, $password) = @_;
    my $user_details = $self->get_user_details($username) or return;
    my $auth = $self->match_password($password, $user_details->{pass});
    return $auth;
}

sub get_user_details {
    my ($self, $username) = @_;
    my $user = {pass => 'hi', user => 'steve'};
    return $user;
}

sub get_user_roles {
    return;
}
1;