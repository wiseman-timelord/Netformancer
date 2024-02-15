# utility.ps1

function Invoke-CPUMonitoring {
    while ($true) {
        $cpuStats = Get-CpuStatistics 

        Clear-Host
        PrintProgramTitle
        
        Write-Host "CPU Name: $($cpuStats.Name)"
        Write-Host "Maximum Threads: $($cpuStats.Threads)"  # Display the number of threads
        Write-Host "Maximum Clock Speed: $($cpuStats.MaxSpeed)MHz"
        Write-Host "Current Clock Speed: $($cpuStats.CurrentSpeed)MHz"
        Write-Host "CPU Usage: $($cpuStats.Usage)%"
        Write-Host ""
        PrintProgramSeparator
        Write-Host "Select; Back = B"
		Write-Host "Refreshing In 5 Seconds..."

        if ([console]::KeyAvailable) {
            $key = [console]::ReadKey($true)
            if ($key.Key -eq "B") {
                break
            }
        }

        Start-Sleep -Seconds 5
    }
    Show-PerformanceMonitorMenu
}

function Get-CpuStatistics {
    $cpuInfo = Get-CimInstance -ClassName Win32_Processor
    $cpuUsage = (Get-Counter -Counter "\Processor(_Total)\% Processor Time").CounterSamples.CookedValue
    $cpuUsageRounded = [math]::Round($cpuUsage, 1)

    return @{
        Name = $cpuInfo.Name
        MaxSpeed = $cpuInfo.MaxClockSpeed
        CurrentSpeed = $cpuInfo.CurrentClockSpeed
        Usage = $cpuUsageRounded
        Threads = $cpuInfo.ThreadCount
    }
}


function Invoke-NETMonitoring {
    while ($true) {
        # Fetch stats before clearing the screen
        $networkStats = Get-NetworkStatistics
        $netAdapters = Get-NetAdapter | Where-Object Status -eq 'Up'

        Clear-Host
        PrintProgramTitle

        foreach ($adapter in $netAdapters) {
            Write-Host "NIC Name: $($adapter.InterfaceDescription)"
            Write-Host "Status: Up"
            Write-Host "Speed: $($adapter.LinkSpeed)"
            Write-Host "IPv4 Address: $(($adapter | Get-NetIPAddress -AddressFamily IPv4).IPAddress)"
            Write-Host "Download Rate: $($networkStats.InRate) KB/s"
            Write-Host "Upload Rate: $($networkStats.OutRate) KB/s"
            Write-Host "Discards Total: $($networkStats.Discards)"
            Write-Host "Errors Total: $($networkStats.Errors)"
            Write-Host ""
        }

        if (-not $netAdapters) {
            Write-Host "No active network adapters found."
        }

        PrintProgramSeparator
        Write-Host "Select; Back = B"
		Write-Host "Refreshing In 5 Seconds..."

        if ([console]::KeyAvailable -and ([console]::ReadKey().Key -eq "B")) {
            [console]::ReadKey($true)
            break
        }

        Start-Sleep -Seconds 5
    }
    Show-PerformanceMonitorMenu
}

function Get-NetworkStatistics {
    $networkInterface = Get-NetAdapterStatistics | Select-Object -First 1
    if ($networkInterface -eq $null) {
        return @{
            InRate = 0
            OutRate = 0
            Discards = 0
            Errors = 0
        }
    }

    $currentInbound = $networkInterface.ReceivedBytes
    $currentOutbound = $networkInterface.SentBytes
    $inRate = (($currentInbound - $Global:LastInboundBytes_f8m) * 8 / 1024) / 5
    $outRate = (($currentOutbound - $Global:LastOutboundBytes_u4x) * 8 / 1024) / 5
    $Global:LastInboundBytes_f8m = $currentInbound
    $Global:LastOutboundBytes_u4x = $currentOutbound
    $discardsTotal = if ($networkInterface.PacketsReceivedDiscarded) {$networkInterface.PacketsReceivedDiscarded} else {0}
    $errorsTotal = if ($networkInterface.PacketsReceivedErrors) {$networkInterface.PacketsReceivedErrors} else {0}

    return @{
        InRate = [math]::Round($inRate, 1)
        OutRate = [math]::Round($outRate, 1)
        Discards = $discardsTotal
        Errors = $errorsTotal
    }
}

function Get-EventsReport {
    param (
        [ValidateSet("Application", "System")]
        [string]$EventType
    )
    Clear-Host
    PrintProgramTitle
    $eventTypeName = if ($EventType -eq "Application") { "Program" } else { "System" }
    Write-Host "Requesting $eventTypeName Events.."

    $logName = "$EventType"
    $events = Get-WinEvent -LogName $logName -MaxEvents 20 | Select-Object TimeCreated, Id, LevelDisplayName, Message
    Write-Host "..$eventTypeName Events Received.`n"
    Start-Sleep -Seconds 1

    $fileName = if ($EventType -eq "Application") { "ProgramEvents.Log" } else { "SystemEvents.Log" }
    Write-Host "Exporting Report to $fileName.."
    $report = @()
    foreach ($event in $events) {
        $report += "Time: $($event.TimeCreated), ID: $($event.Id), Level: $($event.LevelDisplayName), Message: $($event.Message.split("`n")[0])"
    }
    $report | Out-File -FilePath $fileName -Force
    Write-Host "..$fileName Report Exported.`n"
    Start-Sleep -Seconds 1
    Write-Host "Check Event Report File; Returning To Menu...`n"
    Start-Sleep -Seconds 2
    Show-RecentEventsMenu
}







function Show-SystemInformation {
    Clear-Host
    PrintProgramTitle
    Ensure-AndDisplayReportStatus -ReportPath $Global:reportPath_s9v

    Write-Host "System Information:"
    $systemInfoKeys = @(
        "Machine name:",
        "Operating System:",
        "Language:",
        "System Model:",
        "BIOS:",
        "Processor:",
        "Memory:",
        "Windows Dir:",
        "DirectX Version:"
    )
    foreach ($key in $systemInfoKeys) {
        if ($Global:FetchedInfo1_9vb[$key]) {
            Write-Host ($Global:FetchedInfo1_9vb[$key].TrimStart())
        }
    }
    Shorter-FunctionsPromptHelper
}

function Show-GraphicsInformation {
    Clear-Host
    PrintProgramTitle
    Ensure-AndDisplayReportStatus -ReportPath $Global:reportPath_s9v

    Write-Host "Graphics Information:"
    for ($i = 1; $i -le 2; $i++) {
        $deviceInfo = if ($i -eq 1) { $Global:FetchedInfo1_9vb } else { $Global:FetchedInfo2_gv3 }
        if ($deviceInfo -and $deviceInfo["Graphics Card $i"]) {
            Write-Host "Graphics Card $i Details:"
            $deviceInfo["Graphics Card $i"].GetEnumerator() | ForEach-Object {
                Write-Host "$($_.Key): $($_.Value)"
            }
            Write-Host ""
        }
        if ($deviceInfo -and $deviceInfo["Monitor $i"]) {
            Write-Host "Monitor $i Details:"
            $deviceInfo["Monitor $i"].GetEnumerator() | ForEach-Object {
                Write-Host "$($_.Key): $($_.Value)"
            }
            Write-Host ""
        }
    }
    Shorter-FunctionsPromptHelper
}

function Show-AudioInformation {
    Clear-Host
    PrintProgramTitle
    Ensure-AndDisplayReportStatus -ReportPath $Global:reportPath_s9v

    Write-Host "Audio Information:"
    for ($i = 1; $i -le 2; $i++) {
        $deviceInfo = if ($i -eq 1) { $Global:FetchedInfo1_9vb } else { $Global:FetchedInfo2_gv3 }
        if ($deviceInfo -and $deviceInfo["Audio Device $i"]) {
            Write-Host "Audio Device $i Details:"
            $deviceInfo["Audio Device $i"].GetEnumerator() | ForEach-Object {
                Write-Host "$($_.Key): $($_.Value)"
            }
            Write-Host ""
        }
    }
    Shorter-FunctionsPromptHelper
}


function Shorter-FunctionsPromptHelper {
	PrintProgramSeparator
    Write-Host "Select; Back = B:" -NoNewline
    do {
        $key = [console]::ReadKey($true)
    } while ($key.Key -ne "B")
    Write-Host "`nReturning To Submenu..."
    Start-Sleep -Seconds 1
    Show-DeviceInfoMenu
}

function Ensure-AndDisplayReportStatus {
    param (
        [string]$ReportPath
    )
    Write-Host "Check Report Status.."
    if (-not (Test-RecentReport -ReportPath $ReportPath)) {
        Write-Host "..Retrieving New Report.."
        Invoke-GenerateReport -ReportPath $ReportPath
        PopulateGlobalFetchedInfo -ReportPath $ReportPath
    } else {
        Write-Host "..Using Existing Report.`n"
        PopulateGlobalFetchedInfo -ReportPath $ReportPath
    }
}

function PopulateGlobalFetchedInfo {
    param ([string]$ReportPath)
    $content = Get-Content -Path $ReportPath

    # Clear existing data
    $Global:FetchedInfo1_9vb.Clear()
    $Global:FetchedInfo2_gv3.Clear()

    # Function to extract and assign device information
    function ExtractDeviceInfo {
        param ([string]$Content, [int]$DeviceIndex, [hashtable]$DeviceInfo)

        $lines = $Content -split "`r`n"
        $isDeviceSection = $false
        $deviceCount = 0

        foreach ($line in $lines) {
            if ($line -match "---------------") {
                if ($isDeviceSection -and $deviceCount -eq $DeviceIndex) { break }
                $isDeviceSection = $false
            }
            if ($line -match "Card name:|Device Key:|Manufacturer:|Chip type:|DAC type:|Display Memory:|Dedicated Memory:|Shared Memory:|Current Mode:|HDR Support:|Driver Provider:|Driver Version:|Driver Date:|Audio Device:|Min/Max Sample Rate:") {
                if (-not $isDeviceSection) {
                    $isDeviceSection = $true
                    $deviceCount++
                    if ($deviceCount -gt $DeviceIndex) { continue }
                }
                if ($deviceCount -eq $DeviceIndex) {
                    $keyValue = $line -split ":", 2
                    $DeviceInfo[$keyValue[0].Trim()] = $keyValue[1].Trim()
                }
            }
        }
    }

    # Extract information for the first and second devices in both Display and Sound Devices sections
    $displayContent = $content | Select-String "Display Devices" -Context 0,1000
    ExtractDeviceInfo -Content $displayContent.Context.PostContext -DeviceIndex 1 -DeviceInfo $Global:FetchedInfo1_9vb
    ExtractDeviceInfo -Content $displayContent.Context.PostContext -DeviceIndex 2 -DeviceInfo $Global:FetchedInfo2_gv3

    $soundContent = $content | Select-String "Sound Devices" -Context 0,1000
    ExtractDeviceInfo -Content $soundContent.Context.PostContext -DeviceIndex 1 -DeviceInfo $Global:FetchedInfo1_9vb
    ExtractDeviceInfo -Content $soundContent.Context.PostContext -DeviceIndex 2 -DeviceInfo $Global:FetchedInfo2_gv3
}


function Test-RecentReport {
    param (
        [string]$ReportPath
    )
    if (Test-Path -Path $ReportPath) {
        $fileCreationTime = (Get-Item $ReportPath).LastWriteTime
        $currentTime = Get-Date
        $timeDifference = $currentTime.Subtract($fileCreationTime)
        return $timeDifference.TotalHours -le 1
    }
    return $false
}


function Invoke-GenerateReport {
    param (
        [string]$ReportPath
    )
    $cacheDir = Split-Path -Path $ReportPath -Parent
    if (-not (Test-Path -Path $cacheDir)) {
        New-Item -ItemType Directory -Path $cacheDir | Out-Null
    }
    Start-Process "dxdiag" -ArgumentList "/dontskip /t `"$ReportPath`"" -NoNewWindow -Wait
    $timeoutSeconds = 60
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    while (-not (Test-Path -Path $ReportPath) -and $stopwatch.Elapsed.TotalSeconds -lt $timeoutSeconds) {
        Start-Sleep -Seconds 1
    }
    if (Test-Path -Path $ReportPath) {
        Write-Host "..Report Created: $ReportPath`n"
    } else {
        Write-Host "..Report Creation Failed!`n"
		Start-Sleep -Seconds 3
		PrintProgramSeparator
		Write-Host "`nReturning To Submenu..."
        Start-Sleep -Seconds 1
        Show-DeviceInfoMenu		
    }
}



