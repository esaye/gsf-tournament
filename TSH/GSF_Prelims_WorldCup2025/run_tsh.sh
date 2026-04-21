#!/bin/bash

# TSH Wrapper Script for GSF Prelims WorldCup 2025
# This script sets up the proper environment for running TSH

# Set the Perl library path
export PERL5LIB="/home/ebrimasaye/TSH/lib/perl:$PERL5LIB"

# Set the tournament directory
TOURNAMENT_DIR="/home/ebrimasaye/TSH/GSF_Prelims_WorldCup2025"

# Change to tournament directory
cd "$TOURNAMENT_DIR"

# Ensure we stay in the directory and have the config file
if [ ! -f "config.tsh" ]; then
    echo "Error: config.tsh not found in $PWD"
    exit 1
fi

# Run TSH with proper paths
perl "/home/ebrimasaye/TSH/tsh.pl" "$@"
