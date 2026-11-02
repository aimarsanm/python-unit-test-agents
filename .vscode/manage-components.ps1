param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('download', 'update')]
    [string]$Mode,
    [string]$WantsAgents = 'No',
    [string]$WantsSkills = 'No',
    [string]$WantsReadme = 'No'
)

$ErrorActionPreference = 'Stop'
$repositoryUrl = 'https://github.com/aimarsanm/python-unit-test-agents.git'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$inventoryPath = Join-Path $PSScriptRoot 'installed-components.json'

Push-Location $repositoryRoot
try {
    if ($Mode -eq 'download') {
        $downloads = @()
        if ($WantsAgents -eq 'Sí') {
            $downloads += [pscustomobject]@{ Source = '.github/agents'; Destination = '.github/agents' }
        }
        if ($WantsSkills -eq 'Sí') {
            $downloads += [pscustomobject]@{ Source = 'skills'; Destination = '.github/skills' }
        }
        if ($WantsReadme -eq 'Sí') {
            $downloads += [pscustomobject]@{ Source = 'README.md'; Destination = '.' }
        }
        if ($downloads.Count -eq 0) {
            Write-Host 'No has seleccionado nada para descargar.'
            exit 0
        }
    } else {
        if (-not (Test-Path -LiteralPath $inventoryPath)) {
            Write-Host 'No hay un inventario de componentes instalados.'
            exit 0
        }
        $downloads = @(Get-Content -LiteralPath $inventoryPath -Raw | ConvertFrom-Json)
    }

    git fetch $repositoryUrl main
    if ($LASTEXITCODE -ne 0) {
        throw 'No se pudieron consultar las versiones remotas.'
    }

    $updates = @()
    foreach ($item in $downloads) {
        $remoteVersion = (git rev-parse "FETCH_HEAD:$($item.Source)" | Out-String).Trim()
        if ($LASTEXITCODE -ne 0 -or -not $remoteVersion) {
            throw "No se pudo obtener la versión remota de $($item.Source)."
        }
        $installedVersionProperty = $item.PSObject.Properties['Version']
        $installedVersion = if ($installedVersionProperty) { $installedVersionProperty.Value } else { $null }
        if ($Mode -eq 'download' -or -not $installedVersion -or $installedVersion -ne $remoteVersion) {
            if ($Mode -eq 'update') {
                Write-Host "¡Hay cambios en: $($item.Source)!"
            }
            if ($installedVersionProperty) {
                $item.Version = $remoteVersion
            } else {
                $item | Add-Member -NotePropertyName Version -NotePropertyValue $remoteVersion
            }
            $updates += $item
        }
    }

    if ($Mode -eq 'update' -and $updates.Count -eq 0) {
        Write-Host 'No hay actualizaciones en tus componentes instalados. Todo está al día.'
        exit 0
    }
    if ($Mode -eq 'update') {
        $wantsUpdate = Read-Host '¿Deseas actualizar los componentes? (S/N)'
        if ($wantsUpdate -ne 'S' -and $wantsUpdate -ne 's') {
            Write-Host 'Actualización omitida por el usuario.'
            exit 0
        }
    }

    $temporaryDirectory = Join-Path ([System.IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())
    New-Item -ItemType Directory -Path $temporaryDirectory | Out-Null
    try {
        foreach ($item in $updates) {
            $archivePath = Join-Path $temporaryDirectory 'download.zip'
            git archive --format=zip --output=$archivePath FETCH_HEAD -- $item.Source
            if ($LASTEXITCODE -ne 0) {
                throw "No se pudo descargar $($item.Source)."
            }
            $expandedPath = Join-Path $temporaryDirectory 'expanded'
            Expand-Archive -LiteralPath $archivePath -DestinationPath $expandedPath -Force
            $sourcePath = Join-Path $expandedPath $item.Source
            if (-not (Test-Path -LiteralPath $sourcePath)) {
                throw "No se encontró la ruta: $($item.Source)"
            }
            if ($item.Destination -ne '.') {
                New-Item -ItemType Directory -Path $item.Destination -Force | Out-Null
            }
            if (Test-Path -LiteralPath $sourcePath -PathType Container) {
                Copy-Item -Path (Join-Path $sourcePath '*') -Destination $item.Destination -Recurse -Force
            } else {
                Copy-Item -LiteralPath $sourcePath -Destination $item.Destination -Force
            }
            Remove-Item -LiteralPath $expandedPath -Recurse -Force
            Remove-Item -LiteralPath $archivePath -Force
            Write-Host "Actualizado con éxito: $($item.Source)"
        }
    } finally {
        Remove-Item -LiteralPath $temporaryDirectory -Recurse -Force -ErrorAction SilentlyContinue
    }

    ConvertTo-Json -InputObject @($downloads) -Depth 10 | Set-Content -LiteralPath $inventoryPath
    if ($Mode -eq 'download') {
        Write-Host '¡Descarga completada y componentes guardados en el inventario!'
    }
} finally {
    Pop-Location
}
