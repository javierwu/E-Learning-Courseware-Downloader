# ==============================================================================
# E-Learning Courseware Download Script (Interactive)
# ==============================================================================
#
# Usage:
#   Double-click to run or execute in PowerShell: .\Courseware_Download.ps1
#
# ==============================================================================

# Set console encoding
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# Clear screen
Clear-Host

# Display title
Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║                                                            ║" -ForegroundColor Cyan
Write-Host "║     E-Learning Courseware Download Tool v1.0                   ║" -ForegroundColor Cyan
Write-Host "║                                                            ║" -ForegroundColor Cyan
Write-Host "║                    Windows PowerShell                         ║" -ForegroundColor Cyan
Write-Host "║                                                            ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# Check curl
Write-Host "Checking environment..." -ForegroundColor Yellow
$curlExists = $false
try {
    $null = Get-Command curl -ErrorAction Stop
    $curlExists = $true
    Write-Host "[OK] curl is installed" -ForegroundColor Green
} catch {
    Write-Host "[X] curl is not installed" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please install curl and retry: https://curl.se/download.html" -ForegroundColor Yellow
    Write-Host "Press any key to exit..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit 1
}

# Input username
Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Gray
Write-Host "  Step 1/2: Login Information" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Gray
Write-Host ""

$username = Read-Host "Please enter username"
if ([string]::IsNullOrWhiteSpace($username)) {
    Write-Host "Error: Username cannot be empty" -ForegroundColor Red
    Write-Host "Press any key to exit..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit 1
}

# Input password
$password = Read-Host "Please enter password" -AsSecureString
$passwordPlain = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($password))
if ([string]::IsNullOrWhiteSpace($passwordPlain)) {
    Write-Host "Error: Password cannot be empty" -ForegroundColor Red
    Write-Host "Press any key to exit..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit 1
}

# Configuration (KEYPATH will be extracted from user input)
$UserAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
# BASE_DOMAIN and REFERER will be built from KEYPATH after user input

# Main download loop
$continueDownload = $true
while ($continueDownload) {
    # Input resource URL with domain extraction and validation
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Gray
    Write-Host "  Step 2/2: Resource Information" -ForegroundColor Cyan
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Please enter the full courseware page URL:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Example:" -ForegroundColor Gray
    Write-Host "  https://elearning.example.com/clientcn/courseware-pdf?..." -ForegroundColor White
    Write-Host ""

    # Read URL with validation loop
    $validDomain = $false
    while (-not $validDomain) {
        $resourceUrl = Read-Host "Resource URL"

        if ([string]::IsNullOrWhiteSpace($resourceUrl)) {
            Write-Host "Error: Resource URL cannot be empty" -ForegroundColor Red
            Write-Host "Press any key to exit..."
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            exit 1
        }

        # Extract top-level domain from URL
        # Expected format: xxx.xxx (e.g., gtcloud.cn)
        if ($resourceUrl -match 'https?://[^/]*\.([^./]+\.[^./]+)/') {
            $KEYPATH = $matches[1]

            # Validate domain format (xxx.xxx)
            if ($KEYPATH -match '^[a-z0-9-]+\.[a-z0-9-]+$') {
                Write-Host "      Detected domain: .$KEYPATH" -ForegroundColor Green
                $validDomain = $true
            } else {
                Write-Host "Error: Invalid domain format (expected xxx.xxx)" -ForegroundColor Red
                Write-Host "Please enter a valid courseware URL" -ForegroundColor Yellow
            }
        } else {
            Write-Host "Error: Unable to extract domain from URL" -ForegroundColor Red
            Write-Host "Please enter a valid courseware URL" -ForegroundColor Yellow
        }
    }

    # Start download
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Gray
    Write-Host "  Starting Download..." -ForegroundColor Cyan
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Gray
    Write-Host ""

    $CookieFile = "$env:TEMP\elearning_cookies_$(Get-Random).txt"

    # Clear old cookies
    if (Test-Path $CookieFile) { Remove-Item $CookieFile -Force }

    $downloadSuccess = $false
    try {
    # Build domain variables from extracted KEYPATH
    $BASE_DOMAIN = "elearning.$KEYPATH"
    $REFERER = "https://$BASE_DOMAIN/clientcn/"

    # Step 1: Get execution parameter
    Write-Host "[1/4] Getting login page..." -ForegroundColor Yellow
    $null = curl -s -c $CookieFile -A $UserAgent "https://sso.$KEYPATH/cas/login?service=https://$BASE_DOMAIN/clientcn/" 2>&1

    $htmlContent = Get-Content $CookieFile -Raw -ErrorAction SilentlyContinue
    if ($htmlContent -match 'name="execution" value="([^"]*)"') {
        $execution = $matches[1]
        Write-Host "      Successfully obtained execution parameter" -ForegroundColor Green
    } else {
        # Get page directly
        curl -s -c $CookieFile -A $UserAgent "https://sso.$KEYPATH/cas/login?service=https://$BASE_DOMAIN/clientcn/" -o "$env:TEMP\cas_page.html" 2>&1
        $execution = Select-String -Path "$env:TEMP\cas_page.html" -Pattern 'name="execution" value="([^"]*)"' -ErrorAction SilentlyContinue | ForEach-Object { $_.Matches[0].Groups[1].Value }

        if (-not $execution) {
            throw "Failed to obtain execution parameter"
        }
        Write-Host "      Successfully obtained execution parameter" -ForegroundColor Green
    }

    # Step 2: CAS login
    Write-Host "[2/4] Logging in..." -ForegroundColor Yellow
    $loginData = "username=$username&password=$passwordPlain&execution=$execution&_eventId=submit&geolocation="

    $loginResult = curl -s -c $CookieFile -b $CookieFile -X POST -H "Content-Type: application/x-www-form-urlencoded" -H "User-Agent: $UserAgent" -d $loginData "https://sso.$KEYPATH/cas/login?service=https://$BASE_DOMAIN/clientcn/" 2>&1

    Start-Sleep -Milliseconds 500
    Write-Host "      Login request sent" -ForegroundColor Green

    # Step 3: Get resource ID
    Write-Host "[3/4] Getting document URL..." -ForegroundColor Yellow

    # Process resource URL - extract resource ID and title
    $docTitle = $null
    # Extract id parameter from URL
    if ($resourceUrl -match '[?&]id=([a-f0-9]+)') {
        $resourceId = $matches[1]
        Write-Host "      Extracted resource ID from URL: $resourceId" -ForegroundColor Gray

        # Try to extract title from URL parameter
        if ($resourceUrl -match '[?&]title=([^&]*)') {
            $urlTitle = $matches[1]
            try {
                # Use .NET to URL decode
                $docTitle = [System.Uri]::UnescapeDataString($urlTitle) -replace '[\\/:*?\"<>|]', ''
                Write-Host "      Extracted title from URL: $docTitle" -ForegroundColor Gray
            } catch {
                # Fallback to basic replacement
                $docTitle = $urlTitle -replace '%20', ' ' -replace '[\\/:*?\"<>|]', ''
                Write-Host "      Extracted title from URL: $docTitle" -ForegroundColor Gray
            }
        }
    } else {
        Write-Host "Error: Unable to extract resource ID from URL" -ForegroundColor Red
        Write-Host "      Please check that the URL contains an 'id' parameter" -ForegroundColor Yellow
        throw "Resource ID not found in URL"
    }

    # Get document URL
    $playUrl = "https://$BASE_DOMAIN/javaxieyi/show!play.do?id=$resourceId&flag=course"
    $playResponse = curl -s -b $CookieFile -A $UserAgent $playUrl 2>&1

    # Set default title if not found
    if ([string]::IsNullOrWhiteSpace($docTitle)) {
        $docTitle = "Courseware_" + (Get-Date -Format 'yyyyMMdd_HHmmss')
    }

    # Get redirect URL
    if ($playResponse -match 'Location:\s*([^\r\n]+)') {
        $docUrl = $matches[1].Trim()
    } else {
        # Try with -i flag
        $pdfResponse = curl -s -i -b $CookieFile -A $UserAgent $playUrl 2>&1
        if ($pdfResponse -match 'Location:\s*([^\r\n]+)') {
            $docUrl = $matches[1].Trim()
        }
    }

    if (-not $docUrl) {
        throw "Failed to obtain document URL, resource may not exist or no permission"
    }
    Write-Host "      Successfully obtained document URL" -ForegroundColor Gray

    # Check if URL points to HTML (online viewer) instead of direct file
    if ($docUrl -match "index\.html") {
        Write-Host "      Resource is an online viewer, checking content..." -ForegroundColor Yellow

        # Download the HTML page
        $htmlContent = curl -s -b $CookieFile -A $UserAgent $docUrl 2>&1

        # Check if this is an online slide viewer (PPT converted to images)
        if ($htmlContent -match "slides/pic/") {
            Write-Host "      Detected online slide viewer (PPT converted to images)" -ForegroundColor Yellow
            Write-Host "      Downloading individual slides..." -ForegroundColor Yellow

            # Extract presentation title from HTML
            if ($htmlContent -match '<title>([^<]*)</title>') {
                $pageTitle = $matches[1] -replace '[\\/:*?\"<>|]', ''
            } else {
                $pageTitle = "slides_" + (Get-Date -Format 'yyyyMMdd_HHmmss')
            }

            # Create directory for slides
            $slideDir = Join-Path $PWD $pageTitle
            $null = New-Item -ItemType Directory -Path $slideDir -Force
            $null = New-Item -ItemType Directory -Path (Join-Path $slideDir "slides\pic") -Force
            $null = New-Item -ItemType Directory -Path (Join-Path $slideDir "slides\thumb") -Force

            Write-Host "      Creating directory: $slideDir" -ForegroundColor Gray

            # Extract all slide image URLs
            $slideUrls = [regex]::Matches($htmlContent, 'href="([^"]*slides/pic/[^"]*)"') | ForEach-Object { $_.Groups[1].Value }

            if ($slideUrls.Count -eq 0) {
                throw "Could not extract slide URLs"
            }

            $slideCount = $slideUrls.Count
            Write-Host "      Found $slideCount slides" -ForegroundColor Gray

            # Download each slide
            $successCount = 0
            $slideNum = 1

            foreach ($slideUrl in $slideUrls) {
                $filename = Split-Path $slideUrl -Leaf
                $outputPath = Join-Path $slideDir "slides\pic\$filename"

                # Build full URL if relative
                if ($slideUrl -match "^https?://") {
                    $fullUrl = $slideUrl
                } elseif ($slideUrl -match "^/") {
                    $docUrl -match "^(https?://[^/]+)" | Out-Null
                    $fullUrl = $matches[1] + $slideUrl
                } else {
                    $htmlDir = ($docUrl -replace '/[^/]*$', '')
                    $fullUrl = "$htmlDir/$slideUrl"
                }

                Write-Host "      Downloading slide [$slideNum/$slideCount]: $filename" -ForegroundColor Gray -NoNewline

                $progressPreference = 'SilentlyContinue'
                curl -s -b $CookieFile -A $UserAgent $fullUrl -o $outputPath 2>&1 | Out-Null
                $progressPreference = 'Continue'

                if (Test-Path $outputPath) {
                    $fileSz = (Get-Item $outputPath).Length
                    if ($fileSz -gt 1000) {
                        $successCount++
                        Write-Host " - OK" -ForegroundColor Green
                    } else {
                        Write-Host " - Failed" -ForegroundColor Red
                    }
                } else {
                    Write-Host " - Failed" -ForegroundColor Red
                }

                $slideNum++
            }

            Write-Host ""
            Write-Host "      Downloaded $successCount/$slideCount slides" -ForegroundColor Green
            Write-Host ""
            Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Green
            Write-Host "║                    Download Successful!                        ║" -ForegroundColor Green
            Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Green
            Write-Host ""
            Write-Host "  Location: $slideDir"
            Write-Host "  Slides: $successCount files"
            Write-Host ""
            return
        } else {
            throw "Unsupported online viewer format"
        }
    }

    # Step 4: Download document
    Write-Host "[4/4] Downloading document..." -ForegroundColor Yellow

    # Determine file extension
    if ($docUrl -match '\.(\w+)(?:\?|$)') {
        $ext = $matches[1]
    } else {
        $ext = "pdf"
    }
    $outputFile = Join-Path $PWD "$docTitle.$ext"

    Write-Host "      Target file: $outputFile" -ForegroundColor Gray

    $progressPreference = 'SilentlyContinue'
    curl -s -b $CookieFile `
      -H "User-Agent: $UserAgent" `
      -H "Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8" `
      -H "Accept-Language: en-US,en;q=0.9" `
      -H "Referer: $Referer" `
      "$docUrl" `
      -o $outputFile 2>&1
    $progressPreference = 'Continue'

    # Check result
    if (Test-Path $outputFile) {
        $fileInfo = Get-Item $outputFile
        $fileSize = [math]::Round($fileInfo.Length / 1MB, 2)

        Write-Host ""
        Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Green
        Write-Host "║                    Download Successful!                        ║" -ForegroundColor Green
        Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Green
        Write-Host ""
        Write-Host "  Filename: $($fileInfo.Name)" -ForegroundColor White
        Write-Host "  Size: $fileSize MB" -ForegroundColor White
        Write-Host "  Location: $($fileInfo.FullName)" -ForegroundColor White
        Write-Host ""
    } else {
        throw "Download failed"
    }

    $downloadSuccess = $true

} catch {
    Write-Host ""
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    Write-Host "Possible reasons:" -ForegroundColor Yellow
    Write-Host "  1. Incorrect username or password" -ForegroundColor Gray
    Write-Host "  2. Incorrect resource ID" -ForegroundColor Gray
    Write-Host "  3. No permission to access this resource" -ForegroundColor Gray
    Write-Host "  4. Network connection issue" -ForegroundColor Gray
    Write-Host ""

    # Clean up failed file
    if (Test-Path $outputFile -ErrorAction SilentlyContinue) {
        Remove-Item $outputFile -Force -ErrorAction SilentlyContinue
    }
} finally {
    # Clean up temporary files
    if (Test-Path $CookieFile -ErrorAction SilentlyContinue) {
        Remove-Item $CookieFile -Force -ErrorAction SilentlyContinue
    }
    if (Test-Path "$env:TEMP\cas_page.html" -ErrorAction SilentlyContinue) {
        Remove-Item "$env:TEMP\cas_page.html" -Force -ErrorAction SilentlyContinue
    }
}

# Ask user if they want to continue
Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
if ($downloadSuccess) {
    Write-Host "  Download completed!" -ForegroundColor Green
} else {
    Write-Host "  Download failed. Try again?" -ForegroundColor Yellow
}
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Write-Host "Options:" -ForegroundColor Gray
Write-Host "  [Space] Continue downloading (use same credentials)" -ForegroundColor Gray
Write-Host "  [Enter]  Exit" -ForegroundColor Gray
Write-Host ""

$choice = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
if ($choice.Character -eq " " -or $choice.Character -eq 0) {
    # Clear screen for next download
    Clear-Host
    Write-Host ""
    Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║                                                            ║" -ForegroundColor Cyan
    Write-Host "║     E-Learning Courseware Download Tool v1.0                   ║" -ForegroundColor Cyan
    Write-Host "║                                                            ║" -ForegroundColor Cyan
    Write-Host "║                    Windows PowerShell                         ║" -ForegroundColor Cyan
    Write-Host "║                                                            ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Using saved credentials: $username" -ForegroundColor Green
    $continueDownload = $true
} else {
    $continueDownload = $false
}
}

Write-Host ""
Write-Host "Thank you for using E-Learning Courseware Download Tool!" -ForegroundColor Gray
Write-Host ""
Write-Host "Press any key to exit..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
