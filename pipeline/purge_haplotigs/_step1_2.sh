#!/bin/bash

echo "Usage: ./purge_haplotigs.sh [manual_peaks]"

if [ -e $1 ]; then
    echo "$1 detected. Use values in this file for l m h."
    l_cutoff=`sed -n 1p $1 | awk '{print $1}'`
    m_cutoff=`sed -n 2p $1 | awk '{print $1}'`
    h_cutoff=`sed -n 3p $1 | awk '{print $1}'`
fi

module load purge_haplotigs/0~20180710.f4fd019

if ! [ -e aligned.bam.genecov ]; then
    echo "STEP 1. Generate coverage histogram"
    echo ""

    echo "\
    purge_haplotigs readhist aligned.bam"
    purge_haplotigs readhist aligned.bam
    echo
fi

if  [[ ! -e peaks && -z $1 ]]; then
echo "STEP 1.5 Get l, m, h cut-offs"

echo "\
    awk '$1=="genome" {print $2"\t"$3}' aligned.bam.genecov | java -jar -Xmx1g $VGP_PIPELINE/purge_haplotigs/depthPeaks.jar - > peaks"
    awk '$1=="genome" {print $2"\t"$3}' aligned.bam.genecov | java -jar -Xmx1g $VGP_PIPELINE/purge_haplotigs/depthPeaks.jar - > peaks
fi

num_lines=`wc -l peaks | awk '{print $1}'`

if [[ -e $1 ]]; then
    # Skip auto detection and proceed
    echo "Skip auto detecting"
elif [[ $num_lines -ge 5 ]]; then
    l_cutoff=`cat peaks | head -n1 | awk '{print $1}'`
    m_cutoff=`cat peaks | tail -n3 | head -n1 | awk '{print $1}'`
    h_cutoff=`cat peaks | tail -n1 | awk '{print $1}'`
elif [[ $num_lines -eq 3 ]]; then
    l_cutoff=`sed -n 1p peaks | awk '{print $1}'`
    # Assumes we have only one peak
    m_cutoff=`sed -n 2p peaks | awk '{print $1}'`
    h_cutoff=`sed -n 3p peaks | awk '{print $1}'`

    # Is it a haploid peak?
    if [[ $m_cutoff -lt $(($h_cutoff/2)) ]]; then
        m_cutoff=`sed -n 2p peaks | awk '{print int($1*1.5)}'`
    else
        # The haploid peak is 1/2 and the m_cutoff should be 3/4 of this
        m_cutoff=`sed -n 2p peaks | awk '{print int($1*0.75)}'`
    fi
else
    echo "...peak is not fitting to 1 or 2 peak(s) model. Exit."
    exit -1
fi

echo "Detected 2 peaks. Setting l=$l_cutoff, m=$m_cutoff, h=$h_cutoff from peaks."

echo "STEP 2. Get Contig Cov"
echo "\
purge_haplotigs  contigcov  -i aligned.bam.genecov  -l $l_cutoff  -m $m_cutoff  -h $h_cutoff  -j 200"
purge_haplotigs  contigcov  -i aligned.bam.genecov  -l $l_cutoff  -m $m_cutoff  -h $h_cutoff  -j 200

