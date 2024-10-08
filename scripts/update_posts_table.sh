#!/bin/bash

# Set the directory paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
INDEX_FILE="$ROOT_DIR/index.html"

# Create temporary files
TEMP_FILE=$(mktemp)
SORTED_FILE=$(mktemp)

# Generate the new table content
echo "<table class=\"posts-table\">" > "$TEMP_FILE"
echo "  <thead><tr><th>Date</th><th>Title</th></tr></thead>" >> "$TEMP_FILE"
echo "  <tbody>" >> "$TEMP_FILE"

# Function to validate date
validate_date() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        date -jf "%B %d, %Y" "$1" "+%Y-%m-%d" >/dev/null 2>&1
    else
        date -d "$1" "+%Y-%m-%d" >/dev/null 2>&1
    fi
}

# Process each HTML file in the root directory, excluding index.html, about.html, and contact.html
find "$ROOT_DIR" -maxdepth 1 -name "*.html" ! -name "index.html" ! -name "about.html" ! -name "contact.html" | while read -r file; do
    # Check if the file is marked as unpublished
    if grep -q "<!-- unpublished -->" "$file"; then
        continue
    fi

    # Extract the date and title
    DATE=$(sed -n 's/.*<time>\(.*\)<\/time>.*/\1/p' "$file" | head -n 1)
    TITLE=$(sed -n 's/.*<h1>\(.*\)<\/h1>.*/\1/p' "$file" | head -n 1)
    FILENAME=$(basename "$file")

    # Only process if date is valid, title is present, and not marked as unpublished
    if validate_date "$DATE" && [ -n "$TITLE" ]; then
        # Format the date for sorting and display
        if [[ "$OSTYPE" == "darwin"* ]]; then
            SORT_DATE=$(date -jf "%B %d, %Y" "$DATE" "+%Y%m%d" 2>/dev/null)
            FORMATTED_DATE=$(date -jf "%B %d, %Y" "$DATE" "+%b %d, %Y" 2>/dev/null)
        else
            SORT_DATE=$(date -d "$DATE" "+%Y%m%d" 2>/dev/null)
            FORMATTED_DATE=$(date -d "$DATE" "+%b %d, %Y" 2>/dev/null)
        fi

        # Output to sorted file
        echo "$SORT_DATE|$FORMATTED_DATE|$FILENAME|$TITLE" >> "$SORTED_FILE"
    fi
done

# Sort the entries by date (newest first) and generate the table rows
sort -r "$SORTED_FILE" | while IFS='|' read -r _ FORMATTED_DATE FILENAME TITLE; do
    echo "    <tr onclick=\"window.location='$FILENAME';\" style=\"cursor: pointer;\"><td>$FORMATTED_DATE</td><td><a href=\"$FILENAME\">$TITLE</a></td></tr>" >> "$TEMP_FILE"
done

# Close the table
echo "  </tbody>" >> "$TEMP_FILE"
echo "</table>" >> "$TEMP_FILE"

# Replace the existing table in index.html with the new one
if [[ "$OSTYPE" == "darwin"* ]]; then
    sed -i '' '/<table class="posts-table"/,/<\/table>/d' "$INDEX_FILE"
    sed -i '' '/<div class="notes-section">/r '"$TEMP_FILE" "$INDEX_FILE"
else
    sed -i '/<table class="posts-table"/,/<\/table>/d' "$INDEX_FILE"
    sed -i '/<div class="notes-section">/r '"$TEMP_FILE" "$INDEX_FILE"
fi

# Clean up
rm "$TEMP_FILE" "$SORTED_FILE"

echo "index.html has been updated with the latest posts, sorted from newest to oldest."