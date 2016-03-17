## See POD after __END__
## You can run "perldoc /path/to/Mu2eDSName.pm" to read formatted documentation.

use strict;
use warnings;

package Mu2eDSName;
use Exporter qw( import );
use Carp;
use Mu2eFNBase;
use Mu2eFilename; # NB: Mu2eFilename and Mu2eDSName use each other, this is non-circular and fine

use Class::Struct Mu2eDSNameFields => [ tier=>'$', owner=>'$', description=>'$', configuration=>'$', extension=>'$'];

use base qw(Mu2eFNBase Mu2eDSNameFields);

#----------------------------------------------------------------
sub parse {
    my ($class, $ds) = @_;

    croak "Error: Mu2e dataset name may contain only alphanumeric characters, hyphens, underscores, and periods. Got: '$ds'\n"
        unless $ds =~ /^([.\w-]*)$/;

    my ($tier, $owner, $description, $configuration, $ext, $extra) = split(/\./, $ds);

    croak "Error parsing Mu2e dataset name '$ds': too many fields\n" if defined $extra;
    croak "Error parsing Mu2e dataset name '$ds': too few fields\n" if not defined $ext;

    my $self = $class->new(
        tier=>$tier,
        owner=>$owner,
        description=>$description,
        configuration=>$configuration,
        extension=>$ext,
        );

    return $self;
}

#----------------------------------------------------------------
sub from_reldsdir {
    my ($class, $rds) = @_;

    my ($family, $tier, $owner, $description, $configuration, $ext, $extra) = split('/', $rds);

    croak "Error: from_reldsdir(): too many fields in '$rds'\n" if defined $extra;
    croak "Error: from_reldsdir(): too few fields in '$rds'\n" if not defined $ext;

    my $self = $class->new(
        tier=>$tier,
        owner=>$owner,
        description=>$description,
        configuration=>$configuration,
        extension=>$ext,
        );

    my $expected_family = $self->file_family;
    croak "Error: from_reldsdir(): file family conflict for '$rds': '$expected_family' != '$family' \n"
        unless $family eq $expected_family;

    return $self;
}

#----------------------------------------------------------------
sub from_absdsdir {
    my ($class, $dir) = @_;
    $dir =~ s|/+$||;

    my $reldir;

  LOCLOOP:
    foreach my $dsl (Mu2eFNBase::standard_locations()) {
        my $locpath = Mu2eFNBase::location_root($dsl);

        my $tmp = $dir;
        if($tmp =~ s|^$locpath/||) {
            $reldir = $tmp;
            last LOCLOOP;
        }
    }

    croak "Error: path '$dir' does not correspond to a known dataset location\n"
        unless defined $reldir;

    return $class->from_reldsdir($reldir);
}

#----------------------------------------------------------------
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
        extension=>$self->extension,
        );

    return $copy;
}

sub dsname { return $_[0]->_name; }

sub file {
    my ($self, $sequencer) = @_;

    croak "Mu2eDSName::file can only be called on an instance\n"
        unless ref $self;

    croak "Mu2eDSName::file needs a sequencer to be specified\n"
        unless defined $sequencer;

    my $fn =  Mu2eFilename->new(
        tier=>$self->tier,
        owner=>$self->owner,
        description=>$self->description,
        configuration=>$self->configuration,
        sequencer=>$sequencer,
        extension=>$self->extension,
        );

    return $fn;
}

#----------------------------------------------------------------

1;
#================================================================
__END__


=head1 NAME

Mu2eDSName - class to handle dataset names in the  Mu2e convention.

=head1 DESCRIPTION

A Mu2eDSName object contains fields:

=over 4

=item * tier

=item * owner

=item * description

=item * configuration

=item * extension

=back

that are accessible by name, or settable with calls like

    $ds->tier('sim');

Fields may contain only alphanumeric characters, hyphens, and
underscores.  For more details see
http://mu2e.fnal.gov/atwork/computing/tapeUpload.shtml

The Mu2eDSName->parse($dsname) call creates a new object and set
all the fields based on its argument.  Alternatively, one can create
an uninitialized object

    $ds = Mu2eDSName->new;

and set its fields "by hand", or create a partly or fully initialized
object by adding arguments (values of the fields, in order) to the
"new" call above.  A Mu2eDSName object can also be created as a
clone() of an existing object.

Once all the fields are defined (and non empty), one can format the
corresponding dataset name with $ds->dsname.

A list of symbolic names of standard dataset locations (like 'disk',
'tape', etc.) is returned by the $ds->standard_locations() call.  The
filesystem path to a given location is given by
$ds->location_root($location_name).  The $ds->reldsdir() method
returns the relative dataset path with respect to a 'location root'
directory, and $ds->absdsdir($locname) returns the absolute filesystem
path for this dataset in a given location.

=head1 EXAMPLE

    use Mu2eDSName;

    my $ds1 = Mu2eDSName->parse('sim.mu2e.cd3-detmix-cut.v1.art');

    print "Original dataset = ", $ds1->dsname, "\n";

    my $ds2 = $ds1->clone();

    $ds2->configuration('v2');

    print "Dataset with new configuration = ", $ds2->dsname, "\n";

    print "A file from the new dataset = ", $ds2->file('001_256')->basename(), "\n";

=head1 AUTHOR

Andrei Gaponenko, 2016

=cut
