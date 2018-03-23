package Nick::Audio::ALSA;

use strict;
use warnings;

use XSLoader;
use Carp;

our( $VERSION, %DEFAULTS );

=pod

=head1 NAME

Nick::Audio::ALSA - Interface to the asound library.

=head1 SYNOPSIS

    use Nick::Audio::ALSA;
    use Time::HiRes 'sleep';

    my $sample_rate = 22050;
    my $hz = 441;
    my $duration = 7;

    my $buff_in;
    my $alsa = Nick::Audio::ALSA -> new(
        'sample_rate'   => $sample_rate,
        'channels'      => 1,
        'device'        => 'default',
        'buffer_in'     => \$buff_in,
        'blocking'      => 0,
        'buffer_secs'   => .5
    );

    # make a sine wave block of data
    my $pi2 = 8 * atan2 1, 1;
    my $steps = $sample_rate / $hz;
    my( $audio_block, $i );
    for ( $i = 0; $i < $steps; $i++ ) {
        $audio_block .= pack 's', 32767 * sin(
            ( $i / $sample_rate ) * $pi2 * $hz
        );
    }
    my $audio_len = length $audio_block;
    $steps = ( $duration * $sample_rate * 2 ) / $audio_len;

    for ( $i = 0; $i < $steps; $i++ ) {
        while (
            $alsa -> can_write() < $audio_len
        ) {
            sleep .1;
        }
        $buff_in = $audio_block;
        $alsa -> play_nb();
    }
    $alsa -> flush();


=head1 METHODS

=head2 new()

Instantiates a new Nick::Audio::ALSA object.

Arguments are interpreted as a hash and all are optional.

=over 2

=item device

ALSA device name (e.g. hw:1,0)

Default: B<default>

=item sample_rate

Sample rate of PCM data in B<buffer_in>.

Default: B<44100>

=item channels

Number of audio channels in PCM data in B<buffer_in>.

Default: B<2>

=item buffer_in

Scalar that'll be used to pull PCM data from.

=item blocking

Whether writing audio will block.

Default: B<true>

=item buffer_secs

How many seconds of audio ALSA should buffer.

Default: B<0>

=back

=head2 play()

Sends PCM audio data from B<buffer_in> to ALSA.

If B<blocking> is set to false, it will be changed to true.

=head2 play_nb()

Sends PCM audio data from B<buffer_in> to ALSA.

If B<blocking> is set to true, it will be changed to false.

=head2 flush()

Blocks while ALSA is drained of audio.

=head2 can_write()

Returns the number of bytes that can be written to ALSA.

=cut

BEGIN {
    $VERSION = '0.01';
    XSLoader::load 'Nick::Audio::ALSA' => $VERSION;
    %DEFAULTS = (
        'sample_rate'   => 44100,
        'channels'      => 2,
        'device'        => 'default',
        'buffer_in'     => do{ my $x = '' },
        'blocking'      => 1,
        'buffer_secs'   => 0
    );
}

sub new {
    my( $class, %settings ) = @_;
    return Nick::Audio::ALSA -> new_xs( map
        exists( $settings{$_} )
        ? $settings{$_}
        : $DEFAULTS{$_},
        qw( device sample_rate channels buffer_in blocking buffer_secs )
    );
}

1;
