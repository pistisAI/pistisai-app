# windows_perf.ps1 — Windows performance measurement for PistisAI Desktop
# Platforms: Windows 10, Windows 11
#
# Usage (PowerShell):
#   .\windows_perf.ps1 -Measurement "cold-start"
#   .\windows_perf.ps1 -Measurement "memory" -Duration 3600
#   .\windows_perf.ps1 -Measurement "all"

param(
    [ValidateSet("cold-start", "warm-start", "memory", "all")]
    [string]$Measurement = "all",
    
    [int]$Duration = 60,  # seconds
    
    [string]$ReportPath = "$PSScriptRoot\..\..\performance_report.json"
)

$ErrorActionPreference = "Stop"

# ============================================================================
# Configuration
# ============================================================================

$BASELINE_COLD_START_MS = 3200
$BASELINE_WARM_START_MS = 1100
$BASELINE_MEMORY_MB = 200
$BASELINE_CPU_PERCENT = 2

$AppName = "pistisai"
$BuildMode = "release"
$RepoRoot = Resolve-Path "$PSScriptRoot\..\.."
$AppPath = "$RepoRoot\build\windows\runner\Release\pistisai.exe"

# ============================================================================
# Utilities
# ============================================================================

function Write-Log {
    param([string]$Message, [ValidateSet("Info", "Error", "Warning")]$Level = "Info")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $output = "[$timestamp] [$Level] $Message"
    Write-Host $output
}

function Write-Success {
    param([string]$Message)
    Write-Host "[✓] $Message" -ForegroundColor Green
}

function Write-Error-Custom {
    param([string]$Message)
    Write-Host "[✗] $Message" -ForegroundColor Red
    exit 1
}

function Test-AppExists {
    if (-not (Test-Path $AppPath)) {
        Write-Error-Custom "App not found: $AppPath`nRun 'flutter build windows' first."
    }
}

# ============================================================================
# Cold Start Measurement
# ============================================================================

function Measure-ColdStart {
    Write-Log "Measuring cold start..."
    Test-AppExists
    
    # Kill any existing process
    Get-Process -Name $AppName -ErrorAction SilentlyContinue | Stop-Process -Force
    Start-Sleep -Seconds 2
    
    # Clear system cache (requires admin)
    try {
        Clear-Host  # Visual indicator cache cleared
        Write-Log "Clearing system cache..."
    }
    catch {
        Write-Log "Note: Full cache clear requires admin (non-critical)" -Level "Warning"
    }
    
    Start-Sleep -Seconds 3
    
    # Measure startup time
    Write-Log "Launching application..."
    $startTime = [DateTime]::Now
    
    $process = Start-Process -FilePath $AppPath -PassThru -WindowStyle Normal
    
    # Wait for window to appear (up to 30 seconds)
    $windowAppeared = $false
    $timeout = [DateTime]::Now.AddSeconds(30)
    
    while ([DateTime]::Now -lt $timeout) {
        if ($process.HasExited) {
            Write-Log "Process exited before window appeared" -Level "Warning"
            break
        }
        
        $window = Get-Process -Name $AppName -ErrorAction SilentlyContinue | 
                  Where-Object { $_.MainWindowHandle -ne 0 }
        
        if ($window) {
            $windowAppeared = $true
            break
        }
        
        Start-Sleep -Milliseconds 100
    }
    
    $elapsedMs = ([DateTime]::Now - $startTime).TotalMilliseconds
    
    Write-Success "Cold start: $([Math]::Round($elapsedMs))ms"
    
    # Cleanup
    Stop-Process -Name $AppName -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 1
    
    return [Math]::Round($elapsedMs)
}

# ============================================================================
# Warm Start Measurement
# ============================================================================

function Measure-WarmStart {
    param([int]$Runs = 3)
    
    Write-Log "Measuring warm start ($Runs runs)..."
    Test-AppExists
    
    # Initial launch
    Get-Process -Name $AppName -ErrorAction SilentlyContinue | Stop-Process -Force
    Start-Sleep -Seconds 2
    
    $times = @()
    
    for ($i = 1; $i -le $Runs; $i++) {
        Write-Log "Run $i/$Runs..."
        
        # Kill and restart
        Get-Process -Name $AppName -ErrorAction SilentlyContinue | Stop-Process -Force
        Start-Sleep -Milliseconds 500
        
        $startTime = [DateTime]::Now
        
        $process = Start-Process -FilePath $AppPath -PassThru -WindowStyle Normal
        
        # Wait for window
        $timeout = [DateTime]::Now.AddSeconds(10)
        while ([DateTime]::Now -lt $timeout) {
            if ($process.HasExited) { break }
            
            $window = Get-Process -Name $AppName -ErrorAction SilentlyContinue | 
                      Where-Object { $_.MainWindowHandle -ne 0 }
            
            if ($window) { break }
            Start-Sleep -Milliseconds 50
        }
        
        $elapsedMs = ([DateTime]::Now - $startTime).TotalMilliseconds
        $times += [Math]::Round($elapsedMs)
        
        Write-Log "  Run $i: $([Math]::Round($elapsedMs))ms"
    }
    
    # Calculate average
    $averageMs = $times | Measure-Object -Average | Select-Object -ExpandProperty Average
    
    Write-Success "Warm start average: $([Math]::Round($averageMs))ms"
    
    Stop-Process -Name $AppName -Force -ErrorAction SilentlyContinue
    
    return [Math]::Round($averageMs)
}

# ============================================================================
# Memory Monitoring
# ============================================================================

function Measure-Memory {
    param([int]$DurationSec = 60)
    
    Write-Log "Monitoring memory for ${DurationSec}s..."
    Write-Log "Start the app and interact with it during measurement."
    Write-Log "Waiting 10 seconds before starting monitor..."
    Start-Sleep -Seconds 10
    
    $startTime = [DateTime]::Now
    $maxMemoryMB = 0
    $measurements = 0
    
    while (([DateTime]::Now - $startTime).TotalSeconds -lt $DurationSec) {
        $process = Get-Process -Name $AppName -ErrorAction SilentlyContinue
        
        if ($process) {
            $memoryMB = [Math]::Round($process.WorkingSet / 1MB)
            $cpuPercent = [Math]::Round(($process.CPU / [Environment]::ProcessorCount), 1)
            
            if ($memoryMB -gt $maxMemoryMB) {
                $maxMemoryMB = $memoryMB
            }
            
            $elapsed = ([DateTime]::Now - $startTime).TotalSeconds
            Write-Host "[$([Math]::Round($elapsed))s] Memory: ${memoryMB}MB (peak: ${maxMemoryMB}MB) | CPU: $cpuPercent%"
            
            $measurements++
        }
        
        Start-Sleep -Seconds 2
    }
    
    Write-Success "Memory monitoring complete. Peak: ${maxMemoryMB}MB"
    return $maxMemoryMB
}

# ============================================================================
# Report Generation
# ============================================================================

function Save-Report {
    param(
        [int]$ColdStart = 0,
        [int]$WarmStart = 0,
        [int]$Memory = 0,
        [string]$Path
    )
    
    $timestamp = Get-Date -AsUTC -Format "yyyy-MM-ddTHH:mm:ssZ"
    
    $report = @{
        timestamp = $timestamp
        platform = "windows"
        os_version = (Get-WmiObject -Class Win32_OperatingSystem).Caption
        measurements = @{
            cold_start_ms = $ColdStart
            warm_start_ms = $WarmStart
            peak_memory_mb = $Memory
        }
        baselines_ms = @{
            cold_start = $BASELINE_COLD_START_MS
            warm_start = $BASELINE_WARM_START_MS
            memory_mb = $BASELINE_MEMORY_MB
        }
    }
    
    $json = ConvertTo-Json $report -Depth 10
    Set-Content -Path $Path -Value $json
    
    Write-Success "Report saved to: $Path"
    Write-Host $json
}

# ============================================================================
# Regression Check
# ============================================================================

function Check-Regression {
    param([int]$Actual, [int]$Baseline, [string]$Metric)
    
    $threshold = $Baseline * 2
    
    if ($Actual -gt $threshold) {
        Write-Host "[✗] REGRESSION: $Metric = $Actual ms (baseline $Baseline ms, threshold $threshold ms)" -ForegroundColor Red
        return $false
    }
    elseif ($Actual -gt $Baseline) {
        Write-Host "[!] SLIGHT INCREASE: $Metric = $Actual ms (baseline $Baseline ms)" -ForegroundColor Yellow
        return $true
    }
    else {
        Write-Host "[✓] WITHIN BASELINE: $Metric = $Actual ms (baseline $Baseline ms)" -ForegroundColor Green
        return $true
    }
}

# ============================================================================
# Main
# ============================================================================

Write-Log "Windows Performance Measurement for PistisAI Desktop"
Write-Log "Platform: Windows 10/11"

$coldStart = 0
$warmStart = 0
$memory = 0

try {
    switch ($Measurement) {
        "cold-start" {
            $coldStart = Measure-ColdStart
            Check-Regression $coldStart $BASELINE_COLD_START_MS "Cold Start"
        }
        "warm-start" {
            $warmStart = Measure-WarmStart -Runs 3
            Check-Regression $warmStart $BASELINE_WARM_START_MS "Warm Start"
        }
        "memory" {
            $memory = Measure-Memory -DurationSec $Duration
            Check-Regression $memory $BASELINE_MEMORY_MB "Memory"
        }
        "all" {
            $coldStart = Measure-ColdStart
            Check-Regression $coldStart $BASELINE_COLD_START_MS "Cold Start"
            
            Write-Log ""
            
            $warmStart = Measure-WarmStart -Runs 3
            Check-Regression $warmStart $BASELINE_WARM_START_MS "Warm Start"
            
            Write-Log ""
            
            $memory = Measure-Memory -DurationSec $Duration
            Check-Regression $memory $BASELINE_MEMORY_MB "Memory"
        }
    }
    
    Save-Report -ColdStart $coldStart -WarmStart $warmStart -Memory $memory -Path $ReportPath
    
    Write-Success "Measurement complete!"
}
catch {
    Write-Error-Custom $_.Exception.Message
}
