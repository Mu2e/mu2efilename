#!/bin/bash
#
# Generate Mu2e metadata for grid job output files.
#
# This code is meant to be run on grid nodes, and has minimal
# dependencies (no Python, no Perl).   For a more user-friendly
# version please use printJson (withouth the ".sh" extension)
# from the mu2etools package.
#
# Andrei Gaponenko, 2020

set -e -u -o pipefail

if [[ -z "$LD_LIBRARY_PATH" ]] && [[ -n "$CET_PLUGIN_PATH" ]]; then
    # spack broke file_info_dumper, this is a workaround
    LD_LIBRARY_PATH=$CET_PLUGIN_PATH
    export LD_LIBRARY_PATH
fi

printJson() {

    # Because this JSON generation code is meant for grid running,
    # some conditions that otherwise would have been treated as errors
    # are given a pass.  For example, if an unknown data_tier is
    # encountered, the file_type is simply set to "other".  When a new
    # data_tier is defined and this code is not updated before job
    # submission, it is easier to manually fix json after jobs succeed
    # than to re-run all the jobs.  And one can still use the outputs
    # even if they are not registered in SAM.

    # We saw DB performance issues when writing very long subrun lists to SAM.
    # The compromise is to drop subrun list from MC metadata if it is too long.
    maxLengthOfMCSubrunList=100

    printJsonError() {
        echo "Usage:"
        echo "    $0 {--parents parentListFile|--no-parents} validMu2eFileName"
    } >&2

    case "$1" in
        --parents)
            parentfile="$2";
            if [[ ! -r $parentfile ]]; then
                echo "Error: parent file \"$parentfile\" is not readable." >&2
                exit 2
            fi
            shift
            ;;

        --no-parents) parentfile="/dev/null";;
        *) printJsonError ; exit 1 ;;
    esac
    shift

    if [[ $# != 1 ]]; then
        printJsonError
        exit 1
    fi

    #================================================================
    inputfile=$1
    filename=$(basename $inputfile)

    fnfields=($(echo $filename | sed -e 's/\./ /g'))

    if [[ ${#fnfields[@]} != 6 ]]; then
        echo "Error: the \"$filename\" does not look like a valid Mu2e file name: expect 6 dot separated fields, got ${#fnfields[@]}" >& 2
        exit 2
    fi

    ### The first block of metadata is directly read from the filename
    cat<<EOF
{
    "file_name": "$filename",
    "dh.dataset": "${fnfields[0]}.${fnfields[1]}.${fnfields[2]}.${fnfields[3]}.${fnfields[5]}",
    "data_tier": "${fnfields[0]}",
    "dh.owner": "${fnfields[1]}",
    "dh.description": "${fnfields[2]}",
    "dh.configuration": "${fnfields[3]}",
    "dh.sequencer": "${fnfields[4]}",
    "file_format": "${fnfields[5]}",
EOF

    # The file_type parameter is derived from the filename using the
    # mappings.  We do not want to crash grid jobs here
    tier="${fnfields[0]}"
    case "$tier" in
        raw|rec|ntd|ext|rex|xnt) filetype=data ;;
        cnf|sim|mix|dig|dts|mcs|nts) filetype=mc ;;
        *) filetype=other;;
    esac

    cat<<EOF
    "file_type": "$filetype",
EOF

    # The following piece is queried from the filesystem
    #
    # Note that without assigning the output to an intermediate
    # variable errors from the called command would not be caught.
    file_size="$(stat -c '%s' $inputfile)"

    # The hash of the file content
    sha256="$(sha256sum $inputfile|cut -f1 -d' ')"

    cat<<EOF
    "file_size": "$file_size",
    "dh.sha256": "$sha256",
EOF

    # A list of parents
    sep=" "
    echo  '    "parents": ['
    (while read line; do
        echo '      '$sep' "'$line'"'; sep=,
        done ) < "$parentfile"
    echo '    ],'

    #================================================================
    # For art files only, run/subrun/event info determined from file content.
    ext="${fnfields[5]}"
    if [[ $ext == art ]]; then
        if which file_info_dumper > /dev/null ; then

            file_info_dumper --event-list "$inputfile" \
                | awk '
BEGIN{
  started=0;
  eventCount=0;
  subrunCount=0;
  fer="";
  fsr="";
};
{
  if(started) {
    if(NF==2) {
      # process subrun list
      ++subrunCount;
      if(!fsr) fsr=$0;
      lsr=$0;

      if((subrunCount < 1+'$maxLengthOfMCSubrunList') || ("'$filetype'" != "mc")) {
          asr[subrunCount] = $0;
      }
      else {
          # Empty the subrun list
          for(i in asr) delete asr[i];
      }

    }
    if(NF==3) {
      # process event list
      ++eventCount;
      if(!fer) fer=$0;
      ler=$0;
    }
  };
};
/Run *SubRun *Event/{started=1};
END {
  print "    \"event_count\": "eventCount",";

# Info on the first (sorted) event in the file, not defined for files with no events.
  if(eventCount) {
    split(fer, fera);
    print "    \"dh.first_run_event\": "fera[1]",";
    print "    \"dh.first_subrun_event\": "fera[2]",";
    print "    \"dh.first_event\": "fera[3]",";
  }
# Info on the last (sorted) event in the file, not defined for files with no events.
  if(eventCount) {
    split(ler, lera);
    print "    \"dh.last_run_event\": "lera[1]",";
    print "    \"dh.last_subrun_event\": "lera[2]",";
    print "    \"dh.last_event\": "lera[3]",";
  }
# Info on the first (sorted) subrun in the file
  split(fsr, fsra);
  print "    \"dh.first_run_subrun\": "fsra[1]",";
  print "    \"dh.first_subrun\": "fsra[2]",";

# Info on the last (sorted) subrun in the file
  split(lsr, lsra);
  print "    \"dh.last_run_subrun\": "lsra[1]",";
  print "    \"dh.last_subrun\": "lsra[2]",";

# List of subruns
  print "    \"runs\": [";
  sep=" ";
  for(i in asr) {
    split(asr[i],tmp);
    print "      " sep " [ " tmp[1] ", " tmp[2] ", \"'$filetype'\" ]";
    sep=",";
  }
  print "    ],";

}
'
        else
            cat >&2 <<EOF
Error: no file_info_dumper in PATH.
It is needed to extract metadata from art files.
Art not setup or its version is not compatible.
EOF
            exit 3
        fi # file_info_dumper

        #----------------------------------------------------------------
        # Another piece of data specific to art files is GenEventCount.
        # It is optional; if there is no GenEventCount in a file's SubRun
        # the metadata field will not be created.

        fcl=$(mktemp)
        out=$(mktemp)
        cat > $fcl <<EOF
process_name: genCountPrint
source: { module_type: RootInput }
physics: {
   analyzers: {
      genCountPrint: { module_type: GenEventCountReader makeHistograms: false }
   }
   e1: [ genCountPrint ]
   end_paths: [ e1 ]
}
source.readParameterSets: false
source.compactEventRanges: true
source.processingMode: RunsAndSubRuns
EOF
        if mu2e -c $fcl $inputfile > $out; then
            gencount=$(awk '/GenEventCount total:/{print $3}' $out)
            if [[ -n "$gencount" ]]; then
                echo '    "dh.gencount": '$gencount','
            else
                echo "Error: GenEventCount status zero but no value" >&2
                exit 4
            fi
        else
            # Is the record missing, or did something else go wrong?
            if ! grep -q 'no *GenEventCount *record' $out; then
                echo "Error getting GenEventCount information" >&2
                exit 4
            fi
        fi
        rm -f $fcl $out

        #----------------------------------------------------------------

    fi # $ext == art
    #================================================================

    # The fixed ending.
    cat<<EOF
    "content_status": "good"
}
EOF
}

printJson "$@"
