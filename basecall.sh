#!/bin/bash

# Function to print usage
print_usage() {
    echo "Usage: $0 --directory <path> [--kit <kit>] [--model <model>] [--dorado <dorado tar archive>]"
    echo "  --directory: Directory where .pod5 files to be basecalled have been placed (required)."
    echo "  --kit: The Oxford Nanopore barcoding kit used (defaults to SQK-NBD114-24)."
    echo "  --model: The basecalling model to use (defaults to sup@latest)."
    echo "  --dorado: The name of the dorado tar archive, which itself contains the prebuilt 'dorado-0.7.3-linux-x64' directory and a pre-downloaded 'models/' directory (defaults to dorado.tar.gz)."
}

# set defaults for some of the command line args
kit="SQK-NBD114-24"
model="sup@latest"
dorado="dorado.tar.gz"

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
        --dorado)
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

# place all the dorado stuff on the $PATH after decompressing it
tar xf $dorado && \
export PATH=$PATH:$(pwd)/dorado/models:$(pwd)/dorado/dorado-0.7.3-linux-x64/bin:$(pwd)/dorado/dorado-0.7.3-linux-x64/lib

# define a function that checks for a dorado installation
check_command() {
    local cmd="$1"
    if ! command -v "$cmd" &> /dev/null; then
        echo "[ERROR] '$cmd' is not available in your PATH. 😕"
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
echo "Dorado is available and ready to run."

# pull out the directory basename and parent dir
RUN_ID=$(basename $search_dir)
echo "Naming output basecalled file $RUN_ID.bam"

# manually move the POD5 files onto the current execute node
mkdir -p $RUN_ID && cp $search_dir/*.pod5 $RUN_ID/

# run the basecaller on the current batch
echo "Now running dorado:"
echo "dorado basecaller \
$model \
$RUN_ID \
--kit-name $kit \
2> $RUN_ID.dorado.log \
> $RUN_ID.bam"
dorado basecaller \
"$model" \
"$RUN_ID" \
--no-trim \
--barcode-both-ends \
--kit-name "$kit" \
2> "$RUN_ID.dorado.log" \
> "$RUN_ID.bam"

echo "Dorado basecalling is complete."

# demultiplex the basecalled BAM
echo "Proceeding to demultiplexing with the basecalled BAM file $RUN_ID.bam."
echo "dorado demux $RUN_ID.bam --no-classify --kit-name $kit --output-dir ${RUN_ID}-demux"
dorado demux $RUN_ID.bam --no-classify --output-dir "${RUN_ID}-demux"

# move results back to staging
echo "Transferring results back to staging server"
mv "${RUN_ID}-demux" "${search_dir}/${RUN_ID}-demux"

echo "Dorado demultiplexing is complete."
