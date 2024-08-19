#!/bin/bash

# Function to print usage
print_usage() {
    echo "Usage: $0 --directory <path>"
    echo "  --directory: Directory where the sorted basecalled .bam files have been placed (required)."
}

# set defaults for some of the command line args
kit="SQK-NBD114-24"
model="sup@latest"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --directory)
            search_dir="$2"
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
check_command "samtools"

# run the merge
samtools merge "${directory}/*.bam" -o "${directory}/basecalled.pre_demux.bam"
