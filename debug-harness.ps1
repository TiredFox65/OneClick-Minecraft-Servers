param(
    [ValidateSet('all', 'list', 'help')]
    [string]$Mode = 'all',
    [string]$OnlyVersion,
    [ValidateRange(5, 3600)]
    [int]$StartupTimeoutSeconds = 900,
    [ValidateRange(1, 300)]
    [int]$ShutdownTimeoutSeconds = 30
)

$ErrorActionPreference = 'Stop'
$mainSource = Join-Path $PSScriptRoot 'Main.bat'
$reportPath = Join-Path $PSScriptRoot 'debugreport.txt'
$runId = '{0}-{1}' -f (Get-Date -Format 'yyyyMMdd-HHmmss'), ([guid]::NewGuid().ToString('N'))
$runRoot = Join-Path $env:TEMP ('ocms-debug-' + $runId)
$report = New-Object 'System.Collections.Generic.List[string]'
$counts = @{ Total = 0; Passed = 0; Failed = 0; Skipped = 0 }
$passedVersions = New-Object 'System.Collections.Generic.List[string]'
$failedVersions = New-Object 'System.Collections.Generic.List[string]'
$skippedVersions = New-Object 'System.Collections.Generic.List[string]'
$debugRconPassword = 'ocms-debug-password'
$debugRconPort = 25575

function Add-ReportLine {
    param([string]$Text)
    $report.Add($Text)
    [System.IO.File]::WriteAllLines($reportPath, $report, [System.Text.UTF8Encoding]::new($false))
}

function New-TestDirectory {
    param([string]$Parent)
    $debugDirectory = Join-Path $Parent 'debug'
    New-Item -ItemType Directory -Path $debugDirectory -Force | Out-Null
    $testMain = Join-Path $debugDirectory 'Main.bat'
    $mainContent = [System.IO.File]::ReadAllText($mainSource)
    $launchMarker = 'if defined OCMS_DEBUG_STATUS echo starting>"!OCMS_DEBUG_STATUS!"'
    $rconSetup = @'
if defined OCMS_DEBUG_RCON_PASSWORD (
>>"server\server.properties" echo enable-rcon=true
>>"server\server.properties" echo rcon.password=!OCMS_DEBUG_RCON_PASSWORD!
>>"server\server.properties" echo rcon.port=!OCMS_DEBUG_RCON_PORT!
>>"server\server.properties" echo server-ip=127.0.0.1
)
'@
    if (-not $mainContent.Contains($launchMarker)) {
        throw 'Could not add test-only RCON settings to the isolated Main.bat copy.'
    }
    $mainContent = $mainContent.Replace($launchMarker, $rconSetup + [Environment]::NewLine + $launchMarker)
    [System.IO.File]::WriteAllText($testMain, $mainContent, [System.Text.Encoding]::Default)
    return $debugDirectory
}

function Initialize-TestRcon {
    return [pscustomobject]@{
        Port = $debugRconPort
        Password = $debugRconPassword
    }
}

function Start-MainApi {
    param(
        [string]$ScriptPath,
        [string]$WorkingDirectory,
        [string]$Arguments,
        [string]$StdoutPath,
        [string]$StderrPath,
        [string]$StatusFile
    )

    $startInfo = New-Object System.Diagnostics.ProcessStartInfo
    $startInfo.FileName = $env:ComSpec
    $startInfo.Arguments = '/d /s /c ""{0}" {1} 1> "{2}" 2> "{3}""' -f $ScriptPath, $Arguments, $StdoutPath, $StderrPath
    $startInfo.WorkingDirectory = $WorkingDirectory
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.EnvironmentVariables['TELEMETRY_OPERATION_SUPPRESSED'] = '1'
    if ($StatusFile) {
        $startInfo.EnvironmentVariables['OCMS_DEBUG_STATUS'] = $StatusFile
        $startInfo.EnvironmentVariables['OCMS_DEBUG_RCON_PASSWORD'] = $debugRconPassword
        $startInfo.EnvironmentVariables['OCMS_DEBUG_RCON_PORT'] = [string]$debugRconPort
    }

    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $startInfo
    if (-not $process.Start()) {
        throw 'Could not start cmd.exe for the Main.bat API.'
    }
    return [pscustomobject]@{
        Process = $process
        StdoutPath = $StdoutPath
        StderrPath = $StderrPath
    }
}

function Read-ApiOutput {
    param([string]$Path)
    if (Test-Path -LiteralPath $Path) {
        return [System.IO.File]::ReadAllText($Path)
    }
    return ''
}

function Get-ProcessSnapshot {
    return @(Get-CimInstance -ClassName Win32_Process)
}

function Add-DescendantIds {
    param(
        [System.Collections.Generic.HashSet[int]]$KnownIds,
        [object[]]$Snapshot
    )

    $changed = $true
    while ($changed) {
        $changed = $false
        foreach ($item in $Snapshot) {
            $processId = [int]$item.ProcessId
            $parentId = [int]$item.ParentProcessId
            if ($KnownIds.Contains($parentId) -and $KnownIds.Add($processId)) {
                $changed = $true
            }
        }
    }
}

function Get-CurrentTrackedJava {
    param(
        [System.Collections.Generic.HashSet[int]]$KnownIds,
        [System.Collections.Generic.HashSet[int]]$BaselineJavaIds,
        [object[]]$Snapshot
    )

    foreach ($item in $Snapshot) {
        if ($item.Name -ieq 'java.exe' -and
            -not $BaselineJavaIds.Contains([int]$item.ProcessId) -and
            $item.CommandLine -notmatch '(?i)installer\.jar' -and
            ($KnownIds.Contains([int]$item.ProcessId) -or
                $item.CommandLine -match '(?i)(@user_jvm_args\.txt|server\.jar|win_args\.txt|minecraft_server\.\d[^ ]*\.jar|\.fabric[\\/].*\.jar)')) {
            return $item
        }
    }
    return $null
}

function Get-VerifiedTrackedJava {
    param(
        [int]$ProcessId,
        [datetime]$CreationDate,
        [System.Collections.Generic.HashSet[int]]$BaselineJavaIds
    )

    if (-not $ProcessId -or
        $BaselineJavaIds.Contains($ProcessId)) {
        return $null
    }
    $process = Get-CimInstance -ClassName Win32_Process -Filter ('ProcessId={0}' -f $ProcessId) -ErrorAction SilentlyContinue
    if (-not $process -or
        $process.Name -ine 'java.exe' -or
        $process.CommandLine -match '(?i)installer\.jar' -or
        ($CreationDate -ne [DateTime]::MinValue -and
            [datetime]$process.CreationDate -ne $CreationDate)) {
        return $null
    }
    return $process
}

function Get-ServerPort {
    param([string]$PropertiesPath)

    if (Test-Path -LiteralPath $PropertiesPath) {
        foreach ($line in [System.IO.File]::ReadAllLines($PropertiesPath)) {
            if ($line -match '^\s*server-port\s*=\s*(\d+)\s*$') {
                $port = [int]$Matches[1]
                if ($port -ge 1 -and $port -le 65535) {
                    return $port
                }
                throw "Invalid server-port value in $PropertiesPath."
            }
        }
    }
    return 25565
}

function Test-OwnedListener {
    param(
        [int]$ProcessId,
        [int]$Port
    )

    try {
        $listeners = @(Get-NetTCPConnection -State Listen -LocalPort $Port -ErrorAction Stop)
        return [pscustomobject]@{
            Owned = [bool]($listeners | Where-Object { [int]$_.OwningProcess -eq $ProcessId })
            Error = ''
        }
    }
    catch {
        return [pscustomobject]@{
            Owned = $false
            Error = $_.Exception.Message
        }
    }
}

function Write-VarInt {
    param(
        [System.IO.BinaryWriter]$Writer,
        [int]$Value
    )

    [uint32]$remaining = [BitConverter]::ToUInt32([BitConverter]::GetBytes($Value), 0)
    while (($remaining -band 0xFFFFFF80) -ne 0) {
        $Writer.Write([byte](($remaining -band 0x7F) -bor 0x80))
        $remaining = $remaining -shr 7
    }
    $Writer.Write([byte]$remaining)
}

function Read-VarInt {
    param([System.IO.Stream]$Stream)

    [uint32]$result = 0
    $position = 0
    do {
        $value = $Stream.ReadByte()
        if ($value -lt 0) {
            throw 'Connection closed while reading a Minecraft status packet.'
        }
        $result = $result -bor ([uint32]($value -band 0x7F) -shl $position)
        $position += 7
        if ($position -gt 35) {
            throw 'Invalid Minecraft VarInt in status response.'
        }
    } while (($value -band 0x80) -ne 0)
    return [int]$result
}

function Read-ExactBytes {
    param(
        [System.IO.Stream]$Stream,
        [int]$Count
    )

    $buffer = New-Object byte[] $Count
    $offset = 0
    while ($offset -lt $Count) {
        $read = $Stream.Read($buffer, $offset, $Count - $offset)
        if ($read -le 0) {
            throw 'Connection closed while reading a Minecraft status packet.'
        }
        $offset += $read
    }
    return ,$buffer
}

function Test-MinecraftStatus {
    param(
        [string]$HostName,
        [int]$Port
    )

    $client = New-Object System.Net.Sockets.TcpClient
    try {
        $asyncResult = $client.BeginConnect($HostName, $Port, $null, $null)
        if (-not $asyncResult.AsyncWaitHandle.WaitOne(1200)) {
            throw 'TCP connection timed out.'
        }
        $client.EndConnect($asyncResult)
        $stream = $client.GetStream()
        $stream.ReadTimeout = 1500
        $stream.WriteTimeout = 1500

        $handshake = New-Object System.IO.MemoryStream
        $writer = New-Object System.IO.BinaryWriter($handshake)
        Write-VarInt $writer 0
        Write-VarInt $writer -1
        $hostBytes = [System.Text.Encoding]::UTF8.GetBytes($HostName)
        Write-VarInt $writer $hostBytes.Length
        $writer.Write($hostBytes)
        $writer.Write([byte](($Port -shr 8) -band 0xFF))
        $writer.Write([byte]($Port -band 0xFF))
        Write-VarInt $writer 1
        $handshakeBytes = $handshake.ToArray()
        $frame = New-Object System.IO.MemoryStream
        $frameWriter = New-Object System.IO.BinaryWriter($frame)
        Write-VarInt $frameWriter $handshakeBytes.Length
        $frameWriter.Write($handshakeBytes)
        $frameWriter.Flush()
        $frameBytes = $frame.ToArray()
        $stream.Write($frameBytes, 0, $frameBytes.Length)

        $stream.Write([byte[]](1, 0), 0, 2)
        $packetLength = Read-VarInt $stream
        if ($packetLength -lt 2 -or $packetLength -gt 1048576) {
            throw 'Invalid Minecraft status packet length.'
        }
        $packet = Read-ExactBytes $stream $packetLength
        $packetStream = New-Object System.IO.MemoryStream(,$packet)
        $packetId = Read-VarInt $packetStream
        if ($packetId -ne 0) {
            throw "Unexpected Minecraft status packet id $packetId."
        }
        $jsonLength = Read-VarInt $packetStream
        if ($jsonLength -lt 2 -or $jsonLength -gt ($packetLength - $packetStream.Position)) {
            throw 'Invalid JSON length in Minecraft status response.'
        }
        $jsonBytes = Read-ExactBytes $packetStream $jsonLength
        $status = ([System.Text.Encoding]::UTF8.GetString($jsonBytes)) | ConvertFrom-Json
        if (-not $status.version -or -not $status.version.name) {
            throw 'Minecraft status response did not contain a server version.'
        }
        return [pscustomobject]@{
            Success = $true
            Version = [string]$status.version.name
            Error = ''
        }
    }
    catch {
        return [pscustomobject]@{
            Success = $false
            Version = ''
            Error = $_.Exception.Message
        }
    }
    finally {
        $client.Dispose()
    }
}

function Read-RconResponse {
    param([System.IO.Stream]$Stream)

    $lengthBytes = Read-ExactBytes $Stream 4
    $length = [BitConverter]::ToInt32($lengthBytes, 0)
    if ($length -lt 10 -or $length -gt 1048576) {
        throw 'Invalid RCON response packet length.'
    }
    $body = Read-ExactBytes $Stream $length
    return [pscustomobject]@{
        Id = [BitConverter]::ToInt32($body, 0)
        Type = [BitConverter]::ToInt32($body, 4)
        Payload = [System.Text.Encoding]::UTF8.GetString($body, 8, $length - 10)
    }
}

function Send-RconPacket {
    param(
        [System.IO.Stream]$Stream,
        [int]$Id,
        [int]$Type,
        [string]$Text
    )

    $textBytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
    $length = 4 + 4 + $textBytes.Length + 2
    $packet = New-Object System.IO.MemoryStream
    $writer = New-Object System.IO.BinaryWriter($packet)
    $writer.Write([int]$length)
    $writer.Write([int]$Id)
    $writer.Write([int]$Type)
    $writer.Write($textBytes)
    $writer.Write([byte]0)
    $writer.Write([byte]0)
    $writer.Flush()
    $bytes = $packet.ToArray()
    $Stream.Write($bytes, 0, $bytes.Length)
}

function Try-RconStop {
    param([hashtable]$Properties)

    if ($Properties['enable-rcon'] -ne 'true' -or
        [string]::IsNullOrWhiteSpace($Properties['rcon.password'])) {
        return [pscustomobject]@{ Available = $false; Sent = $false; Detail = 'RCON is disabled or has no password.' }
    }

    $rconPort = 25575
    if ($Properties['rcon.port'] -match '^\d+$') {
        $rconPort = [int]$Properties['rcon.port']
    }
    $client = New-Object System.Net.Sockets.TcpClient
    try {
        $client.ReceiveTimeout = 2000
        $client.SendTimeout = 2000
        $client.Connect('127.0.0.1', $rconPort)
        $stream = $client.GetStream()
        Send-RconPacket $stream 101 3 $Properties['rcon.password']
        $auth = Read-RconResponse $stream
        if ($auth.Id -ne 101) {
            return [pscustomobject]@{ Available = $true; Sent = $false; Detail = 'RCON authentication was rejected.' }
        }
        Send-RconPacket $stream 102 2 'stop'
        $null = Read-RconResponse $stream
        return [pscustomobject]@{ Available = $true; Sent = $true; Detail = 'RCON stop command sent.' }
    }
    catch {
        return [pscustomobject]@{ Available = $true; Sent = $false; Detail = $_.Exception.Message }
    }
    finally {
        $client.Dispose()
    }
}

function Get-LogTail {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        return '(server log not created)'
    }
    return ((Get-Content -LiteralPath $Path -Tail 30 -ErrorAction Stop) -join ' | ')
}

function Test-ServerStartupComplete {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        return $false
    }
    return [bool](Get-Content -LiteralPath $Path -Tail 120 -ErrorAction Stop |
        Where-Object { $_ -match 'Done \([^)]+\)! For help, type' } |
        Select-Object -First 1)
}

function Test-Version {
    param(
        [string]$ItemVersion,
        [int]$Index,
        [int]$Total
    )

    $counts.Total++
    $startedAt = Get-Date
    $caseRoot = Join-Path $runRoot $ItemVersion
    $workingDirectory = New-TestDirectory $caseRoot
    $serverDirectory = Join-Path $workingDirectory 'server'
    $serverLog = Join-Path $serverDirectory 'logs\latest.log'
    $apiLog = Join-Path $caseRoot 'api-create.log'
    $apiErrorLog = Join-Path $caseRoot 'api-create.stderr.log'
    $serverStatusFile = Join-Path $caseRoot 'mcserver-status.txt'
    $finalResult = 'TEST_ERROR'
    $apiExitCode = 'NOT_STARTED'
    $javaPid = $null
    $javaCreationDate = [DateTime]::MinValue
    $api = $null
    $apiProcess = $null
    $ownedJava = $null
    $descendantIds = New-Object 'System.Collections.Generic.HashSet[int]'
    $baselineJavaIds = New-Object 'System.Collections.Generic.HashSet[int]'
    $serverPort = 25565
    $readyVersion = ''
    $statusError = ''
    $portCheckError = ''
    $apiExitedAt = $null
    $shutdownMethod = 'NONE'
    $shutdownOutcome = 'NOT_ATTEMPTED'
    $creationOutcome = 'NOT_STARTED'
    $readiness = 'NOT_READY'
    $phase = 'Preparing isolated test directory'
    $lastConsoleUpdate = [DateTime]::MinValue
    $lastSeenJavaPid = $null
    $lastServerMarker = ''
    $serverExitObservedAt = $null

    Add-ReportLine ''
    Add-ReportLine ('VERSION=' + $ItemVersion)
    Add-ReportLine ('STARTED=' + $startedAt.ToString('o'))
    Add-ReportLine ('WORKING_DIRECTORY=' + $workingDirectory)
    Write-Host ('[{0}/{1}] Testing {2}' -f $Index, $Total, $ItemVersion)
    Write-Progress -Id 1 -Activity 'Testing supported Minecraft versions' `
        -Status ('Version {0} of {1}: {2}' -f $Index, $Total, $ItemVersion) `
        -PercentComplete ([Math]::Floor((($Index - 1) / [double]$Total) * 100))
    Write-Progress -Id 2 -ParentId 1 -Activity ('Testing ' + $ItemVersion) `
        -Status $phase -PercentComplete 0

    try {
        $baselineSnapshot = Get-ProcessSnapshot
        foreach ($item in $baselineSnapshot) {
            if ($item.Name -ieq 'java.exe') {
                $null = $baselineJavaIds.Add([int]$item.ProcessId)
            }
        }
        $precheckDeadline = [DateTime]::UtcNow.AddSeconds(60)
        $lastPrecheckUpdate = [DateTime]::MinValue
        while ($baselineJavaIds.Count -gt 0 -and [DateTime]::UtcNow -lt $precheckDeadline) {
            if (([DateTime]::UtcNow - $lastPrecheckUpdate).TotalSeconds -ge 5) {
                Write-Host ('[{0}/{1}] Waiting for existing Java process(es) to exit before {2}; remaining time {3}s.' -f `
                    $Index, $Total, $ItemVersion, [Math]::Ceiling(($precheckDeadline - [DateTime]::UtcNow).TotalSeconds))
                $lastPrecheckUpdate = [DateTime]::UtcNow
            }
            Start-Sleep -Milliseconds 500
            $baselineJavaIds.Clear()
            foreach ($item in (Get-ProcessSnapshot)) {
                if ($item.Name -ieq 'java.exe') {
                    $null = $baselineJavaIds.Add([int]$item.ProcessId)
                }
            }
        }
        if ($baselineJavaIds.Count -gt 0) {
            $creationOutcome = 'SKIPPED_SAFETY_JAVA_ALREADY_RUNNING'
            $finalResult = 'SKIPPED'
            $counts.Skipped++
            Write-Host ('[{0}/{1}] SKIPPED {2}: Java is already running; Main.bat refuses server creation while Java is active.' -f $Index, $Total, $ItemVersion)
            Add-ReportLine ('JAVA_PRECHECK=BLOCKED;PIDS=' + (($baselineJavaIds | Sort-Object) -join ','))
            Add-ReportLine ('CREATION=' + $creationOutcome)
            Add-ReportLine 'SERVER_PROCESS=NOT_STARTED'
            Add-ReportLine 'READINESS=NOT_TESTED'
            Add-ReportLine 'SHUTDOWN=NOT_ATTEMPTED'
            Add-ReportLine ('FINAL=' + $finalResult)
            return
        }

        $testRcon = Initialize-TestRcon
        Add-ReportLine ('RCON_SETUP=INJECTED_BEFORE_SERVER_LAUNCH;PORT=' + $testRcon.Port)
        $testStartedUtc = [DateTime]::UtcNow
        $createArguments = 'api -c "{0}" -s' -f $ItemVersion
        $phase = 'Running Main.bat API create and downloading/installing server files'
        Write-Host ('[{0}/{1}] STEP 1/4 - {2}: installing server files.' -f $Index, $Total, $ItemVersion)
        $api = Start-MainApi (Join-Path $workingDirectory 'Main.bat') $workingDirectory `
            $createArguments $apiLog $apiErrorLog $serverStatusFile
        $apiProcess = $api.Process
        Add-ReportLine ('SERVER_STATUS_FILE=' + $serverStatusFile)
        $null = $descendantIds.Add([int]$apiProcess.Id)
        $deadline = [DateTime]::UtcNow.AddSeconds($StartupTimeoutSeconds)
        $apiFinished = $false
        $apiExitCode = 'RUNNING'

        while ([DateTime]::UtcNow -lt $deadline) {
            if (Test-Path -LiteralPath $serverStatusFile) {
                $serverMarker = [System.IO.File]::ReadAllText($serverStatusFile).Trim()
                if ($serverMarker -and $serverMarker -ne $lastServerMarker) {
                    $lastServerMarker = $serverMarker
                    Write-Host ('[{0}/{1}] {2}: Main.bat server launch status is {3}.' -f $Index, $Total, $ItemVersion, $serverMarker)
                    if ($serverMarker -eq 'running') {
                        $phase = 'Server process launched; waiting for protocol readiness'
                    }
                }
            }
            $snapshot = Get-ProcessSnapshot
            Add-DescendantIds $descendantIds $snapshot
            $ownedJava = Get-CurrentTrackedJava $descendantIds $baselineJavaIds $snapshot
            if ($ownedJava) {
                $javaPid = [int]$ownedJava.ProcessId
                $javaCreationDate = [datetime]$ownedJava.CreationDate
                $serverExitObservedAt = $null
            }

            if ($lastServerMarker -eq 'exited' -and -not $ownedJava) {
                $serverRunScript = Join-Path $serverDirectory 'run.bat'
                $launchScript = ''
                if (Test-Path -LiteralPath $serverRunScript) {
                    $launchScript = [System.IO.File]::ReadAllText($serverRunScript)
                }
                $missingLaunchCommand = $launchScript -notmatch '(?im)^\s*@?java(?:\.exe)?\s'
                if ($missingLaunchCommand -or
                    ($serverExitObservedAt -and ([DateTime]::UtcNow - $serverExitObservedAt).TotalSeconds -ge 5)) {
                    $creationOutcome = 'CREATED'
                    if ($missingLaunchCommand) {
                        $finalResult = 'STARTUP_FAILED'
                        $readiness = 'SERVER_LAUNCH_COMMAND_MISSING'
                        $statusError = 'Main.bat generated server\run.bat without a Java launch command for this version.'
                    }
                    else {
                        $finalResult = 'STARTUP_FAILED'
                        $readiness = 'SERVER_PROCESS_EXITED_BEFORE_READY'
                        $statusError = 'The server process exited before it became fully ready.'
                    }
                    $phase = 'Server launch failed; recording this version as failed'
                    if (-not $apiFinished) {
                        if ($apiProcess.HasExited) {
                            $apiProcess.WaitForExit()
                            $apiExitCode = [string]$apiProcess.ExitCode
                        }
                        else {
                            try {
                                $apiProcess.Kill()
                            }
                            catch {
                                if (-not $apiProcess.HasExited) {
                                    throw
                                }
                            }
                            $apiProcess.WaitForExit()
                            $apiExitCode = 'ABORTED_AFTER_SERVER_EXIT'
                        }
                        $apiFinished = $true
                        $apiExitedAt = [DateTime]::UtcNow
                    }
                    Write-Host ('[{0}/{1}] FAILED {2}: {3} Moving to the next version.' -f `
                        $Index, $Total, $ItemVersion, $statusError)
                    break
                }
                elseif (-not $serverExitObservedAt) {
                    $serverExitObservedAt = [DateTime]::UtcNow
                    Write-Host ('[{0}/{1}] {2}: server launcher exited without a running server; confirming process exit for 5 seconds.' -f `
                        $Index, $Total, $ItemVersion)
                }
            }

            if (-not $apiFinished -and $apiProcess.HasExited) {
                $apiProcess.WaitForExit()
                $apiFinished = $true
                $apiExitedAt = [DateTime]::UtcNow
                $apiExitCode = [string]$apiProcess.ExitCode

                $requiredFiles = @(
                    (Join-Path $serverDirectory 'run.bat'),
                    (Join-Path $serverDirectory 'eula.txt'),
                    (Join-Path $serverDirectory 'user_jvm_args.txt')
                )
                $missing = @($requiredFiles | Where-Object { -not (Test-Path -LiteralPath $_) })
                $serverJars = @()
                if (Test-Path -LiteralPath $serverDirectory) {
                    $serverJars = @(Get-ChildItem -LiteralPath $serverDirectory -Filter '*.jar' -File -Recurse -ErrorAction Stop)
                }
                # Main.bat returns 2 after its API create path; artifacts distinguish success from rejection.
                if ($apiProcess.ExitCode -ne 2 -or $missing.Count -gt 0 -or $serverJars.Count -eq 0) {
                    $creationOutcome = 'CREATE_FAILED'
                    $finalResult = 'CREATE_FAILED'
                    $details = @()
                    if ($apiProcess.ExitCode -ne 2) { $details += ('unexpected API exit code ' + $apiProcess.ExitCode) }
                    if ($missing.Count -gt 0) { $details += ('missing artifacts: ' + ($missing -join ', ')) }
                    if ($serverJars.Count -eq 0) { $details += 'no server JAR found' }
                    $creationDetails = $details -join '; '
                    Write-Host ('[{0}/{1}] {2}: creation failed (API exit {3}).' -f $Index, $Total, $ItemVersion, $apiExitCode)
                    break
                }
                $creationOutcome = 'CREATED'
                $serverPort = Get-ServerPort (Join-Path $serverDirectory 'server.properties')
                $phase = 'Waiting for the server process and protocol readiness'
                Write-Host ('[{0}/{1}] STEP 2/4 - {2}: files created; waiting up to {3}s for full startup.' -f `
                    $Index, $Total, $ItemVersion, $StartupTimeoutSeconds)
            }

            if ($apiFinished -and $creationOutcome -eq 'CREATED') {
                $currentJava = Get-VerifiedTrackedJava $javaPid $javaCreationDate $baselineJavaIds
                if (-not $currentJava) {
                    $javaPid = $null
                    $javaCreationDate = [DateTime]::MinValue
                    $ownedJava = $null
                }
                if ($currentJava) {
                    if ($lastSeenJavaPid -ne $javaPid) {
                        $lastSeenJavaPid = $javaPid
                        Write-Host ('[{0}/{1}] {2}: server process detected (PID {3}); checking Minecraft status.' -f $Index, $Total, $ItemVersion, $javaPid)
                    }
                    $status = Test-MinecraftStatus '127.0.0.1' $serverPort
                    $listener = Test-OwnedListener $javaPid $serverPort
                    if ($status.Success -and $listener.Owned) {
                        $portCheckError = ''
                        if (Test-ServerStartupComplete $serverLog) {
                            $readiness = 'FULL_STARTUP_LOG_AND_MINECRAFT_STATUS'
                            $readyVersion = $status.Version
                            $statusError = ''
                            $finalResult = 'READY'
                            Write-Host ('[{0}/{1}] STEP 3/4 - {2}: fully started as {3}; beginning shutdown.' -f `
                                $Index, $Total, $ItemVersion, $readyVersion)
                            break
                        }
                        $phase = 'Minecraft is responding; waiting for world loading and the server Done message'
                        $statusError = ''
                    }
                    if ($status.Success) {
                        $statusError = 'Minecraft status replied, but the tracked server process does not own the configured listening port.'
                    }
                    else {
                        $statusError = $status.Error
                    }
                    if ($listener.Error) {
                        $portCheckError = $listener.Error
                    }
                }
                elseif ($apiProcess.HasExited) {
                    $creationOutcome = 'CREATED'
                }
            }

            $elapsed = ([DateTime]::UtcNow - $testStartedUtc).TotalSeconds
            if (-not $apiFinished) {
                $subProgress = [Math]::Min(60, [Math]::Floor(($elapsed / $StartupTimeoutSeconds) * 60))
            }
            else {
                $readinessElapsed = ([DateTime]::UtcNow - $apiExitedAt).TotalSeconds
                $subProgress = 60 + [Math]::Min(35, [Math]::Floor(($readinessElapsed / $StartupTimeoutSeconds) * 35))
            }
            Write-Progress -Id 2 -ParentId 1 -Activity ('Testing ' + $ItemVersion) `
                -Status ('{0}; elapsed {1}s' -f $phase, [Math]::Floor($elapsed)) `
                -PercentComplete $subProgress
            if (([DateTime]::UtcNow - $lastConsoleUpdate).TotalSeconds -ge 5) {
                Write-Host ('[{0}/{1}] {2}: {3} (elapsed {4}s).' -f $Index, $Total, $ItemVersion, $phase, [Math]::Floor($elapsed))
                $lastConsoleUpdate = [DateTime]::UtcNow
            }
            Start-Sleep -Milliseconds 500
        }

        if (-not $apiFinished -and $apiProcess.HasExited) {
            $apiProcess.WaitForExit()
            $apiFinished = $true
            $apiExitedAt = [DateTime]::UtcNow
            $apiExitCode = [string]$apiProcess.ExitCode
        }
        if (-not $apiFinished) {
            $apiExitCode = 'TIMEOUT'
            $creationOutcome = 'CREATE_TIMEOUT'
            $finalResult = 'CREATE_FAILED'
            try { $apiProcess.Kill() } catch {}
            try { $apiProcess.WaitForExit() } catch {}
        }
        elseif ($creationOutcome -eq 'CREATED' -and
            $finalResult -ne 'READY' -and
            $finalResult -ne 'STARTUP_FAILED') {
            $currentSnapshot = Get-ProcessSnapshot
            Add-DescendantIds $descendantIds $currentSnapshot
            $ownedJava = Get-CurrentTrackedJava $descendantIds $baselineJavaIds $currentSnapshot
            if ($ownedJava) {
                $javaPid = [int]$ownedJava.ProcessId
                $javaCreationDate = [datetime]$ownedJava.CreationDate
                $finalResult = 'STARTUP_TIMEOUT'
                $readiness = 'STARTUP_TIMEOUT'
            }
            else {
                $finalResult = 'STARTUP_FAILED'
                $readiness = 'SERVER_PROCESS_NOT_FOUND_OR_EXITED'
            }
        }

        Add-ReportLine ('API_EXIT_CODE=' + $apiExitCode)
        Add-ReportLine ('CREATION=' + $creationOutcome)
        if ($creationDetails) { Add-ReportLine ('DETAILS=' + $creationDetails) }
        Add-ReportLine ('SERVER_PROCESS=' + $(if ($javaPid) { $javaPid } else { 'NOT_FOUND' }))
        Add-ReportLine ('READINESS=' + $readiness)
        if ($lastServerMarker) { Add-ReportLine ('SERVER_LAUNCH_STATUS=' + $lastServerMarker) }
        Add-ReportLine ('API_STDOUT_LOG=' + $apiLog)
        Add-ReportLine ('API_STDERR_LOG=' + $apiErrorLog)
        if ($readyVersion) { Add-ReportLine ('STATUS_VERSION=' + $readyVersion) }
        if ($statusError) { Add-ReportLine ('LAST_STATUS_ERROR=' + $statusError) }
        if ($portCheckError) { Add-ReportLine ('PORT_CHECK_ERROR=' + $portCheckError) }
        if (Test-Path -LiteralPath $serverLog) { Add-ReportLine ('SERVER_LOG_TAIL=' + (Get-LogTail $serverLog)) }
        if (Test-Path -LiteralPath $apiLog) { Add-ReportLine ('API_STDOUT_LOG=' + $apiLog) }
        if (Test-Path -LiteralPath $apiErrorLog) { Add-ReportLine ('API_STDERR_LOG=' + $apiErrorLog) }

        if ($finalResult -eq 'READY' -and $javaPid) {
            $phase = 'Stopping the ready server'
            Write-Host ('[{0}/{1}] STEP 4/4 - {2}: sending graceful stop.' -f $Index, $Total, $ItemVersion)
            Write-Progress -Id 2 -ParentId 1 -Activity ('Testing ' + $ItemVersion) `
                -Status $phase -PercentComplete 97
            $properties = @{
                'enable-rcon' = 'true'
                'rcon.password' = $testRcon.Password
                'rcon.port' = [string]$testRcon.Port
            }
            $rconResult = Try-RconStop $properties
            if ($rconResult.Sent) {
                $shutdownMethod = 'RCON_STOP'
                Write-Host ('[{0}/{1}] {2}: graceful RCON stop sent; waiting for server exit.' -f $Index, $Total, $ItemVersion)
                $shutdownDeadline = [DateTime]::UtcNow.AddSeconds($ShutdownTimeoutSeconds)
                do {
                    Start-Sleep -Milliseconds 500
                    $stillRunning = Get-CimInstance -ClassName Win32_Process -Filter ('ProcessId={0}' -f $javaPid) -ErrorAction SilentlyContinue
                } while ($stillRunning -and [DateTime]::UtcNow -lt $shutdownDeadline)
                if (-not $stillRunning) {
                    $shutdownOutcome = 'STOPPED'
                    Write-Host ('[{0}/{1}] {2}: server exited cleanly.' -f $Index, $Total, $ItemVersion)
                }
                else {
                    $shutdownOutcome = 'SHUTDOWN_TIMEOUT'
                    Write-Host ('[{0}/{1}] {2}: graceful shutdown timed out; forcing owned-process cleanup.' -f $Index, $Total, $ItemVersion)
                }
            }
            else {
                $shutdownMethod = 'UNAVAILABLE'
                $shutdownOutcome = 'NO_GRACEFUL_CONTROL'
                Add-ReportLine ('SHUTDOWN_LIMITATION=' + $rconResult.Detail)
                Write-Host ('[{0}/{1}] {2}: graceful RCON stop unavailable ({3}); using owned-process cleanup.' -f $Index, $Total, $ItemVersion, $rconResult.Detail)
            }

            if ($shutdownOutcome -ne 'STOPPED') {
                $currentJava = Get-VerifiedTrackedJava $javaPid $javaCreationDate $baselineJavaIds
                if ($currentJava) {
                    Stop-Process -Id $javaPid -Force -ErrorAction Stop
                    $shutdownOutcome += ';OWNED_PROCESS_FORCE_CLEANUP'
                    $cleanupDeadline = [DateTime]::UtcNow.AddSeconds(10)
                    do {
                        Start-Sleep -Milliseconds 250
                        $currentJava = Get-VerifiedTrackedJava $javaPid $javaCreationDate $baselineJavaIds
                    } while ($currentJava -and [DateTime]::UtcNow -lt $cleanupDeadline)
                    if ($currentJava) {
                        $shutdownOutcome += ';CLEANUP_TIMEOUT'
                    }
                }
                if ($shutdownOutcome -eq 'NO_GRACEFUL_CONTROL;OWNED_PROCESS_FORCE_CLEANUP') {
                    $finalResult = 'SHUTDOWN_FAILED'
                }
                elseif ($shutdownOutcome -like 'SHUTDOWN_TIMEOUT*') {
                    $finalResult = 'SHUTDOWN_FAILED'
                }
            }
        }
    }
    catch {
        $finalResult = 'TEST_ERROR'
        Add-ReportLine ('ERROR=' + $_.Exception.Message)
        if ($apiProcess -and -not $apiProcess.HasExited) {
            try { $apiProcess.Kill() } catch {}
        }
    }
    finally {
        $remainingOwnedJava = Get-VerifiedTrackedJava $javaPid $javaCreationDate $baselineJavaIds
        if ($remainingOwnedJava) {
            try {
                Write-Host ('[{0}/{1}] {2}: cleaning up owned server process (PID {3}).' -f $Index, $Total, $ItemVersion, $javaPid)
                Stop-Process -Id $javaPid -Force -ErrorAction Stop
                if ($shutdownMethod -eq 'NONE') {
                    $shutdownMethod = 'OWNED_PID_FORCE_CLEANUP'
                }
                $cleanupDeadline = [DateTime]::UtcNow.AddSeconds(10)
                do {
                    Start-Sleep -Milliseconds 250
                    $remainingOwnedJava = Get-VerifiedTrackedJava $javaPid $javaCreationDate $baselineJavaIds
                } while ($remainingOwnedJava -and [DateTime]::UtcNow -lt $cleanupDeadline)
                if ($remainingOwnedJava) {
                    $shutdownOutcome = 'OWNED_PROCESS_CLEANUP_TIMEOUT'
                }
                elseif ($shutdownOutcome -eq 'NOT_ATTEMPTED') {
                    $shutdownOutcome = 'OWNED_PROCESS_FORCE_CLEANUP'
                }
                if ($finalResult -eq 'READY') {
                    $finalResult = 'SHUTDOWN_FAILED'
                }
            }
            catch {
                $shutdownOutcome = 'OWNED_PROCESS_CLEANUP_FAILED'
                Add-ReportLine ('CLEANUP_ERROR=' + $_.Exception.Message)
                if ($finalResult -eq 'READY') {
                    $finalResult = 'SHUTDOWN_FAILED'
                }
            }
        }
        elseif ($javaPid -and $shutdownOutcome -eq 'NOT_ATTEMPTED') {
            $shutdownMethod = 'OWNED_PID_ALREADY_EXITED'
            $shutdownOutcome = 'STOPPED'
        }
        if ($api) {
            try {
                $apiOutput = Read-ApiOutput $api.StdoutPath
                if ($apiOutput) {
                    Add-ReportLine ('API_OUTPUT_TAIL=' + (($apiOutput -split "\r?\n" | Select-Object -Last 12) -join ' | '))
                }
                $apiError = Read-ApiOutput $api.StderrPath
                if ($apiError) {
                    Add-ReportLine ('API_ERROR_TAIL=' + (($apiError -split "\r?\n" | Select-Object -Last 12) -join ' | '))
                }
            }
            catch {
                Add-ReportLine ('API_OUTPUT_CAPTURE_ERROR=' + $_.Exception.Message)
            }
        }
        if ($finalResult -eq 'READY') {
            $counts.Passed++
            $passedVersions.Add($ItemVersion)
        }
        elseif ($finalResult -eq 'SKIPPED') {
            $skippedVersions.Add($ItemVersion)
        }
        else {
            $counts.Failed++
            $failedVersions.Add($ItemVersion)
        }
        $elapsed = [Math]::Round(((Get-Date) - $startedAt).TotalSeconds, 1)
        Add-ReportLine ('SHUTDOWN_METHOD=' + $shutdownMethod)
        Add-ReportLine ('SHUTDOWN_OUTCOME=' + $shutdownOutcome)
        Add-ReportLine ('ELAPSED_SECONDS=' + $elapsed)
        Add-ReportLine ('FINAL=' + $finalResult)
        Write-Progress -Id 2 -ParentId 1 -Activity ('Testing ' + $ItemVersion) -Completed
        Write-Progress -Id 1 -Activity 'Testing supported Minecraft versions' `
            -Status ('Completed version {0} of {1}' -f $Index, $Total) `
            -PercentComplete ([Math]::Floor(($Index / [double]$Total) * 100))
        Write-Host ('[{0}/{1}] {2}: {3} (shutdown: {4}).' -f $Index, $Total, $ItemVersion, $finalResult, $shutdownOutcome)
    }
}

try {
    if ($Mode -eq 'help') {
        @(
            'Usage: debug.bat [all | debug | single | list | help]'
            'No arguments, "debug", and "single" launch the Main.bat GUI in the debug folder.'
            '"all" tests every version returned by the Main.bat API, one at a time.'
            '"list" prints discovered versions without installing or launching a server.'
            'Optional: -OnlyVersion VERSION tests one discovered version; -StartupTimeoutSeconds N (default 900); -ShutdownTimeoutSeconds N.'
            'Status steps: 1 installs files; 2 waits for full startup; 3 confirms readiness; 4 requests graceful shutdown.'
            'Exit codes: 0 all passed; 1 test/discovery/harness failure; 2 survey confirmation canceled.'
        )
        exit 0
    }
    if (-not (Test-Path -LiteralPath $mainSource)) {
        throw "Main.bat was not found at $mainSource."
    }
    New-Item -ItemType Directory -Path $runRoot -Force | Out-Null
    if ($Mode -ne 'list') {
        Add-ReportLine ('RUN_STARTED=' + (Get-Date).ToString('o'))
        Add-ReportLine ('RUN_DIRECTORY=' + $runRoot)
    }

    $discoveryDirectory = New-TestDirectory (Join-Path $runRoot 'discovery')
    $discoveryStdoutPath = Join-Path $runRoot 'version-discovery.stdout.log'
    $discoveryStderrPath = Join-Path $runRoot 'version-discovery.stderr.log'
    $discovery = Start-MainApi (Join-Path $discoveryDirectory 'Main.bat') $discoveryDirectory `
        'api -g MCVERSIONS' $discoveryStdoutPath $discoveryStderrPath
    if (-not $discovery.Process.WaitForExit(60000)) {
        try { $discovery.Process.Kill() } catch {}
        throw 'Main.bat api -g MCVERSIONS timed out after 60 seconds.'
    }
    $discovery.Process.WaitForExit()
    $discoveryStdout = Read-ApiOutput $discovery.StdoutPath
    $discoveryStderr = Read-ApiOutput $discovery.StderrPath
    $discoveryLog = Join-Path $runRoot 'version-discovery.log'
    [System.IO.File]::WriteAllText($discoveryLog, $discoveryStdout + $discoveryStderr, [System.Text.UTF8Encoding]::new($false))
    if ($discovery.Process.ExitCode -ne 0) {
        throw ('Version discovery API exited with code {0}. Output: {1}' -f $discovery.Process.ExitCode, $discoveryLog)
    }

    $versions = @(
        $discoveryStdout -split "\r?\n" |
            ForEach-Object { $_.Trim() } |
            Where-Object { $_ -match '^[A-Za-z][A-Za-z0-9]*-\d+(?:\.\d+)*$' } |
            Select-Object -Unique
    )
    if ($versions.Count -eq 0) {
        throw ('Version discovery returned no valid version identifiers. Raw API output: {0}' -f $discoveryLog)
    }
    if ($OnlyVersion) {
        $selectedVersions = @($versions | Where-Object { $_ -ieq $OnlyVersion })
        if ($selectedVersions.Count -eq 0) {
            throw ('Version {0} was not returned by the Main.bat API.' -f $OnlyVersion)
        }
        $versions = $selectedVersions
    }
    if ($Mode -eq 'list') {
        $versions
        exit 0
    }
    Add-ReportLine ('DISCOVERED_VERSIONS=' + ($versions -join ','))
    Add-ReportLine ('DISCOVERY_LOG=' + $discoveryLog)
    if ($OnlyVersion) {
        Write-Host ('Selected {0} from the supported-version API. Run logs and debugreport.txt: {1}' -f $versions[0], $runRoot)
    }
    else {
        Write-Host ('Discovered {0} supported versions. Run logs and debugreport.txt: {1}' -f $versions.Count, $runRoot)
    }

    for ($index = 0; $index -lt $versions.Count; $index++) {
        Test-Version $versions[$index] ($index + 1) $versions.Count
    }

    Write-Progress -Id 2 -Completed -Activity 'Current version'
    Write-Progress -Id 1 -Completed -Activity 'Testing supported Minecraft versions'
    Add-ReportLine ('SUMMARY_TOTAL=' + $counts.Total)
    Add-ReportLine ('SUMMARY_PASSED=' + $counts.Passed)
    Add-ReportLine ('SUMMARY_FAILED=' + $counts.Failed)
    Add-ReportLine ('SUMMARY_SKIPPED=' + $counts.Skipped)
    Add-ReportLine ('SUMMARY_PASSED_VERSIONS=' + $(if ($passedVersions.Count) { $passedVersions -join ', ' } else { 'NONE' }))
    Add-ReportLine ('SUMMARY_FAILED_VERSIONS=' + $(if ($failedVersions.Count) { $failedVersions -join ', ' } else { 'NONE' }))
    Add-ReportLine ('SUMMARY_SKIPPED_VERSIONS=' + $(if ($skippedVersions.Count) { $skippedVersions -join ', ' } else { 'NONE' }))
    Add-ReportLine ('RUN_DIRECTORY=' + $runRoot)
    Write-Host ('SUMMARY: total {0}, passed {1}, failed {2}, skipped {3}.' -f $counts.Total, $counts.Passed, $counts.Failed, $counts.Skipped)
    Write-Host ('Passed versions: {0}' -f $(if ($passedVersions.Count) { $passedVersions -join ', ' } else { 'none' }))
    Write-Host ('Failed versions: {0}' -f $(if ($failedVersions.Count) { $failedVersions -join ', ' } else { 'none' }))
    Write-Host ('Report: {0}' -f $reportPath)
    Write-Host ('Logs:   {0}' -f $runRoot)
    if ($counts.Failed -gt 0 -or $counts.Skipped -gt 0 -or $counts.Total -eq 0) {
        exit 1
    }
    exit 0
}
catch {
    try {
        Add-ReportLine ('FATAL_ERROR=' + $_.Exception.Message)
        Add-ReportLine ('RUN_DIRECTORY=' + $runRoot)
    }
    catch {
        Write-Error ('Could not write debugreport.txt: ' + $_.Exception.Message)
    }
    Write-Error $_.Exception.Message
    exit 1
}
