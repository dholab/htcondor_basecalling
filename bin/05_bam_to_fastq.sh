#!/bin/bash

# Function to print usage
print_usage() {
    echo "Usage: $0 --bam <path>"
    echo "  --bam: Path to BAM file to convert to FASTQ.GZ format (required)."
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --bam)
            bam="$2"
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
if [ -z "$bam" ]; then
    echo "Error: --bam is required."
    print_usage
    exit 1
fi

# Check if the BAM file exists
if [ ! -f "$bam" ]; then
    echo "Error: The expected file '$bam' does not exist."
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

# Run the checks
check_command "samtools"
check_command "bgzip"

# identify the parent directory and BAM basename
PARENT_DIR=$(dirname "$bam")
BASENAME=$(basename "$bam" .${bam##*.})

# run the conversion
samtools fastq "$(bam)" | bgzip -o $(BASENAME).fastq.gz
