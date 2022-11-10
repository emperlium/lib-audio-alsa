# lib-audio-alsa

Interface to the ALSA asound library.

## Dependencies

You'll need the [asound library](http://www.alsa-project.org/).

On Ubuntu distributions;

    sudo apt install libasound2-dev

## Installation

    perl Makefile.PL
    make test
    sudo make install

### Testing using ALSA device other than "default"

    NICK_ALSA_DEVICE=hw:CustomPCM make test

## Example

    use Nick::Audio::ALSA;
    use Time::HiRes 'sleep';

    my $sample_rate = 22050;
    my $hz = 441;
    my $duration = 7;

    my $buff_in;
    my $alsa = Nick::Audio::ALSA -> new(
        'sample_rate'   => $sample_rate,
        'channels'      => 1,
        'bit_depth'     => 16,
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

## Methods

### new()

Instantiates a new Nick::Audio::ALSA object.

Arguments are interpreted as a hash and all are optional.

- device

    ALSA device name (e.g. hw:1,0)

    Default: **default**

- sample\_rate

    Sample rate of PCM data in **buffer\_in**.

    Default: **44100**

- channels

    Number of audio channels in PCM data in **buffer\_in**.

    Default: **2**

- item bit_depth

    Number of bits of information in each sample of PCM data in **buffer\_in**.

    Valid values: 16 or 32.

    Default: **16**

- buffer\_in

    Scalar that'll be used to pull PCM data from.

- blocking

    Whether writing audio will block.

    Default: **true**

- buffer\_secs

    How many seconds of audio ALSA should buffer.

    Default: **0**

### play()

Sends PCM audio data from **buffer\_in** to ALSA.

If **blocking** is set to false, it will be changed to true.

### play\_nb()

Sends PCM audio data from **buffer\_in** to ALSA.

If **blocking** is set to true, it will be changed to false.

### flush()

Blocks while ALSA is drained of audio.

### can\_write()

Returns the number of bytes that can be written to ALSA.
