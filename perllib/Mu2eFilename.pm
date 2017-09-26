## See POD after __END__
## You can run "perldoc /path/to/Mu2eFilename.pm" to read formatted documentation.

use strict;
use warnings;

package Mu2eFilename;
use Exporter qw( import );
use Digest;
use Carp;
use Mu2eFNBase;
use Mu2eDSName; # NB: Mu2eFilename and Mu2eDSName use each other, this is non-circular and fine

use Class::Struct Mu2eFilenameFields =>
    [ tier=>'$', owner=>'$', description=>'$',
      configuration=>'$', sequencer=>'$', extension=>'$'];

use base qw(Mu2eFNBase Mu2eFilenameFields);

#----------------------------------------------------------------
sub parse {
    my ($class, $fn, $inopts) = @_;
    my $opts = $inopts // {};
    my $nothrow = $$opts{'nothrow'} // 0;

    my $self;
    if($fn =~ /^([.\w-]*)$/) {

        my ($tier, $owner, $description, $configuration, $seq, $ext, $extra) = split(/\./, $fn);
        if(defined $extra) {
            croak "Error parsing Mu2e file name '$fn': too many fields\n" unless $nothrow;
        }
        else {
            if(not defined $ext) {
                croak "Error parsing Mu2e file name '$fn': too few fields\n"
                    unless $nothrow;
            }
            else {
                $self = $class->new(
                    tier=>$tier,
                    owner=>$owner,
                    description=>$description,
                    configuration=>$configuration,
                    sequencer=>$seq,
                    extension=>$ext,
                    );
            }
        }
    }
    else {
        croak "Error: Mu2e file name may contain only alphanumeric characters, hyphens, underscores, and periods. Got: '$fn'\n"
            unless $nothrow;
    }
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

sub basename  { return $_[0]->_name; }

sub dataset {
    my ($self) = @_;
    croak "Mu2eFilename::dataset can only be called on an instance\n"
        unless ref $self;

    my $ds =  Mu2eDSName->new(
        tier=>$self->tier,
        owner=>$self->owner,
        description=>$self->description,
        configuration=>$self->configuration,
        extension=>$self->extension,
        );

    return $ds;
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
    return $self->reldsdir() . '/'
        . $self->spreader . '/'
        . $self->basename;
}

sub abspathname {
    my ($self, $loc) = @_;
    return $self->location_root($loc) . '/' .  $self->relpathname;
}

# legacy interfaces
sub abspathname_scratch {
    return $_[0]->abspathname('scratch');
}

sub abspathname_disk {
    return $_[0]->abspathname('disk');
}

sub abspathname_tape {
    return $_[0]->abspathname('tape');
}

1;
#================================================================
__END__


=head1 NAME

Mu2eFilename - class to handle the Mu2e file name handling convention.
See http://mu2e.fnal.gov/atwork/computing/tapeUpload.shtml for an
explanation of the basename structure.  In addition to parsing and
manipulating basenames, this package can also produce standardized
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

that are accessible by name, or settable with calls like

    $fn->tier('sim');

The Mu2eFilename->parse($basename) call creates a new object and set
all the fields based on its argument.  Alternatively, one can create
an uninitialized object

    $fn = Mu2eFilename->new;

and set its fields "by hand", or create a partly or fully initialized
object by adding arguments (values of the fields, in order) to the
"new" call above.  A Mu2eFilename object can also be created as a
clone() of an existing object.

Once all the fields are defined (and non empty), one can format the
corresponding file name with $fn->basename or $fn->abspathname($loc)
where $loc is one of the standard locations returned by
$fn->standard_locations().  Legacy methods $fn->abspathname_tape,
$fn->abspathname_disk, $fn->abspathname_scratch are also available.

Another call of interest is $fn->dataset.  It can be used on objects
with undefined sequencer, and returns a Mu2eDSName object.

=head1 EXAMPLE

    use Mu2eFilename;

    my $fn1 = Mu2eFilename->parse('sim.mu2e.cd3-detmix-cut.1109a.000001_00001162.art');

    print "Absolute pathname for a disk backed file = ", $fn1->abspathname_disk, "\n";

    my $fn2 = $fn1->clone();
    $fn2->owner('andr');

    print "Updated basename  = ", $fn2->basename, "\n";

    print "Updated disk pathname  = ", $fn2->abspathname_disk, "\n";

    print "Updated dataset name  = ", $fn2->dataset->dsname, "\n";

=head1 AUTHOR

Andrei Gaponenko, 2015

=cut
