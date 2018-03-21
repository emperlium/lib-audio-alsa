use strict;
use warnings;

use Test::More tests => 2;

use Time::HiRes 'sleep';

use_ok( 'Nick::Audio::ALSA' );

my $sample_rate = 22050;
my $hz = 441;
my $duration = 2;

my $buff_in;
my $alsa = Nick::Audio::ALSA -> new(
    'sample_rate'   => $sample_rate,
    'channels'      => 1,
    'device'        => 'default',
    'buffer_in'     => \$buff_in,
    'blocking'      => 0,
    'buffer_secs'   => .5
);

ok( defined( $alsa ), 'new()' );

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
