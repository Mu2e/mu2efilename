# Code to handle the Mu2e file name handling convention.
# See http://mu2e.fnal.gov/atwork/computing/tapeUpload.shtml
#
# Andrei Gaponenko, 2015

use strict;
use warnings;

package Mu2eFilename;
use Exporter qw( import );
use Digest;
use Carp;
use Data::Dumper;

use Class::Struct Mu2eFilename =>
    [ tier=>'$', owner=>'$', description=>'$',
      configuration=>'$', sequencer=>'$', extension=>'$'];

#----------------------------------------------------------------
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
    chop($res);
    return $res;
}

#----------------------------------------------------------------
# See http://mu2e.fnal.gov/atwork/computing/tapeUpload.shtml
#
my %fileFamilySuffixByTier =
    (
     cnf => 'etc',
     log => 'etc',
     sim => 'sim',
     mix => 'sim',
     dig => 'sim',
     mcs => 'sim',
     nts => 'nts',
    );

sub file_family_prefix {
    my ($self) = @_;
    croak "Mu2eFilename::file_family_prefix can only be called on an instance\n"
        unless ref $self;

    return $self->owner eq "mu2e" ? "phy" : "usr";
}

sub file_family_suffix {
    my ($self) = @_;
    croak "Mu2eFilename::file_family_suffix can only be called on an instance\n"
        unless ref $self;

    my $res = $fileFamilySuffixByTier{$self->tier};

    croak 'Unknown data tier "' . $self->tier . '"'
        unless defined $res; # $fileFamilySuffixByTier{$self->tier};

    return $res;
}

sub file_family {
    my ($self) = @_;
    return $self->file_family_prefix . '-' . $self->file_family_suffix;
}

#----------------------------------------------------------------
# A "spreader" is a string that defines a set of nested subdirectories
# that are used to spread dataset files among several dirs to avoid
# overcrowding a single directory.

sub spreader {
    my $bn = $_[0]->basename;
    my $dig = Digest->new('SHA-256');
    $dig->add($bn);
    my $hash = $dig->hexdigest;
    my @hh = split //, $hash, 7;
    return $hh[0].$hh[1].'/'.$hh[2].$hh[3].'/'.$hh[4].$hh[5];
}

#----------------------------------------------------------------
# relative to the dataroot
sub relpathname {
    my ($self) = @_;

    return $self->file_family . '/'
        . $self->tier . '/'
        . $self->owner . '/'
        . $self->description . '/'
        . $self->configuration . '/'
        . $self->spreader . '/'
        . $self->basename;
}

sub abspathname {
    croak "Environment varialbe MU2E_DATAROOT must be set before calling Mu2eFilename::abspathname "
        unless defined $ENV{'MU2E_DATAROOT'};

    return $ENV{'MU2E_DATAROOT'} . '/' . $_[0]->relpathname;
}

#----------------------------------------------------------------

1;
