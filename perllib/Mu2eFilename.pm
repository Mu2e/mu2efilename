# Code to handle the Mu2e file name handling convention.
# See http://mu2e.fnal.gov/atwork/computing/tapeUpload.shtml
#
# Andrei Gaponenko, 2015

use strict;
use warnings;

package Mu2eFilename;
use Exporter qw( import );
use Carp;
use Data::Dumper;

use Class::Struct Mu2eFilename =>
    [ tier=>'$', owner=>'$', description=>'$',
      configuration=>'$', sequencer=>'$', extension=>'$'];

sub parse {
    my ($class, $fn) = @_;

    croak "Error: Mu2eFilename::parse() requires a base file name without a path.  Got: '$fn'\n"
        if $fn =~ m|/|;

    my ($tier, $owner, $description, $configuration, $seq, $ext, $extra) = split(/\./, $fn);

    croak "Error parsing Mu2e file name '$fn': too many fields\n" if defined $extra;
    croak "Error parsing Mu2e file name '$fn': too few fields\n" if not defined $ext;

    my $self = $class->new(
        tier=>$tier,
        owner=>$owner,
        description=>$description,
        configuration=>$configuration,
        sequencer=>$seq,
        extension=>$ext,
        );

    return $self;
}

sub clone {
    my ($self) = @_;

    croak "clone can only be called on an instance.  Got instead: $self\n"
        unless ref $self;

    my $class = ref $self;

    my $copy = $class->new(
        tier=>$self->tier,
        owner=>$self->owner,
        description=>$self->description,
        configuration=>$self->configuration,
        sequencer=>$self->sequencer,
        extension=>$self->extension,
        );

    return $copy;
}

sub basename {
    my ($self) = @_;
    croak "Mu2eFilename::basename can only be called on an instance\n"
        unless ref $self;

    my $res = '';

    foreach my $i (@$self) {
        croak "Error: Mu2eFilename::basename() is called on an under-defined instance."
            . " Empty field after : \"" . $res . '"'
            unless defined $i and $i ne '';
        $res .= $i . '.';
    }

    return $res;
}

1;
