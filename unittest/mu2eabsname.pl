#!/usr/bin/perl -w

use Mu2eFilename;

my $ff = Mu2eFilename->parse($ARGV[0]);

print $ff->abspathname, "\n";
