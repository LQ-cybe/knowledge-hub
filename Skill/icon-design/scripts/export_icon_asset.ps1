<#
.SYNOPSIS
导出图标成品图，支持 svg、png、ico。

.DESCRIPTION
按 uniqueKey 定位图标后导出目标文件。导出 PNG 或 ICO 时，默认使用本机可调用的 Microsoft Edge 无头截图。

.PARAMETER Key
要导出的图标 uniqueKey。也可不传，改为在 -StylePreset JSON 中提供 uniqueKey / imageName / key。

.PARAMETER Format
输出格式，支持 svg、png、ico，可传单个值或逗号分隔值。

.PARAMETER Size
输出尺寸列表。导出 ico 时建议传 16,32,48,64,128,256。

.PARAMETER Color
替换图标主色，使用 HEX 颜色值。

.PARAMETER Background
输出背景色，默认 transparent。

.PARAMETER OutputPath
输出路径，必须是 skill 外部的绝对路径。

.PARAMETER CatalogDirectory
图标 Catalog 目录，默认自动定位。

.PARAMETER EdgePath
可选。显式指定 msedge.exe 路径，适用于企业环境或非默认安装位置。

.PARAMETER StylePreset
可选。支持直接传入搜索结果页复制出的完整参数 JSON，其中可包含 uniqueKey / imageName / key 以及样式参数。

.EXAMPLE
./export_icon_asset.ps1 -Key heroicons:20:solid:magnifying-glass -Format png -Size 128 -OutputPath D:\MyProject\assets\search-blue.png

.EXAMPLE
./export_icon_asset.ps1 -Key heroicons:20:solid:magnifying-glass -Format ico -Size 16,32,48,64,128,256 -OutputPath D:\MyProject\assets\app-icon.ico -EdgePath "C:\Program Files\Microsoft\Edge\Application\msedge.exe"

.EXAMPLE
./export_icon_asset.ps1 -StylePreset '{"imageName":"heroicons:20:solid:magnifying-glass","theme":"outline","size":48,"color":"#2563EB"}' -Format png -OutputPath D:\MyProject\assets\search-blue.png
#>
param(
    [string]$Key = "",

    [string[]]$Format = @("png"),

    [string[]]$Size = @(),

    [string]$Color = "",

    [string]$SecondaryColor = "",

    [string]$TertiaryColor = "",

    [string]$QuaternaryColor = "",

    [string]$Background = "transparent",

    [string]$Theme = "original",

    [double]$StrokeWidth = 0,

    [string]$StrokeLinecap = "",

    [string]$StrokeLinejoin = "",

    [int]$Weight = 400,

    [int]$Grade = 0,

    [int]$OpticalSize = 24,

    [Parameter(Mandatory = $true)]
    [string]$OutputPath,

    [string]$CatalogDirectory = "",

    [string]$EdgePath = "",

    [string]$StylePreset = ""
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot "icon_common.ps1")

function Get-FormatList {
    param(
        [string[]]$InputFormat
    )

    $allowedFormats = @{
        "svg" = $true
        "png" = $true
        "ico" = $true
    }
    $formatList = New-Object System.Collections.Generic.List[string]
    foreach ($item in @($InputFormat)) {
        foreach ($token in @(([string]$item) -split "[,\s]+")) {
            if ([string]::IsNullOrWhiteSpace($token)) {
                continue
            }

            $value = $token.Trim().ToLowerInvariant()
            if (-not $allowedFormats.ContainsKey($value)) {
                throw "不支持的输出格式: $value。当前仅支持 svg、png、ico。"
            }

            if (-not $formatList.Contains($value)) {
                $formatList.Add($value)
            }
        }
    }

    if ($formatList.Count -eq 0) {
        $formatList.Add("png")
    }

    return @($formatList.ToArray())
}

function Get-ResolvedSizeList {
    param(
        [string[]]$InputSize,
        [string[]]$FormatList
    )

    $sizeList = New-Object System.Collections.Generic.List[int]
    foreach ($item in @($InputSize)) {
        foreach ($token in @(([string]$item) -split "[,\s]+")) {
            if ([string]::IsNullOrWhiteSpace($token)) {
                continue
            }

            $parsedSize = 0
            if (-not [int]::TryParse($token, [ref]$parsedSize)) {
                throw "尺寸参数无效: $token"
            }

            if ($parsedSize -le 0) {
                throw "尺寸必须大于 0。"
            }

            if ($parsedSize -gt 1024) {
                throw "尺寸过大，当前仅支持不超过 1024 像素。"
            }

            if (-not $sizeList.Contains([int]$parsedSize)) {
                $sizeList.Add([int]$parsedSize)
            }
        }
    }

    if ($sizeList.Count -eq 0) {
        if ($FormatList -contains "ico") {
            foreach ($item in @(16, 24, 32, 48, 64, 128, 256)) {
                $sizeList.Add($item)
            }
        }
        elseif ($FormatList -contains "png") {
            $sizeList.Add(256)
        }
    }

    $oversizedIcoFrames = @(@($sizeList.ToArray()) | Where-Object { $_ -gt 256 })
    if (($FormatList -contains "ico") -and $oversizedIcoFrames.Count -gt 0) {
        throw "ICO 尺寸不能大于 256。若需要更大 PNG，请单独导出 PNG。"
    }

    return @($sizeList.ToArray() | Sort-Object)
}

function Get-ObjectPropertyValue {
    param(
        [AllowNull()]
        [object]$Object,

        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    if ($null -eq $Object) {
        return $null
    }

    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) {
        return $null
    }

    return $property.Value
}

function Get-StringValueOrDefault {
    param(
        [AllowNull()]
        [object]$Value,

        [string]$DefaultValue = ""
    )

    if ($null -eq $Value) {
        return $DefaultValue
    }

    $text = [string]$Value
    if ([string]::IsNullOrWhiteSpace($text)) {
        return $DefaultValue
    }

    return $text.Trim()
}

function Get-IntValueOrDefault {
    param(
        [AllowNull()]
        [object]$Value,

        [int]$DefaultValue
    )

    if ($null -eq $Value) {
        return $DefaultValue
    }

    $parsedValue = 0
    if ([int]::TryParse(([string]$Value), [ref]$parsedValue)) {
        return $parsedValue
    }

    return $DefaultValue
}

function Get-DoubleValueOrDefault {
    param(
        [AllowNull()]
        [object]$Value,

        [double]$DefaultValue
    )

    if ($null -eq $Value) {
        return $DefaultValue
    }

    $parsedValue = 0.0
    if ([double]::TryParse(([string]$Value), [System.Globalization.NumberStyles]::Float, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$parsedValue)) {
        return [double]$parsedValue
    }

    if ([double]::TryParse(([string]$Value), [ref]$parsedValue)) {
        return [double]$parsedValue
    }

    return $DefaultValue
}

function Get-SafeFileName {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Text
    )

    $value = $Text
    foreach ($invalidChar in [System.IO.Path]::GetInvalidFileNameChars()) {
        $value = $value.Replace([string]$invalidChar, "-")
    }

    $value = $value -replace "[:\\/]", "-"
    $value = $value -replace "\s+", "-"
    $value = $value -replace "-{2,}", "-"
    return $value.Trim("-")
}

function Get-ExpectedSingleOutputExtension {
    param(
        [string[]]$FormatList,
        [int[]]$ResolvedSizes
    )

    if ($FormatList.Count -eq 1 -and $FormatList[0] -eq "svg") {
        return ".svg"
    }

    if ($FormatList.Count -eq 1 -and $FormatList[0] -eq "ico") {
        return ".ico"
    }

    if ($FormatList.Count -eq 1 -and $FormatList[0] -eq "png" -and $ResolvedSizes.Count -eq 1) {
        return ".png"
    }

    return ""
}

function Get-OutputFileCount {
    param(
        [string[]]$FormatList,
        [int[]]$ResolvedSizes
    )

    $count = 0
    if ($FormatList -contains "svg") {
        $count += 1
    }

    if ($FormatList -contains "png") {
        $count += $ResolvedSizes.Count
    }

    if ($FormatList -contains "ico") {
        $count += 1
    }

    return $count
}

function Resolve-ExportOutputPlan {
    param(
        [Parameter(Mandatory = $true)]
        [string]$OutputPath,

        [Parameter(Mandatory = $true)]
        [string[]]$FormatList,

        [int[]]$ResolvedSizes = @(),

        [Parameter(Mandatory = $true)]
        [string]$SkillRoot
    )

    $resolvedPath = Assert-ExternalOutputPath -Path $OutputPath -ParameterName "OutputPath" -SkillRoot $SkillRoot
    if ((Test-Path -LiteralPath $resolvedPath) -and (Test-Path -LiteralPath $resolvedPath -PathType Container)) {
        throw "参数 -OutputPath 必须是文件路径，不能是目录: $resolvedPath"
    }

    $leafName = Split-Path -Leaf $resolvedPath
    if ([string]::IsNullOrWhiteSpace($leafName)) {
        throw "参数 -OutputPath 必须包含文件名，不能只传目录。"
    }

    $outputCount = Get-OutputFileCount -FormatList $FormatList -ResolvedSizes $ResolvedSizes
    $expectedSingleExtension = Get-ExpectedSingleOutputExtension -FormatList $FormatList -ResolvedSizes $ResolvedSizes
    $inputExtension = [System.IO.Path]::GetExtension($resolvedPath)
    $basePath = $resolvedPath

    if ($outputCount -gt 1) {
        if (-not [string]::IsNullOrWhiteSpace($inputExtension)) {
            throw "多文件输出时，-OutputPath 不能带扩展名，请传外部绝对文件基路径，例如 D:\Project\assets\search-icon"
        }
    }
    elseif (-not [string]::IsNullOrWhiteSpace($inputExtension)) {
        if ($inputExtension.ToLowerInvariant() -ne $expectedSingleExtension) {
            throw "当前输出只接受 $expectedSingleExtension 文件路径，请修正 -OutputPath: $resolvedPath"
        }

        $basePath = Join-Path (Split-Path -Parent $resolvedPath) ([System.IO.Path]::GetFileNameWithoutExtension($resolvedPath))
    }

    return [pscustomobject]@{
        InputPath                = $resolvedPath
        BasePath                 = $basePath
        OutputCount              = $outputCount
        ExpectedSingleExtension  = $expectedSingleExtension
    }
}

function Get-SvgOutputPath {
    param(
        [Parameter(Mandatory = $true)]
        [object]$OutputPlan
    )

    if ($OutputPlan.OutputCount -eq 1 -and $OutputPlan.ExpectedSingleExtension -eq ".svg") {
        return $OutputPlan.InputPath
    }

    return ($OutputPlan.BasePath + ".svg")
}

function Get-PngOutputPath {
    param(
        [Parameter(Mandatory = $true)]
        [object]$OutputPlan,

        [Parameter(Mandatory = $true)]
        [int]$CanvasSize
    )

    if ($OutputPlan.OutputCount -eq 1 -and $OutputPlan.ExpectedSingleExtension -eq ".png") {
        return $OutputPlan.InputPath
    }

    if ($OutputPlan.OutputCount -eq 1) {
        return ($OutputPlan.BasePath + ".png")
    }

    return ("{0}-{1}.png" -f $OutputPlan.BasePath, $CanvasSize)
}

function Get-IcoOutputPath {
    param(
        [Parameter(Mandatory = $true)]
        [object]$OutputPlan
    )

    if ($OutputPlan.OutputCount -eq 1 -and $OutputPlan.ExpectedSingleExtension -eq ".ico") {
        return $OutputPlan.InputPath
    }

    return ($OutputPlan.BasePath + ".ico")
}

function Test-ShouldReplacePaintValue {
    param(
        [string]$Value
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $false
    }

    $normalized = $Value.Trim().ToLowerInvariant()
    if ($normalized -in @("none", "transparent", "inherit", "initial", "unset", "context-fill", "context-stroke")) {
        return $false
    }

    if ($normalized.StartsWith("url(")) {
        return $false
    }

    return $true
}

function Get-NormalizedThemeName {
    param(
        [string]$ThemeName
    )

    $value = Get-StringValueOrDefault -Value $ThemeName -DefaultValue "original"
    switch ($value.ToLowerInvariant()) {
        "original" { return "original" }
        "outline" { return "outline" }
        "filled" { return "filled" }
        "two-tone" { return "two-tone" }
        "multi-color" { return "multi-color" }
        default { throw "不支持的主题模式: $ThemeName。当前仅支持 original、outline、filled、two-tone、multi-color。" }
    }
}

function Get-NormalizedStrokeLinecap {
    param(
        [string]$Value,
        [string]$ThemeName
    )

    $text = Get-StringValueOrDefault -Value $Value
    if ([string]::IsNullOrWhiteSpace($text)) {
        if ($ThemeName -eq "original") {
            return ""
        }

        return "round"
    }

    switch ($text.ToLowerInvariant()) {
        "butt" { return "butt" }
        "round" { return "round" }
        "square" { return "square" }
        default { throw "不支持的端点类型: $Value。当前仅支持 butt、round、square。" }
    }
}

function Get-NormalizedStrokeLinejoin {
    param(
        [string]$Value,
        [string]$ThemeName
    )

    $text = Get-StringValueOrDefault -Value $Value
    if ([string]::IsNullOrWhiteSpace($text)) {
        if ($ThemeName -eq "original") {
            return ""
        }

        return "round"
    }

    switch ($text.ToLowerInvariant()) {
        "miter" { return "miter" }
        "round" { return "round" }
        "bevel" { return "bevel" }
        default { throw "不支持的拐角类型: $Value。当前仅支持 miter、round、bevel。" }
    }
}

function Get-NormalizedColorValue {
    param(
        [string]$Value,
        [string]$Fallback = ""
    )

    $text = Get-StringValueOrDefault -Value $Value -DefaultValue $Fallback
    if ([string]::IsNullOrWhiteSpace($text)) {
        return ""
    }

    if ($text -match "^[0-9a-fA-F]{3}([0-9a-fA-F]{3})?([0-9a-fA-F]{2})?$") {
        return ("#{0}" -f $text.ToUpperInvariant())
    }

    return $text
}

function Format-InvariantNumber {
    param(
        [double]$Value
    )

    return $Value.ToString("0.##", [System.Globalization.CultureInfo]::InvariantCulture)
}

function Get-EffectiveStrokeWidth {
    param(
        [double]$BaseStrokeWidth,
        [int]$WeightValue,
        [int]$GradeValue,
        [int]$OpticalSizeValue,
        [string]$ThemeName
    )

    $baseValue = if ($BaseStrokeWidth -gt 0) { $BaseStrokeWidth } else { if ($ThemeName -eq "filled") { 1.5 } else { 4.0 } }
    $computed = [double]$baseValue
    $computed += (($WeightValue - 400) / 300.0) * 1.6
    $computed += ($GradeValue / 200.0) * 0.8
    $computed += (($OpticalSizeValue - 24) / 24.0) * 0.6
    $computed = [Math]::Max(0.5, [Math]::Min(8.0, $computed))
    return [Math]::Round($computed, 2)
}

function Resolve-StyleOptions {
    param(
        [string]$ThemeName,
        [string]$PrimaryColor,
        [string]$SecondaryColorValue,
        [string]$TertiaryColorValue,
        [string]$QuaternaryColorValue,
        [double]$StrokeWidthValue,
        [string]$LinecapValue,
        [string]$LinejoinValue,
        [int]$WeightValue,
        [int]$GradeValue,
        [int]$OpticalSizeValue
    )

    $theme = Get-NormalizedThemeName -ThemeName $ThemeName
    $primary = Get-NormalizedColorValue -Value $PrimaryColor
    if ([string]::IsNullOrWhiteSpace($primary) -and $theme -ne "original") {
        $primary = "#333333"
    }

    $secondary = Get-NormalizedColorValue -Value $SecondaryColorValue -Fallback "#2F88FF"
    $tertiary = Get-NormalizedColorValue -Value $TertiaryColorValue -Fallback "#FFFFFF"
    $quaternary = Get-NormalizedColorValue -Value $QuaternaryColorValue -Fallback "#43CCF8"
    $hasStrokeTuning = ($theme -ne "original") -or ($StrokeWidthValue -gt 0) -or ($WeightValue -ne 400) -or ($GradeValue -ne 0) -or ($OpticalSizeValue -ne 24) -or (-not [string]::IsNullOrWhiteSpace($LinecapValue)) -or (-not [string]::IsNullOrWhiteSpace($LinejoinValue))
    $effectiveStrokeWidth = if ($hasStrokeTuning) {
        Get-EffectiveStrokeWidth -BaseStrokeWidth $StrokeWidthValue -WeightValue $WeightValue -GradeValue $GradeValue -OpticalSizeValue $OpticalSizeValue -ThemeName $theme
    }
    else {
        0.0
    }

    return [pscustomobject]@{
        Theme                = $theme
        PrimaryColor         = $primary
        SecondaryColor       = $secondary
        TertiaryColor        = $tertiary
        QuaternaryColor      = $quaternary
        Weight               = $WeightValue
        Grade                = $GradeValue
        OpticalSize          = $OpticalSizeValue
        StrokeWidth          = $effectiveStrokeWidth
        StrokeWidthText      = if ($effectiveStrokeWidth -gt 0) { Format-InvariantNumber -Value $effectiveStrokeWidth } else { "" }
        StrokeLinecap        = Get-NormalizedStrokeLinecap -Value $LinecapValue -ThemeName $theme
        StrokeLinejoin       = Get-NormalizedStrokeLinejoin -Value $LinejoinValue -ThemeName $theme
        ShouldTuneStroke     = $hasStrokeTuning
    }
}

function Set-StylePropertyValue {
    param(
        [string]$StyleText,
        [Parameter(Mandatory = $true)]
        [string]$Name,
        [AllowEmptyString()]
        [string]$Value
    )

    $segments = New-Object System.Collections.Generic.List[string]
    $targetName = $Name.Trim().ToLowerInvariant()
    $replaced = $false
    foreach ($segment in @(($StyleText -split ";"))) {
        $trimmed = $segment.Trim()
        if (-not $trimmed) {
            continue
        }

        $pair = $trimmed -split ":", 2
        if ($pair.Count -ne 2) {
            $segments.Add($trimmed)
            continue
        }

        $currentName = $pair[0].Trim()
        if ($currentName.ToLowerInvariant() -eq $targetName) {
            $replaced = $true
            if (-not [string]::IsNullOrWhiteSpace($Value)) {
                $segments.Add(("{0}: {1}" -f $Name, $Value))
            }
            continue
        }

        $segments.Add($trimmed)
    }

    if ((-not $replaced) -and (-not [string]::IsNullOrWhiteSpace($Value))) {
        $segments.Add(("{0}: {1}" -f $Name, $Value))
    }

    return ($segments -join "; ")
}

function Set-XmlAttributeValue {
    param(
        [Parameter(Mandatory = $true)]
        [System.Xml.XmlElement]$Element,
        [Parameter(Mandatory = $true)]
        [string]$Name,
        [AllowEmptyString()]
        [string]$Value
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        if ($Element.HasAttribute($Name)) {
            $Element.RemoveAttribute($Name)
        }
        return
    }

    $Element.SetAttribute($Name, $Value)
}

function Set-ElementStyleAndAttribute {
    param(
        [Parameter(Mandatory = $true)]
        [System.Xml.XmlElement]$Element,
        [Parameter(Mandatory = $true)]
        [string]$Name,
        [AllowEmptyString()]
        [string]$Value
    )

    Set-XmlAttributeValue -Element $Element -Name $Name -Value $Value
    $styleText = if ($Element.HasAttribute("style")) { $Element.GetAttribute("style") } else { "" }
    $updatedStyle = Set-StylePropertyValue -StyleText $styleText -Name $Name -Value $Value
    Set-XmlAttributeValue -Element $Element -Name "style" -Value $updatedStyle
}

function Get-StylePropertyMatchValue {
    param(
        [Parameter(Mandatory = $true)]
        [System.Xml.XmlElement]$Element,
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    if (-not $Element.HasAttribute("style")) {
        return ""
    }

    $styleText = $Element.GetAttribute("style")
    if ([string]::IsNullOrWhiteSpace($styleText)) {
        return ""
    }

    $pattern = "(?i)(^|;)\s*{0}\s*:\s*([^;]+)" -f [Regex]::Escape($Name)
    $match = [Regex]::Match($styleText, $pattern)
    if (-not $match.Success) {
        return ""
    }

    return $match.Groups[2].Value.Trim()
}

function Get-ElementPaintInfo {
    param(
        [Parameter(Mandatory = $true)]
        [System.Xml.XmlElement]$Element
    )

    $fillValue = if ($Element.HasAttribute("fill")) { $Element.GetAttribute("fill") } else { Get-StylePropertyMatchValue -Element $Element -Name "fill" }
    $strokeValue = if ($Element.HasAttribute("stroke")) { $Element.GetAttribute("stroke") } else { Get-StylePropertyMatchValue -Element $Element -Name "stroke" }
    return [pscustomobject]@{
        HasFillPaint   = Test-ShouldReplacePaintValue -Value $fillValue
        HasStrokePaint = Test-ShouldReplacePaintValue -Value $strokeValue
    }
}

function Test-IsGraphicSvgElement {
    param(
        [Parameter(Mandatory = $true)]
        [System.Xml.XmlElement]$Element
    )

    return ($Element.LocalName -in @("path", "circle", "ellipse", "rect", "line", "polyline", "polygon", "use"))
}

function Test-ElementCanUseFill {
    param(
        [Parameter(Mandatory = $true)]
        [System.Xml.XmlElement]$Element
    )

    return ($Element.LocalName -notin @("line", "polyline"))
}

function Set-GraphicStrokeStyle {
    param(
        [Parameter(Mandatory = $true)]
        [System.Xml.XmlElement]$Element,
        [Parameter(Mandatory = $true)]
        [object]$StyleOptions
    )

    if ($StyleOptions.StrokeWidth -gt 0) {
        Set-ElementStyleAndAttribute -Element $Element -Name "stroke-width" -Value $StyleOptions.StrokeWidthText
    }

    if (-not [string]::IsNullOrWhiteSpace($StyleOptions.StrokeLinecap)) {
        Set-ElementStyleAndAttribute -Element $Element -Name "stroke-linecap" -Value $StyleOptions.StrokeLinecap
    }

    if (-not [string]::IsNullOrWhiteSpace($StyleOptions.StrokeLinejoin)) {
        Set-ElementStyleAndAttribute -Element $Element -Name "stroke-linejoin" -Value $StyleOptions.StrokeLinejoin
    }
}

function Get-MultiColorFillValue {
    param(
        [Parameter(Mandatory = $true)]
        [object]$StyleOptions,
        [Parameter(Mandatory = $true)]
        [hashtable]$State
    )

    $palette = @(
        $StyleOptions.SecondaryColor,
        $StyleOptions.TertiaryColor,
        $StyleOptions.QuaternaryColor,
        $StyleOptions.PrimaryColor
    ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

    if ($palette.Count -eq 0) {
        return $StyleOptions.PrimaryColor
    }

    $value = $palette[$State.FillColorIndex % $palette.Count]
    $State.FillColorIndex += 1
    return $value
}

function Apply-SvgStyleRecursively {
    param(
        [Parameter(Mandatory = $true)]
        [System.Xml.XmlNode]$Node,
        [Parameter(Mandatory = $true)]
        [object]$StyleOptions,
        [Parameter(Mandatory = $true)]
        [hashtable]$State
    )

    if ($Node.NodeType -ne [System.Xml.XmlNodeType]::Element) {
        return
    }

    $element = [System.Xml.XmlElement]$Node
    if ($element.LocalName -eq "svg") {
        if (-not [string]::IsNullOrWhiteSpace($StyleOptions.PrimaryColor)) {
            Set-ElementStyleAndAttribute -Element $element -Name "color" -Value $StyleOptions.PrimaryColor
        }
    }
    elseif (Test-IsGraphicSvgElement -Element $element) {
        $paintInfo = Get-ElementPaintInfo -Element $element
        $canUseFill = Test-ElementCanUseFill -Element $element
        switch ($StyleOptions.Theme) {
            "original" {
                if (-not [string]::IsNullOrWhiteSpace($StyleOptions.PrimaryColor)) {
                    if ($paintInfo.HasFillPaint) {
                        Set-ElementStyleAndAttribute -Element $element -Name "fill" -Value $StyleOptions.PrimaryColor
                    }
                    if ($paintInfo.HasStrokePaint) {
                        Set-ElementStyleAndAttribute -Element $element -Name "stroke" -Value $StyleOptions.PrimaryColor
                    }
                }

                if ($StyleOptions.ShouldTuneStroke -and $paintInfo.HasStrokePaint) {
                    Set-GraphicStrokeStyle -Element $element -StyleOptions $StyleOptions
                }
            }
            "outline" {
                if ($canUseFill) {
                    Set-ElementStyleAndAttribute -Element $element -Name "fill" -Value "none"
                }
                Set-ElementStyleAndAttribute -Element $element -Name "stroke" -Value $StyleOptions.PrimaryColor
                Set-GraphicStrokeStyle -Element $element -StyleOptions $StyleOptions
            }
            "filled" {
                if ($canUseFill) {
                    Set-ElementStyleAndAttribute -Element $element -Name "fill" -Value $StyleOptions.PrimaryColor
                }
                if ($paintInfo.HasStrokePaint) {
                    Set-ElementStyleAndAttribute -Element $element -Name "stroke" -Value $StyleOptions.PrimaryColor
                    Set-GraphicStrokeStyle -Element $element -StyleOptions $StyleOptions
                }
            }
            "two-tone" {
                if ($canUseFill -and ($paintInfo.HasFillPaint -or -not $paintInfo.HasStrokePaint)) {
                    Set-ElementStyleAndAttribute -Element $element -Name "fill" -Value $StyleOptions.SecondaryColor
                }
                Set-ElementStyleAndAttribute -Element $element -Name "stroke" -Value $StyleOptions.PrimaryColor
                Set-GraphicStrokeStyle -Element $element -StyleOptions $StyleOptions
            }
            "multi-color" {
                if ($canUseFill -and ($paintInfo.HasFillPaint -or -not $paintInfo.HasStrokePaint)) {
                    Set-ElementStyleAndAttribute -Element $element -Name "fill" -Value (Get-MultiColorFillValue -StyleOptions $StyleOptions -State $State)
                }
                Set-ElementStyleAndAttribute -Element $element -Name "stroke" -Value $StyleOptions.PrimaryColor
                Set-GraphicStrokeStyle -Element $element -StyleOptions $StyleOptions
            }
        }
    }

    foreach ($child in @($Node.ChildNodes)) {
        Apply-SvgStyleRecursively -Node $child -StyleOptions $StyleOptions -State $State
    }
}

function Convert-SvgColor {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SvgMarkup,
        [Parameter(Mandatory = $true)]
        [object]$StyleOptions
    )

    $xmlDocument = New-Object System.Xml.XmlDocument
    $xmlDocument.PreserveWhitespace = $true
    $xmlDocument.LoadXml($SvgMarkup)
    $svgNode = $xmlDocument.DocumentElement
    if ($null -eq $svgNode -or $svgNode.LocalName -ne "svg") {
        return $SvgMarkup
    }

    Apply-SvgStyleRecursively -Node $svgNode -StyleOptions $StyleOptions -State @{ FillColorIndex = 0 }
    return $xmlDocument.OuterXml
}

function Get-BackgroundCssValue {
    param(
        [string]$BackgroundValue
    )

    if ([string]::IsNullOrWhiteSpace($BackgroundValue)) {
        return "transparent"
    }

    return $BackgroundValue.Trim()
}

function New-RenderHtml {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SvgMarkup,

        [Parameter(Mandatory = $true)]
        [int]$CanvasSize,

        [Parameter(Mandatory = $true)]
        [string]$BackgroundValue
    )

    $backgroundCss = Get-BackgroundCssValue -BackgroundValue $BackgroundValue
    return @"
<!doctype html>
<html lang="zh-CN">
<head>
  <meta charset="utf-8" />
  <style>
    html, body {
      margin: 0;
      width: ${CanvasSize}px;
      height: ${CanvasSize}px;
      overflow: hidden;
      background: ${backgroundCss};
    }
    body {
      display: flex;
      align-items: center;
      justify-content: center;
    }
    svg {
      width: ${CanvasSize}px;
      height: ${CanvasSize}px;
      display: block;
      overflow: visible;
    }
  </style>
</head>
<body>
$SvgMarkup
</body>
</html>
"@
}

function Get-EdgeExecutablePath {
    param(
        [string]$ExplicitEdgePath = ""
    )

    if (-not [string]::IsNullOrWhiteSpace($ExplicitEdgePath)) {
        $resolvedEdgePath = [System.IO.Path]::GetFullPath($ExplicitEdgePath)
        if (-not (Test-Path -LiteralPath $resolvedEdgePath -PathType Leaf)) {
            throw "指定的 EdgePath 无效，文件不存在: $resolvedEdgePath"
        }

        return $resolvedEdgePath
    }

    $command = Get-Command msedge.exe -ErrorAction SilentlyContinue
    if ($null -eq $command) {
        $command = Get-Command msedge -ErrorAction SilentlyContinue
    }

    if ($null -ne $command -and -not [string]::IsNullOrWhiteSpace($command.Source)) {
        return $command.Source
    }

    $candidatePaths = @(
        (Join-Path ${env:ProgramFiles(x86)} "Microsoft\Edge\Application\msedge.exe"),
        (Join-Path $env:ProgramFiles "Microsoft\Edge\Application\msedge.exe"),
        (Join-Path $env:LocalAppData "Microsoft\Edge\Application\msedge.exe")
    ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

    foreach ($path in $candidatePaths) {
        if (Test-Path -LiteralPath $path) {
            return $path
        }
    }

    $registryPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\msedge.exe",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\App Paths\msedge.exe",
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\msedge.exe"
    )

    foreach ($registryPath in $registryPaths) {
        try {
            $appPath = (Get-ItemProperty -LiteralPath $registryPath -ErrorAction Stop)."(default)"
            if (-not [string]::IsNullOrWhiteSpace($appPath) -and (Test-Path -LiteralPath $appPath)) {
                return $appPath
            }
        }
        catch {
        }
    }

    throw "未找到 Microsoft Edge，可执行文件 `msedge.exe` 不存在或无法从命令行定位。请先安装 Edge，或确认它位于 PATH、Program Files、LocalAppData，或已注册到 App Paths。暂时无法导出 PNG 或 ICO。"
}

function Convert-ToFileUrl {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    return ([System.Uri]::new($Path)).AbsoluteUri
}

function Invoke-EdgeScreenshot {
    param(
        [Parameter(Mandatory = $true)]
        [string]$HtmlPath,

        [Parameter(Mandatory = $true)]
        [string]$OutputPngPath,

        [Parameter(Mandatory = $true)]
        [int]$CanvasSize,

        [Parameter(Mandatory = $true)]
        [string]$BackgroundValue,

        [string]$EdgeExecutablePath = ""
    )

    $edgePath = Get-EdgeExecutablePath -ExplicitEdgePath $EdgeExecutablePath
    $fileUrl = Convert-ToFileUrl -Path $HtmlPath
    $temporaryPngPath = Join-Path ([System.IO.Path]::GetTempPath()) ("icon-shot-{0}.png" -f ([System.Guid]::NewGuid().ToString("N")))
    $temporaryErrorPath = Join-Path ([System.IO.Path]::GetTempPath()) ("icon-shot-{0}.stderr.log" -f ([System.Guid]::NewGuid().ToString("N")))
    $arguments = @(
        "--headless",
        "--disable-gpu",
        "--hide-scrollbars",
        "--allow-file-access-from-files",
        ("--window-size={0},{0}" -f $CanvasSize),
        ("--screenshot={0}" -f $temporaryPngPath)
    )

    if ((Get-BackgroundCssValue -BackgroundValue $BackgroundValue).ToLowerInvariant() -eq "transparent") {
        $arguments += "--default-background-color=00000000"
    }

    try {
        $null = & $edgePath @arguments $fileUrl 2> $temporaryErrorPath
        $exitCodeVariable = Get-Variable -Name LASTEXITCODE -Scope Global -ErrorAction SilentlyContinue
        $exitCode = if ($null -ne $exitCodeVariable) { [int]$exitCodeVariable.Value } else { 0 }
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        while ((-not (Test-Path -LiteralPath $temporaryPngPath)) -and $stopwatch.ElapsedMilliseconds -lt 15000) {
            Start-Sleep -Milliseconds 200
        }

        if (-not (Test-Path -LiteralPath $temporaryPngPath)) {
            $edgeError = ""
            if (Test-Path -LiteralPath $temporaryErrorPath) {
                try {
                    $edgeError = ([System.IO.File]::ReadAllText($temporaryErrorPath)).Trim()
                }
                catch {
                    $edgeError = ""
                }
            }

            $details = @(
                ("EdgePath={0}" -f $edgePath),
                ("ExitCode={0}" -f $exitCode),
                ("HtmlPath={0}" -f $HtmlPath),
                ("OutputPngPath={0}" -f $OutputPngPath)
            )
            if (-not [string]::IsNullOrWhiteSpace($edgeError)) {
                $details += ("EdgeError={0}" -f $edgeError)
            }

            throw ("PNG 导出失败。请确认本机 Microsoft Edge 支持无头截图，且当前用户对临时目录、源 HTML 和输出目录拥有读写权限。{0}" -f ($details -join "; "))
        }

        $directory = Split-Path -Parent $OutputPngPath
        if ($directory -and -not (Test-Path -LiteralPath $directory)) {
            [void][System.IO.Directory]::CreateDirectory($directory)
        }

        [System.IO.File]::Copy($temporaryPngPath, $OutputPngPath, $true)
    }
    finally {
        if (Test-Path -LiteralPath $temporaryPngPath) {
            [System.IO.File]::Delete($temporaryPngPath)
        }
        if (Test-Path -LiteralPath $temporaryErrorPath) {
            [System.IO.File]::Delete($temporaryErrorPath)
        }
    }
}

function Export-PngFrame {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SvgMarkup,

        [Parameter(Mandatory = $true)]
        [int]$CanvasSize,

        [Parameter(Mandatory = $true)]
        [string]$OutputPngPath,

        [Parameter(Mandatory = $true)]
        [string]$BackgroundValue,

        [string]$EdgeExecutablePath = ""
    )

    $temporaryHtmlPath = Join-Path ([System.IO.Path]::GetTempPath()) ("icon-render-{0}.html" -f ([System.Guid]::NewGuid().ToString("N")))
    try {
        $html = New-RenderHtml -SvgMarkup $SvgMarkup -CanvasSize $CanvasSize -BackgroundValue $BackgroundValue
        [System.IO.File]::WriteAllText($temporaryHtmlPath, $html, (Get-Utf8NoBomEncoding))
        Invoke-EdgeScreenshot -HtmlPath $temporaryHtmlPath -OutputPngPath $OutputPngPath -CanvasSize $CanvasSize -BackgroundValue $BackgroundValue -EdgeExecutablePath $EdgeExecutablePath
    }
    finally {
        if (Test-Path -LiteralPath $temporaryHtmlPath) {
            [System.IO.File]::Delete($temporaryHtmlPath)
        }
    }
}

function Write-IcoFile {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$FrameMap,

        [Parameter(Mandatory = $true)]
        [string]$OutputPath
    )

    $sizes = @($FrameMap.Keys | ForEach-Object { [int]$_ } | Sort-Object)
    if ($sizes.Count -eq 0) {
        throw "ICO 需要至少一个 PNG 帧。"
    }

    $directory = Split-Path -Parent $OutputPath
    if ($directory -and -not (Test-Path -LiteralPath $directory)) {
        [void][System.IO.Directory]::CreateDirectory($directory)
    }

    $fileStream = [System.IO.File]::Open($OutputPath, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write)
    try {
        $writer = New-Object System.IO.BinaryWriter($fileStream)
        try {
            $writer.Write([UInt16]0)
            $writer.Write([UInt16]1)
            $writer.Write([UInt16]$sizes.Count)

            $entryList = New-Object System.Collections.Generic.List[object]
            $offset = 6 + (16 * $sizes.Count)
            foreach ($size in $sizes) {
                $bytes = [byte[]]$FrameMap[[string]$size]
                if ($size -gt 256) {
                    throw "ICO 尺寸不能大于 256。"
                }

                $entryList.Add([pscustomobject]@{
                    Size   = $size
                    Bytes  = $bytes
                    Offset = $offset
                })
                $offset += $bytes.Length
            }

            foreach ($entry in $entryList) {
                $iconSize = [int]$entry.Size
                $dimensionByte = if ($iconSize -ge 256) { [byte]0 } else { [byte]$iconSize }
                $writer.Write($dimensionByte)
                $writer.Write($dimensionByte)
                $writer.Write([byte]0)
                $writer.Write([byte]0)
                $writer.Write([UInt16]1)
                $writer.Write([UInt16]32)
                $writer.Write([UInt32]$entry.Bytes.Length)
                $writer.Write([UInt32]$entry.Offset)
            }

            foreach ($entry in $entryList) {
                $writer.Write([byte[]]$entry.Bytes)
            }
        }
        finally {
            $writer.Dispose()
        }
    }
    finally {
        $fileStream.Dispose()
    }
}

function Resolve-IconCatalogItem {
    param(
        [Parameter(Mandatory = $true)]
        [string]$InputKey,

        [Parameter(Mandatory = $true)]
        [hashtable]$CatalogLookup
    )

    $trimmedKey = $InputKey.Trim()
    if ($CatalogLookup.ContainsKey($trimmedKey)) {
        return $CatalogLookup[$trimmedKey]
    }

    $normalizedInput = Normalize-IconText -Text ($trimmedKey -replace "\.svg$", "")
    return (
        $CatalogLookup.Values |
        Where-Object {
            $_.normalizedName -eq $normalizedInput -or
            $_.name -eq $trimmedKey -or
            $_.svgFileName -eq $trimmedKey
        } |
        Select-Object -First 1
    )
}

$stylePresetObject = $null
if (-not [string]::IsNullOrWhiteSpace($StylePreset)) {
    try {
        $stylePresetObject = $StylePreset | ConvertFrom-Json
    }
    catch {
        throw ("参数 -StylePreset 不是合法 JSON: {0}" -f $_.Exception.Message)
    }

    if (-not $PSBoundParameters.ContainsKey("Key")) {
        foreach ($propertyName in @("uniqueKey", "imageName", "key")) {
            $resolvedKey = Get-StringValueOrDefault -Value (Get-ObjectPropertyValue -Object $stylePresetObject -Name $propertyName) -DefaultValue ""
            if (-not [string]::IsNullOrWhiteSpace($resolvedKey)) {
                $Key = $resolvedKey
                break
            }
        }
    }
    if (-not $PSBoundParameters.ContainsKey("Size")) {
        $presetSize = Get-IntValueOrDefault -Value (Get-ObjectPropertyValue -Object $stylePresetObject -Name "size") -DefaultValue 0
        if ($presetSize -gt 0) {
            $Size = @([string]$presetSize)
        }
    }
    if (-not $PSBoundParameters.ContainsKey("Theme")) {
        $Theme = Get-StringValueOrDefault -Value (Get-ObjectPropertyValue -Object $stylePresetObject -Name "theme") -DefaultValue $Theme
    }
    if (-not $PSBoundParameters.ContainsKey("Color")) {
        $Color = Get-StringValueOrDefault -Value (Get-ObjectPropertyValue -Object $stylePresetObject -Name "color") -DefaultValue $Color
    }
    if (-not $PSBoundParameters.ContainsKey("SecondaryColor")) {
        $SecondaryColor = Get-StringValueOrDefault -Value (Get-ObjectPropertyValue -Object $stylePresetObject -Name "secondaryColor") -DefaultValue $SecondaryColor
    }
    if (-not $PSBoundParameters.ContainsKey("TertiaryColor")) {
        $TertiaryColor = Get-StringValueOrDefault -Value (Get-ObjectPropertyValue -Object $stylePresetObject -Name "tertiaryColor") -DefaultValue $TertiaryColor
    }
    if (-not $PSBoundParameters.ContainsKey("QuaternaryColor")) {
        $QuaternaryColor = Get-StringValueOrDefault -Value (Get-ObjectPropertyValue -Object $stylePresetObject -Name "quaternaryColor") -DefaultValue $QuaternaryColor
    }
    if (-not $PSBoundParameters.ContainsKey("Background")) {
        $Background = Get-StringValueOrDefault -Value (Get-ObjectPropertyValue -Object $stylePresetObject -Name "background") -DefaultValue $Background
    }
    if (-not $PSBoundParameters.ContainsKey("StrokeWidth")) {
        $StrokeWidth = Get-DoubleValueOrDefault -Value (Get-ObjectPropertyValue -Object $stylePresetObject -Name "strokeWidth") -DefaultValue $StrokeWidth
    }
    if (-not $PSBoundParameters.ContainsKey("StrokeLinecap")) {
        $StrokeLinecap = Get-StringValueOrDefault -Value (Get-ObjectPropertyValue -Object $stylePresetObject -Name "strokeLinecap") -DefaultValue $StrokeLinecap
    }
    if (-not $PSBoundParameters.ContainsKey("StrokeLinejoin")) {
        $StrokeLinejoin = Get-StringValueOrDefault -Value (Get-ObjectPropertyValue -Object $stylePresetObject -Name "strokeLinejoin") -DefaultValue $StrokeLinejoin
    }
    if (-not $PSBoundParameters.ContainsKey("Weight")) {
        $Weight = Get-IntValueOrDefault -Value (Get-ObjectPropertyValue -Object $stylePresetObject -Name "weight") -DefaultValue $Weight
    }
    if (-not $PSBoundParameters.ContainsKey("Grade")) {
        $Grade = Get-IntValueOrDefault -Value (Get-ObjectPropertyValue -Object $stylePresetObject -Name "grade") -DefaultValue $Grade
    }
    if (-not $PSBoundParameters.ContainsKey("OpticalSize")) {
        $OpticalSize = Get-IntValueOrDefault -Value (Get-ObjectPropertyValue -Object $stylePresetObject -Name "opticalSize") -DefaultValue $OpticalSize
    }
}

if ([string]::IsNullOrWhiteSpace($Key)) {
    throw "请传入 -Key，或在 -StylePreset JSON 中提供 uniqueKey / imageName / key。"
}

if ([string]::IsNullOrWhiteSpace($CatalogDirectory)) {
    $CatalogDirectory = Get-CatalogDirectory
}

$formatList = @(Get-FormatList -InputFormat $Format)
$resolvedSizes = @(Get-ResolvedSizeList -InputSize $Size -FormatList $formatList)
$skillRoot = Get-SkillRoot
$outputPlan = Resolve-ExportOutputPlan -OutputPath $OutputPath -FormatList $formatList -ResolvedSizes $resolvedSizes -SkillRoot $skillRoot
$styleOptions = Resolve-StyleOptions -ThemeName $Theme -PrimaryColor $Color -SecondaryColorValue $SecondaryColor -TertiaryColorValue $TertiaryColor -QuaternaryColorValue $QuaternaryColor -StrokeWidthValue $StrokeWidth -LinecapValue $StrokeLinecap -LinejoinValue $StrokeLinejoin -WeightValue $Weight -GradeValue $Grade -OpticalSizeValue $OpticalSize

$libraryName = Get-UniqueKeyLibraryName -UniqueKey $Key
$catalogLookup = if ([string]::IsNullOrWhiteSpace($libraryName)) {
    Load-CatalogLookup -CatalogDirectory $CatalogDirectory
}
else {
    Load-CatalogLookup -CatalogDirectory $CatalogDirectory -Libraries @($libraryName)
}
$match = Resolve-IconCatalogItem -InputKey $Key -CatalogLookup $catalogLookup
if ($null -eq $match -and -not [string]::IsNullOrWhiteSpace($libraryName)) {
    $catalogLookup = Load-CatalogLookup -CatalogDirectory $CatalogDirectory
    $match = Resolve-IconCatalogItem -InputKey $Key -CatalogLookup $catalogLookup
}
if ($null -eq $match) {
    $result = [pscustomobject]@{
        status             = "not_found"
        requestCount       = 1
        foundCount         = 0
        missingCount       = 1
        formats            = @($formatList)
        sizes              = @($resolvedSizes)
        outputPath         = $outputPlan.InputPath
        outputPathBase     = $outputPlan.BasePath
        items              = @()
        missing            = @(
            [pscustomobject]@{
                input = $Key.Trim()
                note  = "未找到对应图标，请优先使用搜索结果里的 uniqueKey。"
            }
        )
        stylePreset        = $stylePresetObject
        note               = "输出文件必须写到 skill 外部的绝对路径。PNG/ICO 默认依赖本机 Microsoft Edge 无头截图；如需手工指定浏览器路径，可传 -EdgePath；也可直接传搜索页复制出的 -StylePreset JSON。"
    }

    Write-Output ($result | ConvertTo-Json -Depth 8)
    return
}

$svgMarkup = Convert-SvgColor -SvgMarkup ([string]$match.svg) -StyleOptions $styleOptions
$generatedFiles = New-Object System.Collections.Generic.List[object]
$icoFrameMap = @{}
$temporaryPngPaths = New-Object System.Collections.Generic.List[string]

if ($formatList -contains "svg") {
    $svgPath = Get-SvgOutputPath -OutputPlan $outputPlan
    Write-Utf8NoBomFile -Path $svgPath -Content $svgMarkup
    $generatedFiles.Add([pscustomobject]@{
        format = "svg"
        size   = $null
        path   = $svgPath
    })
}

if (($formatList -contains "png") -or ($formatList -contains "ico")) {
    foreach ($canvasSize in @($resolvedSizes)) {
        $pngPath = if ($formatList -contains "png") {
            Get-PngOutputPath -OutputPlan $outputPlan -CanvasSize $canvasSize
        }
        else {
            $tempPath = Join-Path ([System.IO.Path]::GetTempPath()) ("icon-frame-{0}-{1}.png" -f ([System.Guid]::NewGuid().ToString("N")), $canvasSize)
            $temporaryPngPaths.Add($tempPath)
            $tempPath
        }

        Export-PngFrame -SvgMarkup $svgMarkup -CanvasSize $canvasSize -OutputPngPath $pngPath -BackgroundValue $Background -EdgeExecutablePath $EdgePath
        $icoFrameMap[[string]$canvasSize] = [System.IO.File]::ReadAllBytes($pngPath)

        if ($formatList -contains "png") {
            $generatedFiles.Add([pscustomobject]@{
                format = "png"
                size   = $canvasSize
                path   = $pngPath
            })
        }
    }
}

if ($formatList -contains "ico") {
    $icoPath = Get-IcoOutputPath -OutputPlan $outputPlan
    Write-IcoFile -FrameMap $icoFrameMap -OutputPath $icoPath
    $generatedFiles.Add([pscustomobject]@{
        format = "ico"
        size   = @($resolvedSizes)
        path   = $icoPath
    })
}

foreach ($tempPath in @($temporaryPngPaths.ToArray())) {
    if (Test-Path -LiteralPath $tempPath) {
        [System.IO.File]::Delete($tempPath)
    }
}

$result = [pscustomobject]@{
    status          = "ok"
    requestCount    = 1
    foundCount      = 1
    missingCount    = 0
    formats         = @($formatList)
    sizes           = @($resolvedSizes)
    outputPath      = $outputPlan.InputPath
    outputPathBase  = $outputPlan.BasePath
    items           = @(
        [pscustomobject]@{
            uniqueKey       = [string]$match.uniqueKey
            library         = [string]$match.library
            sourceId        = [string]$match.sourceId
            category        = [string]$match.category
            categoryCN      = [string]$match.categoryCN
            categoryDisplay = [string]$match.categoryDisplay
            name            = [string]$match.name
            title           = [string]$match.title
            theme           = $styleOptions.Theme
            color           = if ([string]::IsNullOrWhiteSpace($styleOptions.PrimaryColor)) { "" } else { $styleOptions.PrimaryColor }
            secondaryColor  = $styleOptions.SecondaryColor
            tertiaryColor   = $styleOptions.TertiaryColor
            quaternaryColor = $styleOptions.QuaternaryColor
            strokeWidth     = $styleOptions.StrokeWidth
            strokeLinecap   = $styleOptions.StrokeLinecap
            strokeLinejoin  = $styleOptions.StrokeLinejoin
            weight          = $styleOptions.Weight
            grade           = $styleOptions.Grade
            opticalSize     = $styleOptions.OpticalSize
            background      = Get-BackgroundCssValue -BackgroundValue $Background
            stylePreset     = [pscustomobject]@{
                imageName       = [string]$match.uniqueKey
                uniqueKey       = [string]$match.uniqueKey
                theme           = $styleOptions.Theme
                size            = if ($resolvedSizes.Count -gt 0) { $resolvedSizes[-1] } else { $null }
                color           = if ([string]::IsNullOrWhiteSpace($styleOptions.PrimaryColor)) { "" } else { $styleOptions.PrimaryColor }
                secondaryColor  = $styleOptions.SecondaryColor
                tertiaryColor   = $styleOptions.TertiaryColor
                quaternaryColor = $styleOptions.QuaternaryColor
                strokeWidth     = $styleOptions.StrokeWidth
                strokeLinecap   = $styleOptions.StrokeLinecap
                strokeLinejoin  = $styleOptions.StrokeLinejoin
                weight          = $styleOptions.Weight
                grade           = $styleOptions.Grade
                opticalSize     = $styleOptions.OpticalSize
                background      = Get-BackgroundCssValue -BackgroundValue $Background
                copySource      = "export_icon_asset"
            }
            files           = @($generatedFiles.ToArray())
        }
    )
    missing         = @()
    stylePreset     = $stylePresetObject
    note            = "输出文件必须写到 skill 外部的绝对路径。PNG/ICO 默认依赖本机 Microsoft Edge 无头截图；样式参数可直接通过搜索页复制出的 -StylePreset JSON 传入，或用独立参数覆盖；如需手工指定浏览器路径，可传 -EdgePath。"
}

Write-Output ($result | ConvertTo-Json -Depth 8)

<#
trace_ref: 49492c26-25384547-272e1d1e-7c7e73c3-f2dfc99a-f316c89e-daaeb88e
node_ref: 0aa626fa-ec3a8a1e-b73ac369-8b439b68-ef238a1e-b631c375-bd866382-69c34a1f-880ac376-9c43af78-2a40af7a-ec3aaf15-b62ac241-8f4fbf6a-ec28ae1c-9725c16e-a240ae4d-e2218c1d-9e0ec946-8641807b-ec0b841e-b11dc247-9f439b58-ef1aa91d-9022c069-8f4ea150-ee1a861c-980bc57a-88438943-ee1ca81c-8b10c07e-85429a5a-ec348b19-8a27ce6a-af43ae53-ec26811e-b606c068-a74e8776-ee1e9c15-b62ac072-9b40b043-ef16a01e-b53bc16f-934e9947-ed0f901c-b933c344-814e9259-ee1d9d1d-9022c067-8943ae53-e926a4
#>
