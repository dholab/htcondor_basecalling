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
    cat <<EOF
Usage: $0 --directory <path> [OPTIONS]

Required arguments:
  --directory <path>    Directory containing .pod5 files to basecall

Optional arguments:
  --kit <kit>          Oxford Nanopore barcoding kit (default: SQK-NBD114-24)
  --model <model>      Basecalling model to use (default: sup@latest)
  --dorado <archive>   Dorado tar archive name (default: dorado.tar.gz)
  --help               Display this help message

Example:
  $0 --directory /path/to/pod5s --kit SQK-NBD114-24 --model sup@latest
EOF
}

# Set defaults for command line arguments
kit="SQK-NBD114-24"
model="sup@latest"
dorado="dorado.tar.gz"
search_dir=""

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
            dorado="$2"
            shift 2
            ;;
        --help|-h)
            print_usage
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            print_usage
            exit 1
            ;;
    esac
done

# Validate required arguments
if [ -z "$search_dir" ]; then
    log_error "Required argument --directory is missing."
    print_usage
    exit 1
fi

if [ ! -d "$search_dir" ]; then
    log_error "Directory does not exist: $search_dir"
    exit 1
fi

# Log configuration
log_info "Configuration:"
log_info "  Directory: $search_dir"
log_info "  Kit: $kit"
log_info "  Model: $model"
log_info "  Dorado archive: $dorado"

# Clone repository and prepare environment
log_info "Cloning htcondor_basecalling repository..."
if ! git clone https://github.com/dholab/htcondor_basecalling.git; then
    log_error "Failed to clone repository"
    exit 1
fi

log_info "Copying dorado archive..."
if ! cp "$dorado" htcondor_basecalling/; then
    log_error "Failed to copy dorado archive: $dorado"
    exit 1
fi

cd htcondor_basecalling || exit 1

# Set environment variables
export HOME=$PWD
export PIXI_HOME=$PWD/.pixi
export PATH="$HOME/.pixi/bin:$PATH"

log_info "Set HOME to: $HOME"
log_info "Installing Pixi package manager..."

# Install Pixi
if ! curl -fsSL https://pixi.sh/install.sh | bash; then
    log_error "Failed to install Pixi"
    exit 1
fi

log_info "Pixi installation complete. Resolving environment (this may take a few minutes)..."

# Solve and install environment
if ! pixi install --frozen; then
    log_error "Pixi environment resolution failed"
    exit 1
fi

log_info "Pixi environment solved successfully."

# Activate environment
export PATH="$HOME/.pixi/envs/default/bin:$PATH"
log_info "Activated Pixi environment."

# Extract and configure dorado
log_info "Extracting dorado archive: $dorado"
if ! tar xf "$dorado"; then
    log_error "Failed to extract dorado archive: $dorado"
    exit 1
fi

export PATH=$PATH:$(pwd)/dorado/models:$(pwd)/dorado/dorado-0.7.3-linux-x64/bin:$(pwd)/dorado/dorado-0.7.3-linux-x64/lib
log_info "Dorado archive extracted successfully and PATH updated."

# Verify dorado is available
if ! command -v dorado &>/dev/null; then
    log_error "dorado is not available in PATH after extraction"
    log_error "Current PATH: $PATH"
    exit 1
fi

log_info "Dorado is available and ready to run."

# Prepare run directory
RUN_ID=$(basename "$search_dir")
log_info "Run ID: $RUN_ID"
log_info "Output file: ${RUN_ID}.bam"

# Copy POD5 files to execute node
log_info "Copying .pod5 files from $search_dir"
mkdir -p "$RUN_ID" || exit 1

pod5_count=$(find "$search_dir" -maxdepth 1 -name "*.pod5" | wc -l)
if [ "$pod5_count" -eq 0 ]; then
    log_error "No .pod5 files found in $search_dir"
    exit 1
fi

log_info "Found $pod5_count .pod5 files"
if ! cp "$search_dir"/*.pod5 "$RUN_ID"/; then
    log_error "Failed to copy .pod5 files"
    exit 1
fi

# Run basecaller
log_info "Running dorado basecaller..."
log_info "  Model: $model"
log_info "  Input directory: $RUN_ID"
log_info "  Kit: $kit"
log_info "  Output: ${RUN_ID}.bam"

if ! dorado basecaller \
    "$model" \
    "$RUN_ID" \
    --no-trim \
    --kit-name "$kit" \
    2>"${RUN_ID}.dorado.log" \
    >"${RUN_ID}.bam"; then
    log_error "Dorado basecalling failed. Check ${RUN_ID}.dorado.log for details."
    exit 1
fi

log_info "Basecalling complete."

# Demultiplex
log_info "Demultiplexing ${RUN_ID}.bam..."
if ! dorado demux "$RUN_ID.bam" --no-classify --output-dir "${RUN_ID}-demux" 2>>"${RUN_ID}.dorado.log"; then
    log_error "Dorado demultiplexing failed. Check ${RUN_ID}.dorado.log for details."
    exit 1
fi

log_info "Demultiplexing complete."

# Convert BAM to FASTQ
log_info "Converting BAM files to FASTQ.gz..."
cd "${RUN_ID}-demux" || exit 1

bam_count=$(find . -maxdepth 1 -type f -name "*.bam" | wc -l)
log_info "Found $bam_count BAM files to convert"

if [ "$bam_count" -gt 0 ]; then
    find . -maxdepth 1 -type f -name '*.bam' -print0 |
        pixi run parallel -0 -j 6 \
            'echo "Converting {}..." && pixi run samtools fastq {} | gzip -c > {.}.fastq.gz && echo "Finished {}"'

    log_info "BAM to FASTQ conversion complete."
else
    log_error "No BAM files found for conversion"
    exit 1
fi

# Generate sequence statistics
log_info "Generating sequence statistics..."
fastq_files=(*.fastq.gz)

if [ ${#fastq_files[@]} -eq 0 ] || [ ! -e "${fastq_files[0]}" ]; then
    log_error "No FASTQ files found for statistics"
    exit 1
fi

log_info "Found ${#fastq_files[@]} FASTQ files"
# Always save to seqstats.tsv
pixi run seqkit stats -b -a -T -j 1 "${fastq_files[@]}" > seqstats.tsv
log_info "Sequence statistics saved to seqstats.tsv"

# Also display pretty version to console
pixi run csvtk pretty -t --style 3line seqstats.tsv

# Return to parent directory
cd ..

# move results back to staging
log_info "Transferring results back to staging server."
mv "${RUN_ID}-demux" "${search_dir}/${RUN_ID}-demux"
if [ $? -eq 0 ]; then
	log_info "Results transferred successfully."
else
	log_error "Failed to transfer results to staging server."
	exit 1
fi

# Calculate and report runtime
end_time=$(date +%s)
elapsed=$((end_time - start_time))
formatted_elapsed=$(format_time "$elapsed")

log_info "====================================="
log_info "Script completed successfully!"
log_info "Runtime: $formatted_elapsed (HH:MM:SS)"
log_info "Output directory: ${RUN_ID}-demux"
log_info "Log file: ${RUN_ID}.dorado.log"
log_info "====================================="
