#!/bin/bash

# Folder containing the JSON files
JSON_FOLDER="../sample_payloads"

# Verify folder exists
if [ ! -d "$JSON_FOLDER" ]; then
    echo "Error: Folder '$JSON_FOLDER' does not exist."
    exit 1
fi

# Process each JSON file
for file in "$JSON_FOLDER"/*.json; do
    # Handle case where no JSON files exist
    [ -e "$file" ] || {
        echo "No JSON files found in '$JSON_FOLDER'."
        exit 0
    }

    echo "Running test for: $file"
    ./test-logicapp.sh -f "$file"
done
