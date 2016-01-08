# Code shared by Mu2eFilename and Mu2eDSName.  This class is not intended to be used directly.
#
# Andrei Gaponenko, 2016

use strict;
use warnings;

package Mu2eFNBase;

use Exporter qw( import );
use Carp;

sub _name {
    my ($self) = @_;
    croak "Mu2eFNBase::_name() can only be called on an instance\n"
        unless ref $self;

    my $res = '';

    foreach my $i (@$self) {
        croak "Error: Mu2eFNBase::_name() is called on an under-defined instance."
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
    croak "Mu2eFNBase::file_family_prefix can only be called on an instance\n"
        unless ref $self;

    return $self->owner eq "mu2e" ? "phy" : "usr";
}

sub file_family_suffix {
    my ($self) = @_;
    croak "Mu2eFNBase::file_family_suffix can only be called on an instance\n"
        unless ref $self;

    my $res = $fileFamilySuffixByTier{$self->tier};

    croak 'Unknown data tier "' . $self->tier . '"'
        unless defined $res;

    return $res;
}

sub file_family {
    my ($self) = @_;
    return $self->file_family_prefix . '-' . $self->file_family_suffix;
}

1;
