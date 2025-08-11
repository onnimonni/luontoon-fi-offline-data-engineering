#!/bin/bash

set -e

echo "Downloading luontoon.fi data to offline..."

# Download the data json definitions
curl --user-agent 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/138.0.0.0 Safari/537.36' \
  --referer 'https://www.luontoon.fi/fi/lajit/retkeily-ja-ulkoilu/kartta' \
  -H 'luontoon-geo-auth: e0jf489hp3gh585793hgfdb10' \
  --parallel \
  --remove-on-error \
  --create-dirs \
  --skip-existing \
  --output "geo/tiles/#1.json" \
  'https://www.luontoon.fi/geo/tiles/{public.restrictedareas_details_view,public.destinations_view,public.destinations_details_view,public.all_lines_view,public.all_lines_details_view,public.amenities_view,public.amenities_cluster_summary_view}.json'

# Download the vector tiles (.pbf) for zoom level 4
curl --user-agent 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/138.0.0.0 Safari/537.36' \
  --referer 'https://www.luontoon.fi/fi/lajit/retkeily-ja-ulkoilu/kartta' \
  -H 'luontoon-geo-auth: e0jf489hp3gh585793hgfdb10' \
  --parallel \
  --remove-on-error \
  --create-dirs \
  --skip-existing \
  --output "geo/tiles/#1/#2/#3/#4.pbf" \
  'https://www.luontoon.fi/geo/tiles/{public.restrictedareas_details_view,public.destinations_view,public.destinations_details_view,public.amenities_cluster_summary_view}/{4}/[8-9]/[3-4].pbf'

# Download some files with zoom level 7
curl --user-agent 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/138.0.0.0 Safari/537.36' \
  --referer 'https://www.luontoon.fi/fi/lajit/retkeily-ja-ulkoilu/kartta' \
  -H 'luontoon-geo-auth: e0jf489hp3gh585793hgfdb10' \
  --parallel \
  --remove-on-error \
  --fail \
  --create-dirs \
  --skip-existing \
  --output "geo/tiles/#1/#2/#3/#4.pbf" \
  'https://www.luontoon.fi/geo/tiles/{public.all_lines_view,public.all_lines_details_view,public.amenities_view}/{8}/[140-148]/[58-75].pbf'

echo "Converting all MapBox vector files to parquet files..."

# Find non-empty .pbf files and run duckdb describe command for each
find . -type f -name "*.pbf" -size +0 -print0 | \
    xargs -0 -n10 -P $(sysctl -n hw.ncpu) sh -c '
    for file in "$@"; do
        # Skip if parquet file already exists
        if [ -f "$file.parquet" ]; then
            continue
        fi
        duckdb -c "
            INSTALL spatial; LOAD spatial;
            COPY (
                FROM st_read('\''$file'\'')
            ) TO '\''$file.parquet'\'' (
                FORMAT PARQUET,
                CODEC '\''zstd'\'',
                PARQUET_VERSION v2
            );
        " > /dev/null
    done' sh

echo "Combining smaller parquet files to bigger parquet files and compressing..."

mkdir -p data

# Summarize all datasets into single parquet files
for file in {public.restrictedareas_details_view,public.destinations_view,public.destinations_details_view,public.all_lines_view,public.all_lines_details_view,public.amenities_view,public.amenities_cluster_summary_view}; do
    echo "Processing geo/tiles/$file/*/*/*.parquet ..."
    # Skip if parquet file already exists
    if [ -f "data/$file.parquet" ]; then
        continue
    fi
    duckdb -c "
        INSTALL spatial; LOAD spatial;
        COPY (
            FROM read_parquet('geo/tiles/$file/*/*/*.parquet', union_by_name = true)
        ) TO 'data/$file.parquet' (
            FORMAT PARQUET,
            CODEC 'zstd',
            COMPRESSION_LEVEL 20,
            PARQUET_VERSION v2
        );
    "
done

# Cleanup temporary smaller parquet files
echo "Cleaning up temporary parquet files..."
find geo/tiles -type f -name "*.pbf.parquet" -delete

echo "All data has been created successfully in the 'data' directory."
echo "🦆📊 You can now query the data using duckdb like this:"

for file in data/*.parquet; do
    duckdb -c "SELECT '$file' as dataset_name, COUNT(*) as row_count FROM '$file'"
done