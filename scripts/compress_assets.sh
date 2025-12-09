#!/bin/bash

# Script to compress textures using ARM ASTC Encoder
# Recursively compresses all textures from raw_assets/ to assets/ preserving directory structure

set -e  # Exit on error

# Get the script's directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Define paths
RAW_ASSETS_DIR="$PROJECT_ROOT/raw_assets"
ASSETS_DIR="$PROJECT_ROOT/assets"
ASTCENC="$PROJECT_ROOT/tools/astcenc"

# ASTC compression settings
BLOCK_SIZE="6x6"      # Block size (4x4, 6x6, 8x8, etc. - 6x6 is a good balance)
QUALITY="-medium"     # Quality preset: -fast, -medium, -thorough, -exhaustive

# Check if astcenc exists
if [ ! -f "$ASTCENC" ]; then
    echo "Error: astcenc not found at $ASTCENC"
    exit 1
fi

# Check if raw_assets directory exists
if [ ! -d "$RAW_ASSETS_DIR" ]; then
    echo "Error: Directory $RAW_ASSETS_DIR does not exist"
    exit 1
fi

# Create assets directory if it doesn't exist
mkdir -p "$ASSETS_DIR"

echo "=========================================="
echo "ASTC Texture Compression"
echo "=========================================="
echo "Input:  $RAW_ASSETS_DIR"
echo "Output: $ASSETS_DIR"
echo "Block:  $BLOCK_SIZE"
echo "Quality: $QUALITY"
echo "=========================================="
echo ""

# Counter for statistics
total_files=0
compressed_files=0
failed_files=0

# Process all image files in raw_assets recursively
# Using find to handle multiple extensions
while IFS= read -r -d '' input_file; do

    total_files=$((total_files + 1))

    # Get relative path from raw_assets
    rel_path="${input_file#$RAW_ASSETS_DIR/}"

    # Get directory and filename
    rel_dir=$(dirname "$rel_path")
    filename=$(basename "$input_file")
    name="${filename%.*}"

    # Create output directory structure
    output_dir="$ASSETS_DIR/$rel_dir"
    mkdir -p "$output_dir"

    # Output file path
    output_file="$output_dir/${name}.astc"

    echo "Compressing: $rel_path -> ${rel_dir}/${name}.astc"

    # Run astcenc
    if "$ASTCENC" -cl "$input_file" "$output_file" "$BLOCK_SIZE" $QUALITY; then
        compressed_files=$((compressed_files + 1))

        # Show file sizes
        input_size=$(du -h "$input_file" | cut -f1)
        output_size=$(du -h "$output_file" | cut -f1)
        echo "  ✓ Done: $input_size -> $output_size"
    else
        failed_files=$((failed_files + 1))
        echo "  ✗ Failed to compress $filename"
    fi

    echo ""
done < <(find "$RAW_ASSETS_DIR" -type f \( -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" \) -print0)

# Print summary
echo "=========================================="
echo "Compression Summary"
echo "=========================================="
echo "Total files:      $total_files"
echo "Compressed:       $compressed_files"
echo "Failed:           $failed_files"
echo "=========================================="

if [ $failed_files -gt 0 ]; then
    exit 1
fi

echo "All assets compressed successfully!"
