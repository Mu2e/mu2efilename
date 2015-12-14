#!/usr/bin/perl -w

use Mu2eFilename;

my $opt = $ARGV[0];
my $ff = Mu2eFilename->parse($ARGV[1]);

if($opt eq '--tape') {
    print $ff->abspathname_tape, "\n";
}
elsif($opt eq '--disk') {
    print $ff->abspathname_disk, "\n";
}
elsif($opt eq '--scratch') {
    print $ff->abspathname_scratch, "\n";
}
else {
    die "$0: unknown option $opt\n";
}
