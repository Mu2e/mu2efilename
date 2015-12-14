## See POD after __END__
## You can run "perldoc /path/to/Mu2eFilename.pm" to read formatted documentation.

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

sub dataset {
    my ($self) = @_;
    croak "Mu2eFilename::dataset can only be called on an instance\n"
        unless ref $self;

    return join('.',
                ($self->tier,
                 $self->owner,
                 $self->description,
                 $self->configuration,
                 ## $self->sequencer,
                 $self->extension)
        );
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
    return $hh[0].$hh[1].'/'.$hh[2].$hh[3];
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

sub abspathname_scratch {
    croak "Environment variable MU2E_DSROOT_SCRATCH must be set before calling Mu2eFilename::abspathname_scratch "
        unless defined $ENV{'MU2E_DSROOT_SCRATCH'};

    return $ENV{'MU2E_DSROOT_SCRATCH'} . '/' . $_[0]->relpathname;
}

sub abspathname_disk {
    croak "Environment variable MU2E_DSROOT_DISK must be set before calling Mu2eFilename::abspathname_disk "
        unless defined $ENV{'MU2E_DSROOT_DISK'};

    return $ENV{'MU2E_DSROOT_DISK'} . '/' . $_[0]->relpathname;
}

sub abspathname_tape {
    croak "Environment variable MU2E_DSROOT_TAPE must be set before calling Mu2eFilename::abspathname_tape "
        unless defined $ENV{'MU2E_DSROOT_TAPE'};

    return $ENV{'MU2E_DSROOT_TAPE'} . '/' . $_[0]->relpathname;
}

1;
#================================================================
__END__


=head1 NAME

Mu2eFilename - class to handle the Mu2e file name handling convention.
See http://mu2e.fnal.gov/atwork/computing/tapeUpload.shtml for an
explanation of the basename structure.  In addition to parsing and
manipulating basenames, this package can also produce a standardized
absolute pathnames for a Mu2e basefilename.  The absolute path
functionality requires that environment variables MU2E_DSROOT_TAPE,
MU2E_DSROOT_DISK, and MU2E_DSROOT_SCRATCH are set.

=head1 DESCRIPTION

A Mu2eFilename object contains fields:

=over 4

=item * tier

=item * owner

=item * description

=item * configuration

=item * sequencer

=item * extension

=back

that are accessable by name, or settable with calls like

    $fn->tier('sim');

The Mu2eFilename->parse($basename) call creates a new object and set
all the fields based on its argument.  Alternatively, one can create
an uninitialized object

    $fn = Mu2eFilename->new;

and set it fields "by hand".  Once all the fields are defined (and non emtpy),
one can format the corresponding file name with $fn->basename or
$fn->abspathname_tape, $fn->abspathname_disk, $fn->abspathname_scratch calls.
Another call of interest is $fn->dataset.

=head1 EXAMPLE

    use Mu2eFilename;

    my $fn = Mu2eFilename->parse('sim.mu2e.cd3-detmix-cut.1109a.000001_00001162.art');

    print "Absolute pathname for disk backed file = ", $fn->abspathname_disk, "\n";

    $fn->owner('andr');

    print "Updated basename  = ", $fn->basename, "\n";

    print "Updated disk pathname  = ", $fn->abspathname_disk, "\n";

=head1 AUTHOR

Andrei Gaponenko, 2015

=cut
