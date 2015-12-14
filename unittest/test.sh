#!/bin/bash
#
# Make sure shell and perl users get identical filenames.
# Check different kinds of files.
#
# Andrei Gaponenko, 2015


while read line; do
    shres=`mu2eabsname_tape $line`
    perlres=`${UPS_PROD_DIR}/unittest/mu2eabsname.pl --tape $line`
    if [[ x"$perlres" != x"$shres" ]]; then
        echo "ERROR: Mu2eFilename consistency check failed for -tape" >&2
        echo "Mu2eFilename from shell: $shres" >&2
        echo "Mu2eFilename from  perl: $perlres" >&2
        return 1
    fi

    shres=`mu2eabsname_disk $line`
    perlres=`${UPS_PROD_DIR}/unittest/mu2eabsname.pl --disk $line`
    if [[ x"$perlres" != x"$shres" ]]; then
        echo "ERROR: Mu2eFilename consistency check failed for -disk" >&2
        echo "Mu2eFilename from shell: $shres" >&2
        echo "Mu2eFilename from  perl: $perlres" >&2
        return 1
    fi

    shres=`mu2eabsname_scratch $line`
    perlres=`${UPS_PROD_DIR}/unittest/mu2eabsname.pl --scratch $line`
    if [[ x"$perlres" != x"$shres" ]]; then
        echo "ERROR: Mu2eFilename consistency check failed for -scratch" >&2
        echo "Mu2eFilename from shell: $shres" >&2
        echo "Mu2eFilename from  perl: $perlres" >&2
        return 1
    fi

done <<EOF
sim.mu2e.cd3-detmix-cut.1109a.000001_00001162.art
cnf.gandr.testmix.1106u.000001_00000000.fcl
log.mu2e.cd3-mix-cut.1109a.000001_00000999.log
nts.mu2e.cd3-detmix-cut.1109a.000001_00000999.root
EOF

return 0
