#define PERL_NO_GET_CONTEXT
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "ppport.h"

#include <alsa/asoundlib.h>

struct nickaudioalsa {
    SV *scalar_in;
    snd_pcm_t *playback_handle;
    unsigned int channels;
    unsigned int bytes_sample;
    bool blocking;
};

typedef struct nickaudioalsa NICKAUDIOALSA;

void set_blocking( NICKAUDIOALSA *THIS, bool blocking ) {
    int err;
    if (
        ( err = snd_pcm_nonblock(
            THIS -> playback_handle,
            blocking ? 0 : 1
        ) ) < 0
    ) {
        croak(
            "ALSA: unable to set blocking mode %d: %s",
            blocking, snd_strerror( err )
        );
    }
    if (
        ( err = snd_pcm_prepare( THIS -> playback_handle ) ) < 0
    ) {
        croak(
            "ALSA: cannot prepare audio interface for blocking: %s",
            snd_strerror( err )
        );
    }
    THIS -> blocking = blocking;
}

void write_audio( NICKAUDIOALSA *THIS ) {
    dTHX;
    STRLEN len_in;
    unsigned char *in_buff = (
        unsigned char *
    )SvPV(
        THIS -> scalar_in, len_in
    );
    len_in /= THIS -> bytes_sample;
    snd_pcm_sframes_t samples;
    samples = snd_pcm_writei(
        THIS -> playback_handle,
        in_buff,
        ( snd_pcm_sframes_t )len_in
    );
    if ( samples < 0 ) {
        samples = snd_pcm_recover(
            THIS -> playback_handle,
            samples,
            0
        );
    }
    if ( samples < 0 ) {
        croak(
            "ALSA: write to audio interface failed to write %lu samples: %s",
            len_in, snd_strerror( samples )
        );
    }
    if (
         samples != ( snd_pcm_sframes_t )len_in
    ) {
        warn(
            "ALSA: wanted to write %li samples, but wrote %li",
            len_in, samples
        );
    }
}

MODULE = Nick::Audio::ALSA  PACKAGE = Nick::Audio::ALSA

static NICKAUDIOALSA *
NICKAUDIOALSA::new_xs( device, sample_rate, channels, bit_depth, scalar_in, blocking, buffer_secs, record )
        const char *device;
        unsigned int sample_rate;
        unsigned int channels;
        unsigned int bit_depth;
        SV *scalar_in;
        bool blocking;
        float buffer_secs;
        bool record;
    CODE:
        Newxz( RETVAL, 1, NICKAUDIOALSA );
        int err;
        if (
            ( err = snd_pcm_open(
                &( RETVAL -> playback_handle ),
                device,
                record ? SND_PCM_STREAM_CAPTURE : SND_PCM_STREAM_PLAYBACK,
                blocking ? 0 : SND_PCM_ASYNC
            ) ) < 0
        ) {
            croak(
                "ALSA: cannot open audio device %s: %s",
                device, snd_strerror( err )
            );
        }
        snd_pcm_hw_params_t *hw_params;
        if (
            ( err = snd_pcm_hw_params_malloc( &hw_params ) ) < 0
        ) {
            croak(
                "ALSA: cannot allocate hardware parameter structure: %s",
                snd_strerror( err )
            );
        }
        if (
            ( err = snd_pcm_hw_params_any(
                RETVAL -> playback_handle,
                hw_params
            ) ) < 0
        ) {
            croak(
                "ALSA: cannot initialize hardware parameter structure: %s",
                snd_strerror( err )
            );
        }
        if (
            ( err = snd_pcm_hw_params_set_access(
                RETVAL -> playback_handle,
                hw_params,
                SND_PCM_ACCESS_RW_INTERLEAVED
            ) ) < 0
        ) {
            croak(
                "ALSA: cannot set access type: %s",
                snd_strerror( err )
            );
        }
        snd_pcm_format_t pcm_format;
        switch( bit_depth ) {
            case 16:
                pcm_format = SND_PCM_FORMAT_S16_LE;
                RETVAL -> bytes_sample = 2 * channels;
                break;
            case 32:
                pcm_format = SND_PCM_FORMAT_S32_LE;
                RETVAL -> bytes_sample = 4 * channels;
                break;
            default:
                croak( "Unsupported bit depth: %d", bit_depth );
        }
        if (
            ( err = snd_pcm_hw_params_set_format(
                RETVAL -> playback_handle,
                hw_params,
                pcm_format
            ) ) < 0
        ) {
            croak(
                "ALSA: cannot set sample format: %s",
                snd_strerror( err )
            );
        }
        if (
            ( err = snd_pcm_hw_params_set_rate_near(
                RETVAL -> playback_handle,
                hw_params,
                &sample_rate,
                0
            ) ) < 0
        ) {
            croak(
                "ALSA: cannot set sample rate %d: %s",
                sample_rate, snd_strerror( err )
            );
        }
        if (
            ( err = snd_pcm_hw_params_set_channels(
                RETVAL -> playback_handle,
                hw_params,
                channels
            ) ) < 0
        ) {
            croak(
                "ALSA: cannot set channels %d: %s",
                channels, snd_strerror( err )
            );
        }
        if ( buffer_secs > 0 ) {
            snd_pcm_uframes_t buffer_size = sample_rate * channels * 2 * buffer_secs;
            if (
                ( err = snd_pcm_hw_params_set_buffer_size_near(
                    RETVAL -> playback_handle,
                    hw_params,
                    &buffer_size
                ) ) < 0
            ) {
                croak(
                    "ALSA: cannot set buffer size %lu: %s",
                    buffer_size, snd_strerror( err )
                );
            }
        }
        if (
            ( err = snd_pcm_hw_params(
                RETVAL -> playback_handle,
                hw_params
            ) ) < 0
        ) {
            croak(
                "ALSA: cannot set parameters: %s",
                snd_strerror( err )
            );
        }
        snd_pcm_hw_params_free( hw_params );
        if (
            ( err = snd_pcm_prepare( RETVAL -> playback_handle ) ) < 0
        ) {
            croak(
                "ALSA: cannot prepare audio interface for use: %s",
                snd_strerror( err )
            );
        }
        RETVAL -> channels = channels;
        RETVAL -> blocking = blocking;
        RETVAL -> scalar_in = SvREFCNT_inc(
            SvROK( scalar_in )
            ? SvRV( scalar_in )
            : scalar_in
        );
    OUTPUT:
        RETVAL

void
NICKAUDIOALSA::DESTROY()
    CODE:
        snd_pcm_close( THIS -> playback_handle );
        SvREFCNT_dec( THIS -> scalar_in );
        Safefree( THIS );

void
NICKAUDIOALSA::play()
    CODE:
        if (
            ! SvOK( THIS -> scalar_in )
        ) {
            XSRETURN_UNDEF;
        }
        if ( ! THIS -> blocking ) {
            set_blocking( THIS, true );
        }
        write_audio( THIS );

void
NICKAUDIOALSA::play_nb()
    CODE:
        if (
            ! SvOK( THIS -> scalar_in )
        ) {
            XSRETURN_UNDEF;
        }
        if ( THIS -> blocking ) {
            set_blocking( THIS, false );
        }
        write_audio( THIS );

void
NICKAUDIOALSA::flush()
    CODE:
        snd_pcm_drain( THIS -> playback_handle );

long
NICKAUDIOALSA::can_write()
    CODE:
        if (
            ( RETVAL = snd_pcm_avail(
                THIS -> playback_handle
            ) ) < 0
        ) {
            croak(
                "ALSA: failed to read writable: %s",
                snd_strerror( RETVAL )
            );
        }
        RETVAL *= 2 * THIS -> channels;
    OUTPUT:
        RETVAL

void
NICKAUDIOALSA::read()
    CODE:
        STRLEN len_in;
        short int *in_buff = (short int*)SvPV( THIS -> scalar_in, len_in );
        len_in /= THIS -> bytes_sample;
        snd_pcm_sframes_t samples;
        samples = snd_pcm_readi(
            THIS -> playback_handle,
            in_buff,
            ( snd_pcm_sframes_t )len_in
        );
        if ( samples < 0 ) {
            samples = snd_pcm_recover(
                THIS -> playback_handle,
                samples,
                0
            );
        }
        if ( samples < 0 ) {
            croak(
                "ALSA: read from audio interface failed to write %lu samples: %s",
                len_in, snd_strerror( samples )
            );
        }
        if (
             samples != ( snd_pcm_sframes_t )len_in
        ) {
            warn(
                "ALSA: wanted to read %li samples, but read %li",
                len_in, samples
            );
        }
