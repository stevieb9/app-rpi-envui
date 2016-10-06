package App::RPi::EnvUI::Event;

use Async::Event::Interval;
use Data::Dumper;

our $VERSION = '0.22';

sub new {
    return bless {}, shift;
}
sub env_to_db {
    my ($self, $api) = @_;

    my $event = Async::Event::Interval->new(
        $api->_config_core('event_fetch_timer'),
        sub {
            my ($temp, $hum) = $api->read_sensor;
            $api->env($temp, $hum);
        },
    );

    return $event;
}
sub env_action {
    my ($self, $api) = @_;

    my $event = Async::Event::Interval->new(
        $api->_config_core('event_action_timer'),
        sub {
            my $t_aux = $api->env_temp_aux;
            my $h_aux = $api->env_humidity_aux;

            $api->action_temp($t_aux, $api->temp);
            $api->action_humidity($h_aux, $api->humidity);
            $api->action_light($api->_config_light)
              if $api->_config_light('enable');
        }
    );

    return $event;
}
1;
__END__

=head1 NAME

App::RPi::EnvUI::Event - Asynchronous events for the Perl portion of
L<App::RPi::EnvUI>

=head1 SYNOPSIS

    use App::RPi::EnvUI::API;
    use App::RPi::EnvUI::Event;

    my $api = App::RPi::EnvUI::API->new;
    my $events = App::RPi::EnvUI::Event->new;

    my $env_to_db_event  = $events->env_to_db($api);
    my $env_action_event = $events->env_action($api);

    $env_to_db_event->start;
    $env_action_event->start;

=head1 DESCRIPTION

This is a helper module for L<App::RPi::EnvUI>, which contains the scheduled
asynchronous Perl events on the server side of the webapp.

=head1 METHODS

=head2 new

Returns a new C<App::RPi::EnvUI::Event> object.

=head2 env_to_db($api)

Parameter:

    $api

Mandatory. An instance of the L<App::RPi::EnvUI::API> class.

Returns the event that updates the 'stats' environment database table.

=head2 env_action($api)

Parameter:

    $api

Mandatory. An instance of the L<App::RPi::EnvUI::API> class.

Returns the event that enables/disables the GPIO pins associated with the
environment.

=head1 SEE ALSO

L<Async::Event::Interval>

=head1 AUTHOR

Steve Bertrand, E<lt>steveb@cpan.org<gt>

=head1 LICENSE AND COPYRIGHT

Copyright 2016 Steve Bertrand.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See L<http://dev.perl.org/licenses/> for more information.

