#!/bin/bash

# Function to print usage
print_usage() {
    echo "Usage: $0 --directory <path> [--kit <kit>]"
    echo "  --directory: Directory where the .bam file to demultiplex have been placed (required)."
    echo "  --kit: The Oxford Nanopore barcoding kit used (defaults to SQK-NBD114-24)."
}

# set defaults for some of the command line args
kit="SQK-NBD114-24"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --directory)
            search_dir="$2"
            shift 2
            ;;
        --kit)
            kit="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            print_usage
            exit 1
            ;;
    esac
done

# Check if required argument is provided
if [ -z "$search_dir" ]; then
    echo "Error: --directory is required."
    print_usage
    exit 1
fi

# Check if the directory exists
EXPECTED_FILE="${search_dir}/basecalled.pre_demux.bam"
if [ ! -f "$EXPECTED_FILE" ]; then
    echo "Error: The expected file '$EXPECTED_FILE' does not exist."
    exit 1
fi

# define a function that checks for a dorado installation
check_command() {
    local cmd="$1"
    if ! command -v "$cmd" &> /dev/null; then
        echo "Error: '$cmd' is not available in your PATH. 😕"
        echo
        echo "It looks like '$cmd' isn't installed or isn't in your system's PATH."
        echo "Here are a few things you can try:"
        echo
        echo "1. Install '$cmd' using your system's package manager."
        echo "   For example, on Ubuntu or Debian: sudo apt install $cmd"
        echo "   On macOS with Homebrew: brew install $cmd"
        echo
        echo "2. If '$cmd' is already installed, make sure it's in your PATH:"
        echo "   - Check your PATH with: echo \$PATH"
        echo "   - Add the directory containing '$cmd' to your PATH if needed."
        echo
        echo "3. If you installed '$cmd' recently, try reopening your terminal"
        echo "   or running 'source ~/.bashrc' (or your shell's equivalent)."
        echo
        exit 1
    fi
}

# Run the check
check_command "dorado"

# if the file does exist, proceed
output_dir="${search_dir}/demux/"
mkdir -p "$output_dir"

# run demultiplexing
dorado demux \
bams/ \
--kit-name $kit \
--output-dir "$output_dir"

# write out a list of BAMs for distributed conversion to gzipped FASTQ format
bam_list="${output_dir}/bams_to_be_converted.txt"
find "$output_dir" -type f -name "*.bam" > "$bam_list"

echo "A list of demultiplexed BAM files available for conversion to FASTQ format is available at $bam_list."
