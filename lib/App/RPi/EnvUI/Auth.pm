package App::RPi::EnvUI::Auth;

use warnings;
use strict;

use App::RPi::EnvUI::DB;
use Moo;
with 'Dancer2::Plugin::Auth::Extensible::Role::Provider';

our $VERSION = '0.25';

sub authenticate_user {
    my ($self, $username, $password) = @_;
    my $pw = $self->get_user_details($username) or return;
    my $auth = $self->match_password($password, $pw);
    return $auth;
}

sub get_user_details {
    my ($self, $user) = @_;
    my $api = App::RPi::EnvUI::API->new;

    return $api->user($user);
}

sub get_user_roles {
    return;
}
1;