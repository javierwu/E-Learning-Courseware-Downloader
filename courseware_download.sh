#!/bin/bash

# ==============================================================================
# E-Learning Courseware Download Script (Interactive)
# ==============================================================================
#
# Usage:
#   chmod +x courseware_download.sh
#   ./courseware_download.sh
#
# ==============================================================================

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
GRAY='\033[0;90m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration (KEYPATH will be extracted from user input)
COOKIE_FILE="/tmp/elearning_cookies_$$.txt"
USER_AGENT="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
# BASE_DOMAIN and REFERER will be built from KEYPATH after user input

# Clear screen
clear

# Display title
echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║                                                            ║"
echo "║     E-Learning Courseware Download Tool v1.0                   ║"
echo "║                                                            ║"
echo "║                    macOS / Linux Version                      ║"
echo "║                                                            ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Check curl
echo -e "${YELLOW}Checking environment...${NC}"
if ! command -v curl &> /dev/null; then
    echo -e "${RED}[X] curl is not installed${NC}"
    echo ""
    echo "Please install curl:"
    echo "  macOS: brew install curl"
    echo "  Linux: sudo apt-get install curl  (Ubuntu/Debian)"
    echo "         sudo yum install curl      (CentOS/RHEL)"
    echo ""
    read -p "Press Enter to exit..."
    exit 1
fi
echo -e "${GREEN}[OK] curl is installed${NC}"

# Input username
echo ""
echo "═══════════════════════════════════════════════════════════"
echo -e "${CYAN}  Step 1/2: Login Information${NC}"
echo "═══════════════════════════════════════════════════════════"
echo ""

read -p "Please enter username: " username
if [ -z "$username" ]; then
    echo -e "${RED}Error: Username cannot be empty${NC}"
    read -p "Press Enter to exit..."
    exit 1
fi

# Input password
read -s -p "Please enter password: " password
echo ""
if [ -z "$password" ]; then
    echo -e "${RED}Error: Password cannot be empty${NC}"
    read -p "Press Enter to exit..."
    exit 1
fi

# Clean up old cookies
rm -f "$COOKIE_FILE"

# Trap to clean up on exit
trap cleanup EXIT

cleanup() {
    rm -f "$COOKIE_FILE"
    rm -f "/tmp/cas_page_$$$.html"
}

# Main download loop
continue_download=true
while [ "$continue_download" = true ]; do
    # Input resource ID or URL
    echo ""
    echo "═══════════════════════════════════════════════════════════"
    echo -e "${CYAN}  Step 2/2: Resource Information${NC}"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    echo -e "${YELLOW}Please enter the full courseware page URL:${NC}"
    echo ""
    echo -e "${GRAY}Example:${NC}"
    echo -e "${GRAY}  https://elearning.example.com/clientcn/courseware-pdf?...${NC}"
    echo ""

    # Read URL with validation loop
    while true; do
        echo -n "Resource URL: "
        read resource_url

        if [ -z "$resource_url" ]; then
            echo -e "${RED}Error: Resource URL cannot be empty${NC}"
            read -p "Press Enter to exit..."
            exit 1
        fi

        # Extract top-level domain from URL
        # Expected format: xxx.xxx (e.g., gtcloud.cn)
        KEYPATH=$(echo "$resource_url" | sed -E 's|https?://[^/]*\.([^./]+\.[^./]+)/.*|\1|')

        # Validate domain format (xxx.xxx)
        if echo "$KEYPATH" | grep -qE '^[a-z0-9-]+\.[a-z0-9-]+$'; then
            echo -e "${GREEN}      Detected domain: .$KEYPATH${NC}"
            break
        else
            echo -e "${RED}Error: Invalid domain format (expected xxx.xxx)${NC}"
            echo -e "${YELLOW}Please enter a valid courseware URL${NC}"
        fi
    done

    # Start download
    echo ""
    echo "═══════════════════════════════════════════════════════════"
    echo -e "${CYAN}  Starting Download...${NC}"
    echo "═══════════════════════════════════════════════════════════"
    echo ""

try_download() {
    # Build domain variables from extracted KEYPATH
    BASE_DOMAIN="elearning.$KEYPATH"
    REFERER="https://$BASE_DOMAIN/clientcn/"

    # Step 1: Get execution parameter
    echo -e "${YELLOW}[1/4] Getting login page...${NC}"
    curl -s -c "$COOKIE_FILE" -A "$USER_AGENT" \
        "https://sso.$KEYPATH/cas/login?service=https://$BASE_DOMAIN/clientcn/" \
        > "/tmp/cas_page_$$$.html" 2>&1

    execution=$(grep -oE 'name="execution" value="[^"]*"' "/tmp/cas_page_$$$.html" | cut -d'"' -f4)

    if [ -z "$execution" ]; then
        echo -e "${RED}Error: Failed to obtain execution parameter${NC}"
        return 1
    fi
    echo -e "${GREEN}      Successfully obtained execution parameter${NC}"

    # Step 2: CAS login
    echo -e "${YELLOW}[2/4] Logging in...${NC}"
    login_data="username=$username&password=$password&execution=$execution&_eventId=submit&geolocation="

    curl -s -c "$COOKIE_FILE" -b "$COOKIE_FILE" -X POST \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -H "User-Agent: $USER_AGENT" \
        -d "$login_data" \
        "https://sso.$KEYPATH/cas/login?service=https://$BASE_DOMAIN/clientcn/" \
        > /dev/null 2>&1

    sleep 0.5
    echo -e "${GREEN}      Login request sent${NC}"

    # Step 3: Get resource ID
    echo -e "${YELLOW}[3/4] Getting PDF URL...${NC}"

    # Process resource URL - extract resource ID and title
    doc_title=""
    # Extract id parameter from URL
    if echo "$resource_url" | grep -q '[?&]id=[a-f0-9]'; then
        resource_id=$(echo "$resource_url" | grep -oE '[?&]id=[a-f0-9]+' | sed 's/[?&]id=//')
        echo -e "${GRAY}      Extracted resource ID from URL: $resource_id${NC}"
        # Try to extract title parameter from full URL
        if echo "$resource_url" | grep -q '[?&]title='; then
            # URL decode the title parameter
            url_title=$(echo "$resource_url" | grep -oE '[?&]title=[^&]*' | sed 's/[?&]title=//')
            if [ -n "$url_title" ]; then
                # Use Python for proper URL decoding if available
                if command -v python3 >/dev/null 2>&1; then
                    doc_title=$(echo "$url_title" | python3 -c "import sys, urllib.parse; print(urllib.parse.unquote(sys.stdin.read().strip()))" 2>/dev/null | sed 's/[\/:*?"<>|]//g')
                elif command -v python >/dev/null 2>&1; then
                    doc_title=$(echo "$url_title" | python -c "import sys, urllib; print urllib.unquote(sys.stdin.read().strip()).decode('utf-8')" 2>/dev/null | sed 's/[\/:*?"<>|]//g')
                else
                    # Fallback: basic URL decode
                    doc_title=$(printf '%b' "$url_title" | sed 's/%20/ /g;s/%2C/,/g;s/%3A/:/g;s/%28/(/g;s/%29/)/g;s/[\/:*?"<>|]//g')
                fi
                if [ -n "$doc_title" ]; then
                    echo -e "${GRAY}      Extracted title from URL: $doc_title${NC}"
                fi
            fi
        fi
    else
        echo -e "${RED}Error: Unable to extract resource ID from URL${NC}"
        echo -e "${YELLOW}      Please check that the URL contains an 'id' parameter${NC}"
        return 1
    fi

    # Get document URL and title
    play_url="https://$BASE_DOMAIN/javaxieyi/show!play.do?id=$resource_id&flag=course"

    # Get redirect URL (actual document URL)
    pdf_url=$(curl -s -i -b "$COOKIE_FILE" -A "$USER_AGENT" "$play_url" 2>&1 | grep -i "^Location:" | cut -d' ' -f2- | tr -d '\r')

    # If Location not found in response, try with curl -i
    if [ -z "$pdf_url" ]; then
        pdf_url=$(curl -s -i -b "$COOKIE_FILE" -A "$USER_AGENT" "$play_url" 2>&1 | grep -i "^Location:" | cut -d' ' -f2- | tr -d '\r')
    fi

    if [ -z "$pdf_url" ]; then
        echo -e "${RED}Error: Failed to obtain PDF URL, resource may not exist or no permission${NC}"
        return 1
    fi

    # Set default title if not found
    if [ -z "$doc_title" ]; then
        doc_title="Courseware_$(date +'%Y%m%d_%H%M%S')"
    fi

    # Check if URL points to HTML (online viewer) instead of PDF
    if echo "$pdf_url" | grep -q "index\.html"; then
        echo -e "${YELLOW}      Resource is an online viewer, extracting actual document link...${NC}"

        # Download the HTML page and extract document link
        html_content=$(curl -s -b "$COOKIE_FILE" -A "$USER_AGENT" "$pdf_url" 2>&1)

        # Save HTML for debugging
        echo "$html_content" > "/tmp/debug_viewer_$$.html"

        # Try to extract title from viewer HTML (if not already found)
        if echo "$doc_title" | grep -q "Courseware_"; then
            viewer_title=$(echo "$html_content" | grep -oE '<title>[^<]*</title>' | sed 's/<title>//;s/<\/title>//;s/[\/:*?"<>|]//g')
            if [ -n "$viewer_title" ]; then
                doc_title="$viewer_title"
            fi
        fi

        # Try to find various document types in the HTML
        doc_exts=(pdf ppt pptx doc docx mp4 avi xlsx xls)
        found_url=""
        final_ext="pdf"

        for ext in "${doc_exts[@]}"; do
            # Try multiple patterns to find the document
            # Pattern 1: href="file.ext" or href='file.ext'
            candidate=$(echo "$html_content" | grep -oiE "href=[\"']([^\"']*\\.$ext)[\"']" | head -1)
            if [ -n "$candidate" ]; then
                candidate=$(echo "$candidate" | sed 's/href=["\x27]//g;s/["\x27]$//')
                found_url="$candidate"
                final_ext="$ext"
                break
            fi

            # Pattern 2: src="file.ext" or src='file.ext'
            candidate=$(echo "$html_content" | grep -oiE "src=[\"']([^\"']*\\.$ext)[\"']" | head -1)
            if [ -n "$candidate" ]; then
                candidate=$(echo "$candidate" | sed 's/src=["\x27]//g;s/["\x27]$//')
                found_url="$candidate"
                final_ext="$ext"
                break
            fi

            # Pattern 3: data-url or other attributes
            candidate=$(echo "$html_content" | grep -oE "\\.$ext[\"']" | head -1)
            if [ -n "$candidate" ]; then
                # Extract the full URL from context
                candidate=$(echo "$html_content" | grep -oE "[^\"' ]*\\.$ext[\"']" | head -1)
                if [ -n "$candidate" ]; then
                    found_url="$candidate"
                    final_ext="$ext"
                    break
                fi
            fi
        done

        # Check if this is an online slide viewer (PPT converted to images)
        if echo "$html_content" | grep -q "slides/pic/"; then
            echo -e "${YELLOW}      Detected online slide viewer (PPT converted to images)${NC}"
            echo -e "${YELLOW}      Downloading individual slides...${NC}"

            # Extract presentation title from HTML
            page_title=$(echo "$html_content" | grep -oE '<title>[^<]*</title>' | sed 's/<title>//;s/<\/title>//;s/[\/:*?"<>|]//g')
            if [ -z "$page_title" ]; then
                page_title="slides_$timestamp"
            fi

            # Create directory for slides
            slide_dir="${page_title}"
            mkdir -p "$slide_dir"
            mkdir -p "$slide_dir/slides/pic"
            mkdir -p "$slide_dir/slides/thumb"

            echo -e "${GRAY}      Creating directory: $slide_dir${NC}"

            # Extract all slide image URLs
            slide_urls=$(echo "$html_content" | grep -oE 'href="[^"]*slides/pic/[^"]*"' | sed 's/href="//;s/"$//' | sort -u)

            if [ -z "$slide_urls" ]; then
                echo -e "${RED}Error: Could not extract slide URLs${NC}"
                return 1
            fi

            # Count slides
            slide_count=$(echo "$slide_urls" | wc -l | tr -d ' ')
            echo -e "${GRAY}      Found $slide_count slides${NC}"

            # Download each slide
            slide_num=1
            success_count=0
            while IFS= read -r slide_url; do
                [ -z "$slide_url" ] && continue

                # Extract filename from URL
                filename=$(echo "$slide_url" | sed 's/.*\///')
                output_path="$slide_dir/slides/pic/$filename"

                # Build full URL if relative
                if echo "$slide_url" | grep -q "^http"; then
                    full_url="$slide_url"
                elif echo "$slide_url" | grep -q "^/"; then
                    base_url=$(echo "$pdf_url" | sed -E 's|(https?://[^/]*).*|\1|')
                    full_url="${base_url}${slide_url}"
                else
                    html_dir=$(echo "$pdf_url" | sed 's|/[^/]*$||')
                    full_url="${html_dir}/${slide_url}"
                fi

                echo -ne "${GRAY}      Downloading slide [$slide_num/$slide_count]: $filename${NC}\r"

                if curl -s -b "$COOKIE_FILE" -A "$USER_AGENT" "$full_url" -o "$output_path" 2>&1; then
                    if [ -f "$output_path" ]; then
                        file_sz=$(stat -f%z "$output_path" 2>/dev/null || stat -c%s "$output_path" 2>/dev/null)
                        if [ "$file_sz" -gt 1000 ]; then
                            success_count=$((success_count + 1))
                        fi
                    fi
                fi

                slide_num=$((slide_num + 1))
            done <<< "$slide_urls"

            echo ""
            echo -e "${GREEN}      Downloaded $success_count/$slide_count slides${NC}"
            echo ""
            echo "╔════════════════════════════════════════════════════════════╗"
            echo -e "${GREEN}║                    Download Successful!                        ║${NC}"
            echo "╚════════════════════════════════════════════════════════════╝"
            echo ""
            echo "  Location: $(pwd)/$slide_dir/"
            echo "  Slides: $success_count files"
            echo ""

            return 0
        fi

        # If still not found, try to find any file extension in upload/ directory
        if [ -z "$found_url" ]; then
            # Look for URLs pointing to files in upload/ or CourseWareFile/ directories
            candidate=$(echo "$html_content" | grep -oE 'https://[^[:space:]"]*upload/[^[:space:]"]*\.[a-z0-9]+' | head -1)
            if [ -n "$candidate" ]; then
                found_url="$candidate"
                final_ext=$(echo "$candidate" | sed -E 's/.*\.([a-z0-9]+).*/\1/')
            fi
        fi

        if [ -z "$found_url" ]; then
            echo -e "${RED}Error: Could not extract document link from HTML page${NC}"
            echo -e "${YELLOW}      HTML preview (first 500 chars):${NC}"
            echo "$html_content" | head -c 500
            echo ""
            echo -e "${YELLOW}      Debug: Full HTML saved to /tmp/debug_viewer_$$.html${NC}"
            echo -e "${YELLOW}      Supported formats: pdf, ppt, pptx, doc, docx, mp4, xlsx, xls${NC}"
            return 1
        fi

        # Handle relative URLs
        if echo "$found_url" | grep -q "^http"; then
            pdf_url="$found_url"
        elif echo "$found_url" | grep -q "^/"; then
            base_url=$(echo "$pdf_url" | sed -E 's|(https?://[^/]*).*|\1|')
            pdf_url="${base_url}${found_url}"
        else
            html_dir=$(echo "$pdf_url" | sed 's|/[^/]*$||')
            pdf_url="${html_dir}${found_url}"
        fi
        echo -e "${GREEN}      Found document ($final_ext): $pdf_url${NC}"
    else
        # Direct file URL - extract extension
        final_ext=$(echo "$pdf_url" | sed -E 's/.*\.([a-z0-9]+).*/\1/')
    fi

    echo -e "${GREEN}      Successfully obtained document URL${NC}"

    # Step 4: Download document
    echo -e "${YELLOW}[4/4] Downloading document...${NC}"
    output_file="$doc_title.$final_ext"

    echo -e "${GRAY}      Target file: $output_file${NC}"
    echo -e "${GRAY}      Document URL: $pdf_url${NC}"

    # Download with verbose output for debugging
    curl -s -b "$COOKIE_FILE" \
        -H "User-Agent: $USER_AGENT" \
        -H "Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8" \
        -H "Accept-Language: en-US,en;q=0.9" \
        -H "Referer: $REFERER" \
        -w "\n      HTTP Status: %{http_code}\n      Size: %{size_download} bytes\n" \
        "$pdf_url" \
        -o "$output_file" 2>&1 | grep -E "HTTP|Size"

    # Check result
    if [ -f "$output_file" ]; then
        file_size=$(du -h "$output_file" | cut -f1)
        actual_size=$(wc -c < "$output_file" | tr -d ' ')

        # Show file info
        echo -e "${GRAY}      File size: $file_size ($actual_size bytes)${NC}"

        # Detect file type
        file_type=$(file "$output_file" 2>/dev/null | head -1)
        echo -e "${GRAY}      File type: $file_type${NC}"

        # Check if file is valid (not HTML error page)
        # Get first few bytes
        if command -v xxd >/dev/null 2>&1; then
            header=$(xxd -p -l 8 "$output_file" 2>/dev/null | tr -d '\n')
        else
            header=$(head -c 4 "$output_file" 2>/dev/null)
        fi

        # Check for common file signatures
        is_valid=false
        error_page=false

        # HTML error page detection
        if echo "$file_type" | grep -qi "HTML"; then
            # Check if it's an error page
            if echo "$header" | grep -qi "doctype.*html\|<html"; then
                # Check for common error indicators
                if grep -qi "404\|error\|找不到\|not found" "$output_file"; then
                    error_page=true
                fi
            fi
        fi

        # Valid file signatures
        if [ "$error_page" = false ]; then
            if echo "$file_type" | grep -qi "PDF\|PowerPoint\|Word\|Excel\|MP4\|AVI"; then
                is_valid=true
            elif echo "$header" | grep -qi "25504446\|504b03040a\|d0cf11e0a1b11ae1"; then
                # PDF, PPT, DOC/XLS magic numbers
                is_valid=true
            fi
        fi

        if [ "$is_valid" = true ]; then
            echo ""
            echo "╔════════════════════════════════════════════════════════════╗"
            echo -e "${GREEN}║                    Download Successful!                        ║${NC}"
            echo "╚════════════════════════════════════════════════════════════╝"
            echo ""
            echo "  Filename: $output_file"
            echo "  Size: $file_size"
            echo "  Type: $file_type"
            echo "  Location: $(pwd)/$output_file"
            echo ""
            return 0
        else
            echo -e "${RED}Error: Download failed - invalid file or error page${NC}"
            if [ "$actual_size" -lt 10000 ]; then
                echo -e "${GRAY}      First 300 bytes of response:${NC}"
                head -c 300 "$output_file"
            fi
            rm -f "$output_file"
            return 1
        fi
    else
        echo -e "${RED}Error: Download failed${NC}"
        return 1
    fi
}

# Main execution
if try_download; then
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}  Download completed!${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${GRAY}Options:${NC}"
    echo -e "${GRAY}  [Space] Continue downloading (use same credentials)${NC}"
    echo -e "${GRAY}  [Enter]  Exit${NC}"
    echo ""
    echo -n "Your choice: "

    # Read from terminal and handle space key
    # Use stty to disable canonical mode for single-char read
    old_settings=$(stty -g 2>/dev/null)
    stty -icanon -echo 2>/dev/null || true
    choice=$(dd bs=1 count=1 2>/dev/null)
    stty "$old_settings" 2>/dev/null || true
    echo ""

    # Check for space character (ASCII 32) or empty (Enter)
    if [ "$choice" = " " ]; then
        # Clear screen for next download
        clear
        echo ""
        echo "╔════════════════════════════════════════════════════════════╗"
        echo "║                                                            ║"
        echo "║     E-Learning Courseware Download Tool v1.0                   ║"
        echo "║                                                            ║"
        echo "║                    macOS / Linux Version                      ║"
        echo "║                                                            ║"
        echo "╚════════════════════════════════════════════════════════════╝"
        echo ""
        echo -e "${GREEN}Using saved credentials: $username${NC}"
        continue_download=true
    else
        continue_download=false
    fi
else
    echo ""
    echo -e "${RED}Error: Download failed${NC}"
    echo ""
    echo -e "${YELLOW}Possible reasons:${NC}"
    echo -e "${GRAY}  1. Incorrect username or password${NC}"
    echo -e "${GRAY}  2. Incorrect resource ID${NC}"
    echo -e "${GRAY}  3. No permission to access this resource${NC}"
    echo -e "${GRAY}  4. Network connection issue${NC}"
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}  Try again or exit?${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${GRAY}Options:${NC}"
    echo -e "${GRAY}  [Space] Try again with same credentials${NC}"
    echo -e "${GRAY}  [Enter]  Exit${NC}"
    echo ""
    echo -n "Your choice: "

    # Read from terminal and handle space key
    old_settings=$(stty -g 2>/dev/null)
    stty -icanon -echo 2>/dev/null || true
    choice=$(dd bs=1 count=1 2>/dev/null)
    stty "$old_settings" 2>/dev/null || true
    echo ""

    if [ "$choice" = " " ]; then
        # Clear screen for next download
        clear
        echo ""
        echo "╔════════════════════════════════════════════════════════════╗"
        echo "║                                                            ║"
        echo "║     E-Learning Courseware Download Tool v1.0                   ║"
        echo "║                                                            ║"
        echo "║                    macOS / Linux Version                      ║"
        echo "║                                                            ║"
        echo "╚════════════════════════════════════════════════════════════╝"
        echo ""
        echo -e "${GREEN}Using saved credentials: $username${NC}"
        continue_download=true
    else
        continue_download=false
    fi
fi
done

echo ""
echo -e "${GRAY}Thank you for using E-Learning Courseware Download Tool!${NC}"
echo ""
exit 0
