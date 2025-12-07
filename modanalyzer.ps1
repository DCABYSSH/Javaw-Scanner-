Clear-Host
Write-Host "▄████▄  ██▓   ▓█████ ▄▄▄       ██▀███    ██████  ██████" -ForegroundColor Cyan
Write-Host "▒██▀ ▀█ ▓██▒  ▓█   ▀▒████▄    ▓██ ▒ ██▒  ▒██    ▒ ▒██    ▒" -ForegroundColor Cyan
Write-Host "▒▓█    ▄ ▒██░  ▒███ ▒██  ▀█▄  ▓██ ░▄█ ▒  ░ ▓██▄   ░ ▓██▄  " -ForegroundColor Cyan
Write-Host "▒▓▓▄ ▄██▒▒██░  ▒▓█  ▄░██▄▄▄▄██ ▒██▀▀█▄     ▒  ██▒  ▒  ██▒" -ForegroundColor Cyan
Write-Host "▒ ▓███▀ ░░██████▒░▒████▒▓█   ▓██▒░██▓ ▒██▒  ▒██████▒▒▒██████▒▒" -ForegroundColor Cyan
Write-Host "░ ░▒ ▒  ░░ ▒░▓  ░░░ ▒░ ░▒▒   ▓▒█░░ ▒▓ ░▒▓░  ▒ ▒▓▒ ▒ ░▒ ▒▓▒ ▒ ░" -ForegroundColor Cyan
Write-Host "░  ▒  ░  ░ ▒  ░ ░ ░  ░ ▒   ▒▒ ░  ░▒ ░ ▒░  ░ ░▒  ░ ░░ ░▒  ░ ░" -ForegroundColor Cyan
Write-Host "░       ░  ░ ░      ░   ░   ▒    ░░   ░   ░  ░  ░  ░  ░  " -ForegroundColor Cyan
Write-Host "░ ░         ░  ░  ░   ░     ░   ░    ░            ░        " -ForegroundColor Cyan
Write-Host "Made by " -ForegroundColor DarkGray -NoNewline
Write-Host "DCABYSSH_"
Write-Host

Write-Host "Enter path to the mods folder: " -NoNewline
Write-Host "(press Enter to use default)" -ForegroundColor DarkGray
$mods = Read-Host "PATH"
Write-Host

if (-not $mods) {
    $mods = "$env:USERPROFILE\AppData\Roaming\.minecraft\mods"
	Write-Host "Continuing with " -NoNewline
	Write-Host $mods -ForegroundColor White
	Write-Host
}

if (-not (Test-Path $mods -PathType Container)) {
    Write-Host "Invalid Path!" -ForegroundColor Red
    exit 1
}

# -------------------------------
# Utility functions
# -------------------------------

function Get-SHA1 {
    param (
        [string]$filePath
    )
    return (Get-FileHash -Path $filePath -Algorithm SHA1).Hash
}

function Get-ZoneIdentifier {
    param (
        [string]$filePath
    )
	$ads = Get-Content -Raw -Stream Zone.Identifier $filePath -ErrorAction SilentlyContinue
	if ($ads -match "HostUrl=(.+)") {
		return $matches[1]
	}
	
	return $null
}

function Fetch-Modrinth {
    param (
        [string]$hash
    )
    try {
        $response = Invoke-RestMethod -Uri "https://api.modrinth.com/v2/version-file/$hash" -Method Get -UseBasicParsing -ErrorAction Stop
		if ($response.project_id) {
            $projectResponse = "https://api.modrinth.com/v2/project/$($response.project_id)"
            $projectData = Invoke-RestMethod -Uri $projectResponse -Method Get -UseBasicParsing -ErrorAction Stop
            return @{ Name = $projectData.title; Slug = $projectData.slug }
        }
    } catch {}
	
    return @{ Name = ""; Slug = "" }
}

function Fetch-Megabase {
    param (
        [string]$hash
    )
    try {
        $response = Invoke-RestMethod -Uri "https://megabase.vercel.app/api/query?hash=$hash" -Method Get -UseBasicParsing -ErrorAction Stop
		if (-not $response.error) {
			return $response.data
		}
    } catch {}
	
    return $null
}

# -------------------------------
# Cheat string detector
# -------------------------------

$cheatStrings = @(
	"AimAssist",
	"AnchorTweaks",
	"AutoAnchor",
	"AutoCrystal",
	"AutoAnchor",
	"AutoDoubleHand",
	"AutoHitCrystal",
	"AutoPot",
	"AutoTotem",
	"AutoArmor",
	"InventoryTotem",
	"Hitboxes",
	"JumpReset",
	"LegitTotem",
	"PingSpoof",
	"SelfDestruct",
	"ShieldBreaker",
	"TriggerBot",
	"Velocity",
	"AxeSpam",
	"WebMacro",
	"SelfDestruct",
	"FastPlace"
)

function Check-Strings {
	param (
        [string]$filePath
    )
	
	$stringsFound = [System.Collections.Generic.HashSet[string]]::new()
	
	$fileContent = Get-Content -Raw $filePath -Encoding UTF8
	
	foreach ($string in $cheatStrings) {
		if ($fileContent -match [regex]::Escape($string)) {
			$stringsFound.Add($string) | Out-Null
		}
	}
	
	return $stringsFound
}

# -------------------------------
# Mod scanning
# -------------------------------

$verifiedMods = @()
$unknownMods = @()
$cheatMods = @()

$jarFiles = Get-ChildItem -Path $mods -Filter *.jar

$spinner = @("|", "/", "-", "\")
$totalMods = $jarFiles.Count
$counter = 0

foreach ($file in $jarFiles) {
	$counter++
	$spin = $spinner[$counter % $spinner.Length]
	Write-Host "`r[$spin] Scanning mods: $counter / $totalMods" -ForegroundColor Yellow -NoNewline
	
	$hash = Get-SHA1 -filePath $file.FullName
	
    $modDataModrinth = Fetch-Modrinth -hash $hash
    if ($modDataModrinth.Slug) {
		$verifiedMods += [PSCustomObject]@{ ModName = $modDataModrinth.Name; FileName = $file.Name }
		continue
    }
	
	$modDataMegabase = Fetch-Megabase -hash $hash
	if ($modDataMegabase.name) {
		$verifiedMods += [PSCustomObject]@{ ModName = $modDataMegabase.Name; FileName = $file.Name }
		continue
	}
	
	$zoneId = Get-ZoneIdentifier $file.FullName
	$unknownMods += [PSCustomObject]@{ FileName = $file.Name; FilePath = $file.FullName; ZoneId = $zoneId }
}

# -------------------------------
# Scan unknown mods for cheats
# -------------------------------

if ($unknownMods.Count -gt 0) {
	$tempDir = Join-Path $env:TEMP "habibimodanalyzer"
	
	$counter = 0
	
	try {
		Write-Host "`r$(' ' * 80)`r" -NoNewline
		
		if (Test-Path $tempDir) {
			Remove-Item -Recurse -Force $tempDir -ErrorAction SilentlyContinue
		}
		
		New-Item -ItemType Directory -Path $tempDir | Out-Null
		Add-Type -AssemblyName System.IO.Compression.FileSystem
	
		$modsToRemove = @()
		
		foreach ($mod in $unknownMods) {
			$counter++
			$spin = $spinner[$counter % $spinner.Length]
			Write-Host "`r[$spin] Scanning unknown mods for cheat strings ($counter / $($unknownMods.Count))..." -ForegroundColor Yellow -NoNewline
			
			$modStrings = Check-Strings $mod.FilePath
			if ($modStrings.Count -gt 0) {
				$modsToRemove += $mod.FileName
				$cheatMods += [PSCustomObject]@{ FileName = $mod.FileName; StringsFound = $modStrings }
				continue
			}
			
			$fileNameWithoutExt = [System.IO.Path]::GetFileNameWithoutExtension($mod.FileName)
			$extractPath = Join-Path $tempDir $fileNameWithoutExt
			
			if (-not (Test-Path $extractPath)) {
				New-Item -ItemType Directory -Path $extractPath | Out-Null
				try {
					[System.IO.Compression.ZipFile]::ExtractToDirectory($mod.FilePath, $extractPath)
				} catch {
					Remove-Item -Recurse -Force $extractPath -ErrorAction SilentlyContinue
					continue
				}
			}
			
			$depJarsPath = Join-Path $extractPath "META-INF/jars"
			if (-not (Test-Path $depJarsPath)) {
				continue
			}
			
			$depJars = Get-ChildItem -Path $depJarsPath -Filter "*.jar" -ErrorAction SilentlyContinue
			foreach ($jar in $depJars) {
				$depStrings = Check-Strings $jar.FullName
				if ($depStrings.Count -gt 0) {
					$modsToRemove += $mod.FileName
					$cheatMods += [PSCustomObject]@{ FileName = $mod.FileName; DepFileName = $jar.Name; StringsFound = $depStrings }
					break
				}
			}
		}
		
		$unknownMods = $unknownMods | Where-Object { $_.FileName -notin $modsToRemove }

	} catch {
		Write-Host "`nError occured while scanning jar files! $($_.Exception.Message)" -ForegroundColor Red
	} finally {
		Remove-Item -Recurse -Force $tempDir -ErrorAction SilentlyContinue
	}
}

Write-Host "`r$(' ' * 80)`r" -NoNewline

# -------------------------------
# Final output
# -------------------------------

if ($verifiedMods.Count -gt 0) {
	Write-Host "{ Verified Mods }" -ForegroundColor DarkCyan
	foreach ($mod in $verifiedMods) {
		Write-Host ("> {0, -30}" -f $mod.ModName) -ForegroundColor Green -NoNewline
		Write-Host "$($mod.FileName)" -ForegroundColor Gray
	}
	Write-Host
}

if ($unknownMods.Count -gt 0) {
	Write-Host "{ Unknown Mods }" -ForegroundColor DarkCyan
	foreach ($mod in $unknownMods) {
		if ($mod.ZoneId) {
			Write-Host ("> {0, -30}" -f $mod.FileName) -ForegroundColor DarkYellow -NoNewline
			Write-Host "$($mod.ZoneId)" -ForegroundColor DarkGray
			continue
		}
		Write-Host "> $($mod.FileName)" -ForegroundColor DarkYellow
	}
	Write-Host
}

if ($cheatMods.Count -gt 0) {
    Write-Host "{ Cheat Mods }" -ForegroundColor DarkCyan
	foreach ($mod in $cheatMods) {
		Write-Host "> $($mod.FileName)" -ForegroundColor Red -NoNewline
		if ($mod.DepFileName) {
			Write-Host " ->" -ForegroundColor Gray -NoNewline
			Write-Host " $($mod.DepFileName)" -ForegroundColor Red -NoNewline
		}
		Write-Host " [$($mod.StringsFound -join ', ')]" -ForegroundColor DarkMagenta
	}
	Write-Host
}
