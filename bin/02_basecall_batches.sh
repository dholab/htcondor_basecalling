#!/bin/bash

# Function to print usage
print_usage() {
    echo "Usage: $0 --directory <path> [--kit <kit>] [--model <model>]"
    echo "  --directory: Directory where .pod5 files to be basecalled have been placed (required)."
    echo "  --kit: The Oxford Nanopore barcoding kit used (defaults to SQK-NBD114-24)."
    echo "  --model: The basecalling model to use (defaults to sup@latest)."
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
        --kit)
            kit="$2"
            shift 2
            ;;
        --model)
            model="$2"
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

# Use the arguments
echo "Directory: $search_dir"
echo "Kit: $kit"
echo "Model: $model"

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

# pull out the directory basename and parent dir
DIR_ID=$(basename "$directory")
PARENT_DIR=$(dirname "$directory")

# run the basecaller on the current batch
dorado basecaller \
$model \
"$directory" \
--kit-name $kit \
2> "${PARENT_DIR}/$DIR_ID.dorado.log" \
| samtools sort -M - -o "${PARENT_DIR}/$DIR_ID.bam"

