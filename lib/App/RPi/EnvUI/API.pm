package App::RPi::EnvUI::API;

use App::RPi::EnvUI::DB;
use Async::Event::Interval;
use Data::Dumper;
use DateTime;
use JSON::XS;
use RPi::DHT11;
use RPi::WiringPi::Constant qw(:all);
use WiringPi::API qw(:perl);

our $VERSION = '0.2';

my $db = App::RPi::EnvUI::DB->new;

sub new {
    return bless {}, shift;
}
sub switch {
    my $self = shift;
    my $aux_id = shift;

    my $state = $self->aux_state($aux_id);
    my $pin = $self->aux_pin($aux_id);

    if ($pin != 0 && $pin != -1){
        $state
            ? write_pin($pin, HIGH)
            : write_pin($pin, LOW);
    }
}
sub action_light {
    my $self = shift;
    my $light = shift;
    my $now = DateTime->now(time_zone => $self->_config_core('time_zone'));

    my ($on_hour, $on_min) = split /:/, $light->{on_at};

    if ($now->hour > $on_hour || ($now->hour == $on_hour && $now->minute >= $on_min)){
        $db->update('light', 'value', time(), 'id', 'on_since');
        $self->aux_state(_config('light_aux'), ON);

        #
        # turn light on here!
        #
    }
    if ($self->_config_light('on_since')){
        my $on_since = $self->_config_light('on_since');
        my $on_hours = $self->_config_light('on_hours');
        my $on_secs = $on_hours * 60 * 60;

        my $time = time();
        my $remaining = $time - $on_since;

        if ($remaining >= $on_secs){
            $db->update('light', 'value', 0, 'id', 'on_since');
            $self->aux_state(_config('light_aux'), OFF);

            #
            # turn light off here!
            #
        }
    }
}
sub action_humidity {
    my $self = shift;
    my ($aux_id, $humidity) = @_;

    my $min_run = $self->_config('humidity_aux_on_time');
    my $limit = $self->_config('humidity_limit');

    my $x = $self->aux_override($aux_id);

    if (! $self->aux_override($aux_id)) {
        if ($humidity < $limit && $self->aux_time( $aux_id ) == 0) {
            $self->aux_state( $aux_id, HIGH );
            $self->aux_time( $aux_id, time );
        }
        elsif ($humidity >= $limit && $self->aux_time( $aux_id ) >= $min_run) {
            $self->aux_state( $aux_id, LOW );
            $self->aux_time( $aux_id, 0 );
        }
    }
}
sub action_temp {
    my $self = shift;
    my ($aux_id, $temp) = @_;
    my $limit = $self->_config('temp_limit');
    my $min_run = $self->_config('temp_aux_on_time');

    if (! $self->aux_override($aux_id)){
        if ($temp >= $limit && $self->aux_time($aux_id) == 0){
            $self->aux_state($aux_id, HIGH);
            $self->aux_time($aux_id, time);
        }
        elsif ($temp < $limit && $self->aux_time($aux_id) >= $min_run){
            $self->aux_state($aux_id, LOW);
            $self->aux_time($aux_id, 0);
        }
    }
}
sub aux {
    my $self = shift;
    my $aux_id = shift;

    my $aux = $db->aux($aux_id);
    return $aux;
}
sub auxs {
    my $self = shift;
    return $db->auxs;
}
sub aux_id {
    my $self = shift;
    return $_[0]->{id};
}
sub aux_state {
    my $self = shift;
    # maintains the auxillary state (on/off)

    my ($aux_id, $state) = @_;
    if (defined $state){
        $db->update('aux', 'state', $state, 'id', $aux_id);
    }
    return $self->aux($aux_id)->{state};
}
sub aux_time {
    my $self = shift;
    # maintains the auxillary state (on/off)

    my ($aux_id, $time) = @_;

    if (defined $time) {
        $db->update('aux', 'on_time', $time, 'id', $aux_id);
    }

    my $on_time = $self->aux($aux_id)->{on_time};
    return $on_time == 0 ? 0 : time - $on_time;
}
sub aux_override {
    my $self = shift;
    # sets a manual override flag if an aux is turned on manually (via button)

    my ($aux_id, $override) = @_;

    if (defined $override){
        $db->update('aux', 'override', $override, 'id', $aux_id);
    }
    return $self->aux($aux_id)->{override};
}
sub aux_pin {
    my $self = shift;
    # returns the auxillary's GPIO pin number

    my ($aux_id, $pin) = @_;
    if (defined $pin){
        $db->update('aux', 'pin', $pin, 'id', $aux_id);
    }
    return $self->aux($aux_id)->{pin};
}
sub _config {
    my $self = shift;
    my $want = shift;
    return $db->config($want);
}
sub _config_core {
    my $self = shift;
    my $want = shift;
    return $db->config_core($want);
}
sub _config_light {
    my $self = shift;
    my $want = shift;

    my $light = $db->config_light;

    my %conf;

    for (keys %$light) {
        $conf{$_} = $light->{$_}{value};
    }

    my ($on_hour, $on_min) = split /:/, $conf{on_at};

    my $now = DateTime->now(time_zone => $db->config_core('time_zone'));
    my $light_on = $now->clone;

    $light_on->set_hour($on_hour);
    $light_on->set_minute($on_min);

    my $dur = $now->subtract_datetime($light_on);
    $conf{on_in} = $dur->hours . ' hrs, ' . $dur->minutes . ' mins';

    if (defined $want){
        return $conf{$want};
    }

    return \%conf;
}
sub _config_water {
    my $self = shift;
    my $water = $db->config_water;

    my %conf;

    for (keys %$water){
        $conf{$_} = $water->{$_}{value};
    }

    return \%conf;
}
sub env {
    my $self = shift;
    my ($temp, $hum) = @_;

    if (defined $temp){
        $db->insert_env($temp, $hum);
    }

    my $id = $db->last_id;

    return $db->env;
}
sub temp {
    my $self = shift;
    return $self->env()->{temp};
}
sub humidity {
    my $self = shift;
    return $self->env()->{humidity};
}
sub env_humidity_aux {
    my $self = shift;
    return $self->_config('humidity_aux');
}
sub env_temp_aux {
    my $self = shift;
    return $self->_config('temp_aux');
}
sub _parse_config {
    my $self = shift;
    my $json;
    {
        local $/;
        open my $fh, '<', 'config/envui.json' or die $!;
        $json = <$fh>;
    }
    my $conf = decode_json $json;

    # auxillary channels

    for (1..8){
        my $aux_id = "aux$_";
        my $pin = $conf->{$aux_id}{pin};
        $self->aux_pin($aux_id, $pin);
    }

    # aux

    for my $directive (keys %{ $conf->{aux} }){
        $db->update('aux', 'value', $conf->{aux}{$directive}, 'id', $directive);
    }

    # environment control

    for my $directive (keys %{ $conf->{control} }){
        $db->update(
            'control', 'value', $conf->{control}{$directive}, 'id', $directive
        );
    }

    # core configuration

    for my $directive (keys %{ $conf->{core} }){
        $db->update('core', 'value', $conf->{core}{$directive}, 'id', $directive);
    }

    # light config

    for my $directive (keys %{ $conf->{light} }){
        $db->update('light', 'value', $conf->{light}{$directive}, 'id', $directive);
    }

    # water config

    for my $directive (keys %{ $conf->{water} }){
        $db->update('water', 'value', $conf->{water}{$directive}, 'id', $directive);
    }

}
sub _reset {
    my $self = shift;
    # reset dynamic db attributes
    for (1..8){
        my $aux_id = "aux$_";
        $self->aux_time($aux_id, 0);
    }
}
sub _bool {
    my $self = shift;
    # translates javascript true/false to 1/0

    my $bool = shift;
    return $bool eq 'true' ? 1 : 0;
}

true;
__END__

=head1 NAME

App::RPi::EnvUI - One-page asynchronous grow room environment control web application

=head1 SYNOPSIS

    sudo plackup ./envui

=head1 DESCRIPTION

This distribution is alpha. It does not install the same way most CPAN modules
install, and has some significant requirements Most specifically, the
L<wiringPi|http://wiringpi.com> libraries, and the fact it can only run on a
Raspberry Pi. To boot, you have to have an elaborate electrical relay
configuration set up etc.

Right now, I'm testing an L<App::FatPacker> install method, where the packed 
web app is bundled into a single file called C<envui>, and placed in your
current working directory. See L</SYNOPSIS> for running the app. I doubt this
will work as expected on my first try.

It's got no tests yet, and barely any documentation. It's only here so I can
begin testing the installation routine.

This is my first web app in many, many years, so the technologies (jQuery,
L<Dancer2> etc) are brand new to me, so as I go, I'll be refactoring heavily as
I continue to learn.

At this stage, after I sort the installer, I will be focusing solely on tests.
After tests are done, I'll clean up the code (refactor), then complete the
existing non-finished functionality, and add the rest of the functionality I
want to add.

I'll then add pictures, diagrams and schematics of my physical layout of the Pi
all electrical components, and the electrical circuits.

=head1 WHAT IT DOES

Reads temperature and humidity data via a hygrometer sensor through the
L<RPi::DHT11> distribution.

It then allows, through a one-page asynchronous web UI to turn on and off
120/240v devices through buttons, timers and reached threshold limits.

For example. We have a max temperature limit of 80F. We assign an auxillary
(GPIO pin) that is connected to a relay to a 120v exhaust fan. Through the
configuration file, we load the temp limit, and if the temp goes above it, we
enable the fan via the GPIO pin.

To prevent the fan from going on/off repeatedly if the temp hovers at the limit,
a minimum "on time" is also set, so by default, if the fan turns on, it'll stay
on for 30 minutes, no matter if the temp drops back below the limit.

Each auxillary has a manual override switch in the UI, and if overridden in the
UI, it'll remain in the state you set.

We also include a grow light scheduler, so that you can connect your light, set
the schedule, and we'll manage it. The light has an override switch in the UI,
but that can be disabled to prevent any accidents.

...manages auto-feeding too, but that's not any where near complete yet.


=head1 AUTHOR

Steve Bertrand, E<lt>steveb@cpan.org<gt>

=head1 LICENSE AND COPYRIGHT

Copyright 2016 Steve Bertrand.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See L<http://dev.perl.org/licenses/> for more information.

