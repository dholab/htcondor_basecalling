#!/bin/bash

# Record the start time of the script
start_time=$(date +%s)

# Logging functions
log_info() {
	echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') $*"
}

log_error() {
	echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') $*" >&2
}

# Function to format seconds into HH:MM:SS
format_time() {
	local total_seconds=$1
	printf "%02d:%02d:%02d" $((total_seconds / 3600)) $(((total_seconds % 3600) / 60)) $((total_seconds % 60))
}

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
	log_error "--directory is required."
	print_usage
	exit 1
fi

# Use the arguments
log_info "Directory: $search_dir"
log_info "Kit: $kit"
log_info "Model: $model"

# place all the dorado stuff on the $PATH after decompressing it
log_info "Extracting dorado archive: $dorado"
tar xf $dorado &&
	export PATH=$PATH:$(pwd)/dorado/models:$(pwd)/dorado/dorado-0.7.3-linux-x64/bin:$(pwd)/dorado/dorado-0.7.3-linux-x64/lib
if [ $? -eq 0 ]; then
	log_info "Dorado archive extracted successfully and PATH updated."
else
	log_error "Failed to extract dorado archive: $dorado"
	exit 1
fi

# define a function that checks for a dorado installation
check_command() {
	local cmd="$1"
	if ! command -v "$cmd" &>/dev/null; then
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
log_info "Dorado is available and ready to run."

# pull out the directory basename and parent dir
RUN_ID=$(basename "$search_dir")
log_info "Naming output basecalled file $RUN_ID.bam"

# manually move the POD5 files onto the current execute node
log_info "Copying .pod5 files from $search_dir into the current execute node."
mkdir -p "$RUN_ID" && cp "$search_dir"/*.pod5 "$RUN_ID"/

# run the basecaller on the current batch
log_info "Now running dorado basecaller:"
log_info "Command: dorado basecaller \\"
log_info "         $model \\"
log_info "         $RUN_ID \\"
log_info "         --no-trim \\"
log_info "         --kit-name $kit \\"
log_info "         2> ${RUN_ID}.dorado.log \\"
log_info "         > ${RUN_ID}.bam"
dorado basecaller \
	"$model" \
	"$RUN_ID" \
	--no-trim \
	--kit-name "$kit" \
	2>"$RUN_ID.dorado.log" \
	>"$RUN_ID.bam"
if [ $? -eq 0 ]; then
	log_info "Dorado basecalling is complete."
else
	log_error "Dorado basecalling encountered an error."
	exit 1
fi

# demultiplex the basecalled BAM
log_info "Proceeding to demultiplexing with the basecalled BAM file ${RUN_ID}.bam."
log_info "Command: dorado demux ${RUN_ID}.bam --no-classify --output-dir ${RUN_ID}-demux"
dorado demux "$RUN_ID.bam" --no-classify --output-dir "${RUN_ID}-demux" 2>>"$RUN_ID.dorado.log"
if [ $? -eq 0 ]; then
	log_info "Dorado demultiplexing is complete."
else
	log_error "Dorado demultiplexing encountered an error."
	exit 1
fi

# move results back to staging
log_info "Transferring results back to staging server."
mv "${RUN_ID}-demux" "${search_dir}/${RUN_ID}-demux"
if [ $? -eq 0 ]; then
	log_info "Results transferred successfully."
else
	log_error "Failed to transfer results to staging server."
	exit 1
fi

# Calculate and report the script runtime
end_time=$(date +%s)
elapsed=$((end_time - start_time))
formatted_elapsed=$(format_time "$elapsed")
log_info "Script completed successfully in $formatted_elapsed (HH:MM:SS)."
