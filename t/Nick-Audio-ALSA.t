use strict;
use warnings;

use Test::More tests => 2;

use Time::HiRes 'sleep';

use_ok( 'Nick::Audio::ALSA' );

my $sample_rate = 44010;
my $hz = 441;
my $duration = 2;
my $channels = 2;
my $bit_depth = 16;
my $pack = 's';
#my $bit_depth = 32;
#my $pack = 'l';

my $buff_in;
my %set = (
    'sample_rate'   => $sample_rate,
    'channels'      => $channels,
    'bit_depth'     => $bit_depth,
    'device'        => $ENV{'NICK_ALSA_DEVICE'} || 'default',
    'buffer_in'     => \$buff_in,
    'blocking'      => 0,
    'buffer_secs'   => .5
);

my $alsa = Nick::Audio::ALSA -> new( %set );

ok( defined( $alsa ), 'new()' );

# make a sine wave block of data
my $pi2 = 8 * atan2 1, 1;
my $steps = $sample_rate / $hz;
my $max = ( 1 << ( $bit_depth - 1 ) ) - 1;
my( $audio_block, $i );
for ( $i = 0; $i < $steps; $i++ ) {
    for ( 1 .. $channels ) {
        $audio_block .= pack $pack, $max * sin(
            ( $i / $sample_rate ) * $pi2 * $hz
        );
    }
}
my $audio_len = length $audio_block;
$steps = (
    $duration * $sample_rate * ( $bit_depth / 8 ) * $channels
) / $audio_len;

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


$set{'read_secs'} = .1;
$alsa = Nick::Audio::ALSA -> new( %set );
for ( my $i = 0; $i < 5; $i++ ) {
    $alsa -> read();
}
