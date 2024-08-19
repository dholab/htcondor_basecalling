#!/bin/bash

# Function to print usage
print_usage() {
    echo "Usage: $0 --batch-size <number> --directory <path>"
    echo "  --batch-size: Number of files per batch"
    echo "  --directory: Directory to recursively search for .pod5 files"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --batch-size)
            batch_size="$2"
            shift 2
            ;;
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

# Check if both arguments are provided
if [ -z "$batch_size" ] || [ -z "$search_dir" ]; then
    echo "Error: Both --batch-size and --directory must be provided."
    print_usage
    exit 1
fi

# Check if the directory exists
if [ ! -d "$search_dir" ]; then
    echo "Error: Directory '$search_dir' does not exist."
    exit 1
fi

# Find all .pod5 files and store them in an array
mapfile -d $'\0' pod5_files < <(find "$search_dir" -type f -name "*.pod5" -print0)

# Calculate number of files and batches
total_files=${#pod5_files[@]}
num_batches=$(( (total_files + batch_size - 1) / batch_size ))

# Create output directory
output_dir="batched_pod5_files"
mkdir -p "$output_dir"

# Initialize list of new directories
dir_list="${search_dir}/pod5_batch_dirs.txt"
> "$dir_list"

# Process files in batches
for ((i=0; i<num_batches; i++)); do
    # Create batch directory
    batch_dir="${output_dir}/batch_$(printf "%03d" $((i+1)))"
    mkdir -p "$batch_dir"
    echo "$PWD/$batch_dir" >> "$dir_list"

    # Move files to batch directory
    for ((j=0; j<batch_size && i*batch_size+j<total_files; j++)); do
        mv "${pod5_files[i*batch_size+j]}" "$batch_dir" &
    done
done

# wait for all files to finish transferring
wait

echo "Batching complete. New directories are listed in $dir_list"
