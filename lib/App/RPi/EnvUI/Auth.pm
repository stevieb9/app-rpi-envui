package App::RPi::EnvUI::Auth;

use warnings;
use strict;

use App::RPi::EnvUI::API;
use App::RPi::EnvUI::DB;
use Moo;
with 'Dancer2::Plugin::Auth::Extensible::Role::Provider';

our $VERSION = '0.99_01';

my $api = App::RPi::EnvUI::API->new;
my $log = $api->log->child('Auth');

sub authenticate_user {
    my ($self, $user, $pass) = @_;

    my $log = $log->child('authenticate_user');
    $log->_6("attempting to authenticate user $user");

    my $user_details = $self->get_user_details($user) or return;
    my $auth = $self->match_password($pass, $user_details->{pass});
    return $auth;
}
sub get_user_details {
    my ($self, $user) = @_;
    my $log = $log->child('get_user_details');
    $log->_6("fetching user details for user $user");
    App::RPi::EnvUI::API->new->user($user);
}
sub get_user_roles {
    return;
}
1;
