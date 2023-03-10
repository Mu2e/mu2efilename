# Code shared by Mu2eFilename and Mu2eDSName.
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
# See https://mu2ewiki.fnal.gov/wiki/FileFamilies

# data tier to file family mapping for mu2e-owned datasets
my %dataTierToFileFamilyMapMu2e =
    (
     raw => 'phy-raw',
     rec => 'phy-rec',
     ntd => 'phy-ntd',
     cnf => 'phy-etc',
     sim => 'phy-sim',
     dts => 'phy-sim',
     mix => 'phy-sim',
     dig => 'phy-sim',
     mcs => 'phy-sim',
     nts => 'phy-nts',
     log => 'phy-etc',
     bck => 'phy-etc',
     etc => 'phy-etc',
    );

my %dataTierToFileFamilyMapUsr =
    (
     raw => 'phy-raw',
     rec => 'usr-dat',
     ntd => 'usr-dat',
     ext => 'usr-dat',
     rex => 'usr-dat',
     xnt => 'usr-dat',
     cnf => 'usr-etc',
     sim => 'usr-sim',
     dts => 'usr-sim',
     mix => 'usr-sim',
     dig => 'usr-sim',
     mcs => 'usr-sim',
     nts => 'usr-nts',
     log => 'usr-etc',
     bck => 'usr-etc',
     etc => 'usr-etc',
    );

sub file_family {
    my ($self) = @_;
    croak "Mu2eFNBase::file_family can only be called on an instance\n"
        unless ref $self;

    my ($mapping, $user) = $self->owner eq "mu2e" ?
        (\%dataTierToFileFamilyMapMu2e, 'official Mu2e') :
        (\%dataTierToFileFamilyMapUsr, 'user');

    my $res = $mapping->{$self->tier};

    croak 'File family for data tier "' . $self->tier . '" of ' .
        $user . ' files is not defined.'
        unless defined $res;

    return $res;
}

# dataset directory relative to a dataroot
sub reldsdir {
    my ($self) = @_;

    return $self->file_family . '/'
        . $self->tier . '/'
        . $self->owner . '/'
        . $self->description . '/'
        . $self->configuration . '/'
        . $self->extension;
}

# Mu2e dataset locations:  a map of symbolic name => filesystem path
my %mu2eDSL;
sub _init_mu2eDSL {
    for my $i ('disk', 'tape', 'scratch') {
        my $var = 'MU2E_DSROOT_'.uc($i);
        croak "Error: mu2efilename package is not setup properly: env var $var is not defined\n"
            unless defined $ENV{$var};
        $mu2eDSL{$i} = $ENV{$var};
    }
}
_init_mu2eDSL();

sub standard_locations() {
    return keys %mu2eDSL;
}

sub location_root {
    my $dsl = shift;
    if(ref $dsl) { # invoked on an instance?
        $dsl = shift;
    }
    croak "Unknown dataset location '$dsl'\n" unless defined $mu2eDSL{$dsl};
    return $mu2eDSL{$dsl};
}

sub absdsdir {
    my ($self, $dsl) = @_;
    return $self->location_root($dsl) . '/' . $self->reldsdir;
}

1;
#================================================================
__END__
=head1 NAME

Mu2eFNBase - common data and methods for Mu2eDSName and Mu2eFilename classes.

=head1 DESCRIPTION

Most of the class content is used via the Mu2eDSName and Mu2eFilename
packages, and is not supposed to be directly called by user.
The exceptions are these calls

   Mu2eFNBase::standard_locations()
    returns a list of symbolic location names, like ('tape', 'disk').

   Mu2eFNBase::location_root($locname)
    returns the filesystem path for the given location.

=head1 AUTHOR

Andrei Gaponenko, 2016

=cut
