use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'Nick::Audio::ALSA',
    VERSION_FROM        => 'lib/Nick/Audio/ALSA.pm',
    AUTHOR              => 'Nick Peskett',
    LIBS                => [ '-lasound' ]
);
