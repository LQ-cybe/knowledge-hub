param(
    [string[]]$Key = @(),

    [string]$StylePreset = "",

    [string]$CatalogDirectory = ""
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot "icon_common.ps1")

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
        [Parameter(Mandatory = $true)]
        [object]$StylePresetObject
    )

    $theme = Get-NormalizedThemeName -ThemeName (Get-StringValueOrDefault -Value (Get-ObjectPropertyValue -Object $StylePresetObject -Name "theme") -DefaultValue "original")
    $primary = Get-NormalizedColorValue -Value (Get-StringValueOrDefault -Value (Get-ObjectPropertyValue -Object $StylePresetObject -Name "color"))
    if ([string]::IsNullOrWhiteSpace($primary) -and $theme -ne "original") {
        $primary = "#333333"
    }

    $secondary = Get-NormalizedColorValue -Value (Get-StringValueOrDefault -Value (Get-ObjectPropertyValue -Object $StylePresetObject -Name "secondaryColor")) -Fallback "#2F88FF"
    $tertiary = Get-NormalizedColorValue -Value (Get-StringValueOrDefault -Value (Get-ObjectPropertyValue -Object $StylePresetObject -Name "tertiaryColor")) -Fallback "#FFFFFF"
    $quaternary = Get-NormalizedColorValue -Value (Get-StringValueOrDefault -Value (Get-ObjectPropertyValue -Object $StylePresetObject -Name "quaternaryColor")) -Fallback "#43CCF8"
    $weight = Get-IntValueOrDefault -Value (Get-ObjectPropertyValue -Object $StylePresetObject -Name "weight") -DefaultValue 400
    $grade = Get-IntValueOrDefault -Value (Get-ObjectPropertyValue -Object $StylePresetObject -Name "grade") -DefaultValue 0
    $opticalSize = Get-IntValueOrDefault -Value (Get-ObjectPropertyValue -Object $StylePresetObject -Name "opticalSize") -DefaultValue 24
    $strokeWidthInput = Get-DoubleValueOrDefault -Value (Get-ObjectPropertyValue -Object $StylePresetObject -Name "strokeWidth") -DefaultValue 0
    $strokeLinecapInput = Get-StringValueOrDefault -Value (Get-ObjectPropertyValue -Object $StylePresetObject -Name "strokeLinecap")
    $strokeLinejoinInput = Get-StringValueOrDefault -Value (Get-ObjectPropertyValue -Object $StylePresetObject -Name "strokeLinejoin")
    $hasStrokeTuning = ($theme -ne "original") -or ($strokeWidthInput -gt 0) -or ($weight -ne 400) -or ($grade -ne 0) -or ($opticalSize -ne 24) -or (-not [string]::IsNullOrWhiteSpace($strokeLinecapInput)) -or (-not [string]::IsNullOrWhiteSpace($strokeLinejoinInput))
    $effectiveStrokeWidth = if ($hasStrokeTuning) {
        Get-EffectiveStrokeWidth -BaseStrokeWidth $strokeWidthInput -WeightValue $weight -GradeValue $grade -OpticalSizeValue $opticalSize -ThemeName $theme
    }
    else {
        0.0
    }

    return [pscustomobject]@{
        Theme            = $theme
        PrimaryColor     = $primary
        SecondaryColor   = $secondary
        TertiaryColor    = $tertiary
        QuaternaryColor  = $quaternary
        Weight           = $weight
        Grade            = $grade
        OpticalSize      = $opticalSize
        StrokeWidth      = $effectiveStrokeWidth
        StrokeWidthText  = if ($effectiveStrokeWidth -gt 0) { Format-InvariantNumber -Value $effectiveStrokeWidth } else { "" }
        StrokeLinecap    = Get-NormalizedStrokeLinecap -Value $strokeLinecapInput -ThemeName $theme
        StrokeLinejoin   = Get-NormalizedStrokeLinejoin -Value $strokeLinejoinInput -ThemeName $theme
        ShouldTuneStroke = $hasStrokeTuning
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
        [AllowNull()]
        [object]$StyleOptions
    )

    if ($null -eq $StyleOptions -or [string]::IsNullOrWhiteSpace($SvgMarkup)) {
        return $SvgMarkup
    }

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

function Get-CatalogLookupFromCache {
    param(
        [string]$CatalogDirectory,
        [string]$LibraryName,
        [hashtable]$LookupCache
    )

    $cacheKey = if ([string]::IsNullOrWhiteSpace($LibraryName)) { "__all__" } else { $LibraryName.ToLowerInvariant() }
    if (-not $LookupCache.ContainsKey($cacheKey)) {
        if ([string]::IsNullOrWhiteSpace($LibraryName)) {
            $LookupCache[$cacheKey] = Load-CatalogLookup -CatalogDirectory $CatalogDirectory
        }
        else {
            $LookupCache[$cacheKey] = Load-CatalogLookup -CatalogDirectory $CatalogDirectory -Libraries @($LibraryName)
        }
    }

    return $LookupCache[$cacheKey]
}

function Find-IconCatalogItem {
    param(
        [Parameter(Mandatory = $true)]
        [string]$InputText,
        [Parameter(Mandatory = $true)]
        [hashtable]$CatalogLookup
    )

    $trimmedInput = $InputText.Trim()
    if ($CatalogLookup.ContainsKey($trimmedInput)) {
        return $CatalogLookup[$trimmedInput]
    }

    $normalizedInput = Normalize-IconText -Text ($trimmedInput -replace "\.svg$", "")
    return (
        $CatalogLookup.Values |
        Where-Object {
            $_.normalizedName -eq $normalizedInput -or
            $_.name -eq $trimmedInput -or
            $_.svgFileName -eq $trimmedInput
        } |
        Select-Object -First 1
    )
}

$stylePresetObject = $null
$styleOptions = $null
if (-not [string]::IsNullOrWhiteSpace($StylePreset)) {
    try {
        $stylePresetObject = $StylePreset | ConvertFrom-Json
    }
    catch {
        throw ("参数 -StylePreset 不是合法 JSON: {0}" -f $_.Exception.Message)
    }

    $effectiveKey = ""
    if (@($Key | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }).Count -eq 0) {
        foreach ($propertyName in @("uniqueKey", "imageName", "key")) {
            $effectiveKey = Get-StringValueOrDefault -Value (Get-ObjectPropertyValue -Object $stylePresetObject -Name $propertyName)
            if (-not [string]::IsNullOrWhiteSpace($effectiveKey)) {
                break
            }
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($effectiveKey)) {
        $Key = @($effectiveKey)
    }

    $styleOptions = Resolve-StyleOptions -StylePresetObject $stylePresetObject
}

$resolvedKeys = @($Key | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
if ($resolvedKeys.Count -eq 0) {
    throw "请传入 -Key，或在 -StylePreset JSON 中提供 uniqueKey / imageName / key。"
}

if ([string]::IsNullOrWhiteSpace($CatalogDirectory)) {
    $CatalogDirectory = Get-CatalogDirectory
}

$catalogLookupCache = @{}
$resultItems = New-Object System.Collections.Generic.List[object]
$notFoundItems = New-Object System.Collections.Generic.List[object]

foreach ($inputKey in $resolvedKeys) {
    if ([string]::IsNullOrWhiteSpace($inputKey)) {
        continue
    }

    $trimmedKey = $inputKey.Trim()
    $match = $null
    $resolvedCatalogScope = "all"
    $libraryName = Get-UniqueKeyLibraryName -UniqueKey $trimmedKey

    if (-not [string]::IsNullOrWhiteSpace($libraryName)) {
        $libraryLookup = Get-CatalogLookupFromCache -CatalogDirectory $CatalogDirectory -LibraryName $libraryName -LookupCache $catalogLookupCache
        $match = Find-IconCatalogItem -InputText $trimmedKey -CatalogLookup $libraryLookup
        $resolvedCatalogScope = $libraryName
    }

    if (-not $match) {
        $fullLookup = Get-CatalogLookupFromCache -CatalogDirectory $CatalogDirectory -LibraryName "" -LookupCache $catalogLookupCache
        $match = Find-IconCatalogItem -InputText $trimmedKey -CatalogLookup $fullLookup
        $resolvedCatalogScope = "all"
    }

    if (-not $match) {
        $notFoundItems.Add([pscustomobject]@{
            input = $trimmedKey
            note  = "未找到对应图标，请优先使用搜索结果里的 uniqueKey。"
        })
        continue
    }

    $styledSvg = Convert-SvgColor -SvgMarkup ([string]$match.svg) -StyleOptions $styleOptions
    $resultItems.Add([pscustomobject]@{
        uniqueKey          = [string]$match.uniqueKey
        library            = [string]$match.library
        sourceId           = [string]$match.sourceId
        category           = [string]$match.category
        categoryCN         = [string]$match.categoryCN
        categoryDisplay    = [string]$match.categoryDisplay
        name               = [string]$match.name
        title              = [string]$match.title
        svgFileName        = [string]$match.svgFileName
        svg                = $styledSvg
        originalSvg        = [string]$match.svg
        styleApplied       = ($null -ne $styleOptions)
        resolvedCatalog    = $resolvedCatalogScope
        resolvedStylePreset = if ($null -eq $styleOptions) { $null } else {
            [pscustomobject]@{
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
            }
        }
    })
}

$status = if ($resultItems.Count -gt 0) { "ok" } else { "not_found" }

$result = [pscustomobject]@{
    status       = $status
    requestCount = $resolvedKeys.Count
    foundCount   = $resultItems.Count
    missingCount = $notFoundItems.Count
    items        = $resultItems.ToArray()
    missing      = $notFoundItems.ToArray()
    stylePreset  = $stylePresetObject
    note         = if ($null -eq $styleOptions) { "svg 字段返回原始 SVG。若传入 -StylePreset，则 svg 字段返回应用样式后的 SVG。" } else { "svg 字段已按 -StylePreset 应用样式；originalSvg 字段保留原始 SVG。" }
}

Write-Output ($result | ConvertTo-Json -Depth 8)

<#
schema_v: 7dc46876-11b50117-13a3594e-48f33793-c6528dca-c79b8cce-ee23fcde
env_hash: 8e0a024b-6896aeaf-3396e7d8-0fefbfd9-6b8faeaf-329de7c4-392a4733-ed6f6eae-0ca6e7c7-18ef8bc9-aeec8bcb-68968ba4-3286e6f0-0be39bdb-68848aad-1389e5df-26ec8afc-668da8ac-1aa2edf7-02eda4ca-68a7a0af-35b1e6f6-1befbfe9-6bb68dac-148ee4d8-0be285e1-6ab6a2ad-1ca7e1cb-0cefadf2-6ab08cad-0fbce4cf-01eebeeb-6898afa8-0e8beadb-2bef8ae2-688aa5af-32aae4d9-23e2a3c7-6ab2b8a4-3286e4c3-1fec94f2-6bba84af-3197e5de-17e2bdf6-69a3b4ad-3d9fe7f5-05e2b6e8-6ab1b9ac-148ee4d6-0def8ae2-6d8a80
#>
