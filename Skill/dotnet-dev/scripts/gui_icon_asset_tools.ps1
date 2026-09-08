#requires -Version 5.1

Add-Type -AssemblyName System.Drawing

function Ensure-DirectoryExists {
    param([string]$Path)

    if (-not [System.IO.Directory]::Exists($Path)) {
        [void][System.IO.Directory]::CreateDirectory($Path)
    }
}

function Get-IconPngBytes {
    param(
        [System.Drawing.Image]$SourceImage,
        [int]$Size
    )

    $bitmap = New-Object System.Drawing.Bitmap $Size, $Size, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $bitmap.SetResolution(96, 96)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)

    try {
        $graphics.Clear([System.Drawing.Color]::Transparent)
        $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
        $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality

        $scale = [Math]::Min($Size / [double]$SourceImage.Width, $Size / [double]$SourceImage.Height)
        $drawWidth = [Math]::Max(1, [int][Math]::Round($SourceImage.Width * $scale))
        $drawHeight = [Math]::Max(1, [int][Math]::Round($SourceImage.Height * $scale))
        $offsetX = [int][Math]::Floor(($Size - $drawWidth) / 2.0)
        $offsetY = [int][Math]::Floor(($Size - $drawHeight) / 2.0)

        $graphics.DrawImage($SourceImage, $offsetX, $offsetY, $drawWidth, $drawHeight)

        $memoryStream = New-Object System.IO.MemoryStream
        try {
            $bitmap.Save($memoryStream, [System.Drawing.Imaging.ImageFormat]::Png)
            return $memoryStream.ToArray()
        }
        finally {
            $memoryStream.Dispose()
        }
    }
    finally {
        $graphics.Dispose()
        $bitmap.Dispose()
    }
}

function New-IcoBytesFromPng {
    param(
        [string]$SourcePngPath,
        [int[]]$Sizes = @(16, 20, 24, 32, 40, 48, 64, 128, 256)
    )

    if (-not [System.IO.File]::Exists($SourcePngPath)) {
        throw "未找到 PNG 图标源文件：$SourcePngPath"
    }

    $pngBytes = [System.IO.File]::ReadAllBytes($SourcePngPath)
    $pngStream = New-Object System.IO.MemoryStream (, $pngBytes)

    try {
        $image = [System.Drawing.Image]::FromStream($pngStream, $true, $true)
        try {
            $resolvedSizes = @(
                $Sizes |
                Where-Object { $_ -gt 0 -and $_ -le 256 } |
                Sort-Object -Unique
            )

            if ($resolvedSizes.Count -eq 0) {
                throw 'ICO 至少需要一个合法尺寸。'
            }

            $entries = New-Object System.Collections.Generic.List[object]
            foreach ($size in $resolvedSizes) {
                $entryPngBytes = Get-IconPngBytes -SourceImage $image -Size $size
                $entries.Add([pscustomobject]@{
                        Size  = $size
                        Bytes = $entryPngBytes
                    }) | Out-Null
            }

            $outputStream = New-Object System.IO.MemoryStream
            $writer = New-Object System.IO.BinaryWriter($outputStream)

            try {
                $writer.Write([UInt16]0)
                $writer.Write([UInt16]1)
                $writer.Write([UInt16]$entries.Count)

                $offset = 6 + ($entries.Count * 16)
                foreach ($entry in $entries) {
                    $iconSize = [int]$entry.Size
                    $entryBytes = [byte[]]$entry.Bytes
                    $sizeByte = if ($iconSize -ge 256) { [byte]0 } else { [byte]$iconSize }

                    $writer.Write($sizeByte)
                    $writer.Write($sizeByte)
                    $writer.Write([byte]0)
                    $writer.Write([byte]0)
                    $writer.Write([UInt16]1)
                    $writer.Write([UInt16]32)
                    $writer.Write([UInt32]$entryBytes.Length)
                    $writer.Write([UInt32]$offset)

                    $offset += $entryBytes.Length
                }

                foreach ($entry in $entries) {
                    $writer.Write([byte[]]$entry.Bytes)
                }

                $writer.Flush()
                return $outputStream.ToArray()
            }
            finally {
                $writer.Dispose()
                $outputStream.Dispose()
            }
        }
        finally {
            $image.Dispose()
        }
    }
    finally {
        $pngStream.Dispose()
    }
}

function Get-DefaultGuiIconSourcePath {
    param([string]$SkillRoot)

    $assetRoot = Join-Path $SkillRoot 'assets\gui-exe-default-icon'
    $candidates = @(
        (Join-Path $assetRoot 'app-icon-source.png'),
        (Join-Path $assetRoot 'app.ico')
    )

    foreach ($candidate in $candidates) {
        if ([System.IO.File]::Exists($candidate)) {
            return $candidate
        }
    }

    return $null
}

function Install-GuiIconAssets {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourceIconPath,

        [Parameter(Mandatory = $true)]
        [string]$TargetDirectory
    )

    $resolvedSourcePath = [System.IO.Path]::GetFullPath($SourceIconPath)
    if (-not [System.IO.File]::Exists($resolvedSourcePath)) {
        throw "未找到图标源文件：$resolvedSourcePath"
    }

    Ensure-DirectoryExists -Path $TargetDirectory

    $extension = [System.IO.Path]::GetExtension($resolvedSourcePath).ToLowerInvariant()
    $targetIcoPath = Join-Path $TargetDirectory 'app.ico'

    switch ($extension) {
        '.png' {
            $targetSourcePath = Join-Path $TargetDirectory 'app-icon-source.png'
            [System.IO.File]::Copy($resolvedSourcePath, $targetSourcePath, $true)

            $icoBytes = New-IcoBytesFromPng -SourcePngPath $resolvedSourcePath
            [System.IO.File]::WriteAllBytes($targetIcoPath, $icoBytes)
        }
        '.ico' {
            $targetSourcePath = Join-Path $TargetDirectory 'app-icon-source.ico'
            [System.IO.File]::Copy($resolvedSourcePath, $targetSourcePath, $true)
            [System.IO.File]::Copy($resolvedSourcePath, $targetIcoPath, $true)
        }
        default {
            throw "暂不支持的图标格式：$extension。当前只支持 .png 或 .ico。"
        }
    }

    return [pscustomobject]@{
        SourcePath = $resolvedSourcePath
        IcoPath    = $targetIcoPath
    }
}

<#
meta_key: f22f9791-9e5efef0-9c48a6a9-c718c874-49b9722d-48707329-61c80339
source_map: 7d0ccaef-9b90660b-c0902f7c-fce9777d-9889660b-c19b2f60-ca2c8f97-1e69a60a-ffa02f63-ebe9436d-5dea436f-9b904300-c1802e54-f8e5537f-9b824209-e08f2d7b-d5ea4258-958b6008-e9a42553-f1eb6c6e-9ba1680b-c6b72e52-e8e9774d-98b04508-e7882c7c-f8e44d45-99b06a09-efa1296f-ffe96556-99b64409-fcba2c6b-f2e8764f-9b9e670c-fd8d227f-d8e94246-9b8c6d0b-c1ac2c7d-d0e46b63-99b47000-c1802c67-ecea5c56-98bc4c0b-c2912d7a-e4e47552-9aa57c09-ce992f51-f6e47e4c-99b77108-e7882c72-fee94246-9e8c48
#>
