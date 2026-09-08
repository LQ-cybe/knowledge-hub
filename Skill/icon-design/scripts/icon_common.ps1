Set-StrictMode -Version Latest

function Get-SkillRoot {
    if ($PSScriptRoot) {
        return (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
    }

    return (Get-Location).Path
}

function Get-Utf8BomEncoding {
    return New-Object System.Text.UTF8Encoding($true)
}

function Get-Utf8NoBomEncoding {
    return New-Object System.Text.UTF8Encoding($false)
}

function Write-Utf8BomFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$Content
    )

    $directory = Split-Path -Parent $Path
    if ($directory -and -not (Test-Path -LiteralPath $directory)) {
        [void][System.IO.Directory]::CreateDirectory($directory)
    }

    [System.IO.File]::WriteAllText($Path, $Content, (Get-Utf8BomEncoding))
}

function Write-Utf8NoBomFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$Content
    )

    $directory = Split-Path -Parent $Path
    if ($directory -and -not (Test-Path -LiteralPath $directory)) {
        [void][System.IO.Directory]::CreateDirectory($directory)
    }

    [System.IO.File]::WriteAllText($Path, $Content, (Get-Utf8NoBomEncoding))
}

function Read-JsonFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "JSON 文件不存在: $Path"
    }

    $content = [System.IO.File]::ReadAllText($Path, (Get-Utf8BomEncoding))
    return ($content | ConvertFrom-Json)
}

function Get-SearchIndexPath {
    param(
        [string]$Path = ""
    )

    if (-not [string]::IsNullOrWhiteSpace($Path)) {
        return $Path
    }

    return (Join-Path (Get-SkillRoot) "data\search-index.json")
}

function Get-SearchTokenIndexPath {
    return (Join-Path (Get-SkillRoot) "data\search-token-index.json")
}

function Get-SearchTokenDirectory {
    return (Join-Path (Get-SkillRoot) "data\search-tokens")
}

function Get-SearchTokenPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Library
    )

    return (Join-Path (Get-SearchTokenDirectory) ("{0}.json" -f $Library))
}

function Get-SearchLibraryDirectory {
    return (Join-Path (Get-SkillRoot) "data\search-libraries")
}

function Get-SearchLibraryPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Library
    )

    return (Join-Path (Get-SearchLibraryDirectory) ("{0}.json" -f $Library))
}

function Get-CatalogDirectory {
    return (Join-Path (Get-SkillRoot) "data\catalogs")
}

function Get-UniqueKeyLibraryName {
    param(
        [AllowNull()]
        [string]$UniqueKey
    )

    if ([string]::IsNullOrWhiteSpace($UniqueKey)) {
        return ""
    }

    $separatorIndex = $UniqueKey.IndexOf(":")
    if ($separatorIndex -lt 1) {
        return ""
    }

    return $UniqueKey.Substring(0, $separatorIndex)
}

function Resolve-AbsolutePath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        throw "输出路径不能为空。"
    }

    if (-not [System.IO.Path]::IsPathRooted($Path)) {
        throw "输出路径必须是绝对路径: $Path"
    }

    return [System.IO.Path]::GetFullPath($Path)
}

function Test-PathInsideRoot {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$RootPath
    )

    $resolvedPath = Resolve-AbsolutePath -Path $Path
    $resolvedRoot = Resolve-AbsolutePath -Path $RootPath
    $normalizedRoot = $resolvedRoot.TrimEnd("\")
    if ($resolvedPath.Equals($normalizedRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        return $true
    }

    return $resolvedPath.StartsWith(($normalizedRoot + "\"), [System.StringComparison]::OrdinalIgnoreCase)
}

function Assert-ExternalOutputPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [string]$ParameterName = "OutputPath",

        [string]$SkillRoot = ""
    )

    $resolvedPath = Resolve-AbsolutePath -Path $Path
    $root = if ([string]::IsNullOrWhiteSpace($SkillRoot)) { Get-SkillRoot } else { Resolve-AbsolutePath -Path $SkillRoot }

    if (Test-PathInsideRoot -Path $resolvedPath -RootPath $root) {
        throw ("参数 -{0} 不能写到 skill 目录内部，请传用户项目里的外部绝对路径: {1}" -f $ParameterName, $resolvedPath)
    }

    return $resolvedPath
}

function Normalize-IconText {
    param(
        [AllowNull()]
        [string]$Text
    )

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return ""
    }

    $value = $Text.ToLowerInvariant()
    $value = $value -replace "[-_/\\:\.\|]+", " "
    $value = $value -replace "[^0-9a-z\u4e00-\u9fa5\s]+", " "
    $value = $value -replace "\s+", " "
    return $value.Trim()
}

function Split-SearchTokens {
    param(
        [string[]]$TextList
    )

    $tokenList = New-Object System.Collections.Generic.List[string]

    foreach ($text in ($TextList | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })) {
        $normalized = Normalize-IconText -Text $text
        if (-not $normalized) {
            continue
        }

        $tokenList.Add($normalized)
        foreach ($token in ($normalized -split "\s+")) {
            if (-not [string]::IsNullOrWhiteSpace($token)) {
                $tokenList.Add($token)
            }
        }
    }

    return $tokenList | Where-Object { $_ } | Select-Object -Unique
}

function Get-SearchSynonymMap {
    return @{
        "logo"      = @("brand", "icon", "symbol", "mark")
        "brand"     = @("logo", "mark", "symbol")
        "icon"      = @("logo", "symbol", "mark")
        "search"    = @("find", "lookup", "magnifier")
        "find"      = @("search", "lookup")
        "home"      = @("house", "main")
        "user"      = @("account", "profile", "person", "member")
        "account"   = @("user", "profile", "member")
        "setting"   = @("settings", "config", "gear", "cog")
        "settings"  = @("setting", "config", "gear", "cog")
        "config"    = @("setting", "settings", "gear")
        "edit"      = @("write", "modify", "pencil")
        "write"     = @("edit", "modify", "pencil")
        "delete"    = @("remove", "trash", "bin")
        "remove"    = @("delete", "trash", "bin")
        "close"     = @("cancel", "x")
        "error"     = @("warning", "alert", "danger")
        "warning"   = @("error", "alert", "danger")
        "success"   = @("ok", "check", "done", "tick")
        "check"     = @("success", "ok", "done", "tick")
        "mail"      = @("email", "message", "letter")
        "email"     = @("mail", "message", "letter")
        "message"   = @("chat", "mail", "comment")
        "chat"      = @("message", "comment", "dialog")
        "phone"     = @("call", "mobile", "telephone")
        "calendar"  = @("date", "schedule")
        "time"      = @("clock", "timer")
        "clock"     = @("time", "timer")
        "image"     = @("picture", "photo")
        "picture"   = @("image", "photo")
        "photo"     = @("image", "camera", "picture")
        "camera"    = @("photo", "picture", "image")
        "video"     = @("play", "media")
        "music"     = @("audio", "voice")
        "audio"     = @("music", "voice")
        "voice"     = @("audio", "music", "mic")
        "download"  = @("import", "down")
        "upload"    = @("export", "up")
        "export"    = @("upload", "share")
        "share"     = @("send", "export")
        "link"      = @("url", "chain")
        "lock"      = @("secure", "password")
        "folder"    = @("directory")
        "file"      = @("document", "page")
        "document"  = @("file", "page")
        "chart"     = @("graph", "data")
        "data"      = @("database", "chart")
        "shop"      = @("cart", "store")
        "cart"      = @("shop", "shopping")
        "payment"   = @("pay", "wallet")
        "github"    = @("git", "code", "repository")
        "wechat"    = @("weixin", "chat", "message")
        "youtube"   = @("video", "play", "media")
    }
}

function Expand-SearchKeywords {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Keyword
    )

    $synonymMap = Get-SearchSynonymMap
    $termWeightMap = @{}

    foreach ($term in (Split-SearchTokens -TextList $Keyword)) {
        if (-not $termWeightMap.ContainsKey($term) -or $termWeightMap[$term] -lt 1.0) {
            $termWeightMap[$term] = 1.0
        }

        if ($synonymMap.ContainsKey($term)) {
            foreach ($synonym in $synonymMap[$term]) {
                $normalized = Normalize-IconText -Text $synonym
                if (-not $normalized) {
                    continue
                }

                if (-not $termWeightMap.ContainsKey($normalized) -or $termWeightMap[$normalized] -lt 0.65) {
                    $termWeightMap[$normalized] = 0.65
                }
            }
        }
    }

    $result = foreach ($key in $termWeightMap.Keys) {
        [pscustomobject]@{
            Term   = $key
            Weight = [double]$termWeightMap[$key]
        }
    }

    return $result | Sort-Object -Property @{ Expression = "Weight"; Descending = $true }, @{ Expression = "Term"; Descending = $false }
}

function Get-TextBigrams {
    param(
        [string]$Text
    )

    $normalized = (Normalize-IconText -Text $Text) -replace "\s+", ""
    if (-not $normalized) {
        return @()
    }

    if ($normalized.Length -eq 1) {
        return @($normalized)
    }

    $result = New-Object System.Collections.Generic.List[string]
    for ($index = 0; $index -lt ($normalized.Length - 1); $index++) {
        $result.Add($normalized.Substring($index, 2))
    }

    return $result
}

function Get-DiceScore {
    param(
        [string]$Left,
        [string]$Right
    )

    $leftValue = Normalize-IconText -Text $Left
    $rightValue = Normalize-IconText -Text $Right
    if (-not $leftValue -or -not $rightValue) {
        return 0.0
    }

    if ($leftValue -eq $rightValue) {
        return 1.0
    }

    $leftBigrams = @(Get-TextBigrams -Text $leftValue)
    $rightBigrams = @(Get-TextBigrams -Text $rightValue)
    if ($leftBigrams.Count -eq 0 -or $rightBigrams.Count -eq 0) {
        return 0.0
    }

    $leftMap = @{}
    foreach ($item in $leftBigrams) {
        if (-not $leftMap.ContainsKey($item)) {
            $leftMap[$item] = 0
        }

        $leftMap[$item] += 1
    }

    $intersection = 0
    foreach ($item in $rightBigrams) {
        if ($leftMap.ContainsKey($item) -and $leftMap[$item] -gt 0) {
            $leftMap[$item] -= 1
            $intersection += 1
        }
    }

    return (2.0 * $intersection) / ($leftBigrams.Count + $rightBigrams.Count)
}

function Get-MatchScore {
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Entry,

        [Parameter(Mandatory = $true)]
        [object[]]$TermSpecs
    )

    $totalScore = 0.0
    $matchDetails = New-Object System.Collections.Generic.List[string]
    $matchedOriginalTerms = New-Object System.Collections.Generic.HashSet[string]

    foreach ($termSpec in $TermSpecs) {
        $term = $termSpec.Term
        $weight = [double]$termSpec.Weight
        if (-not $term) {
            continue
        }

        $bestScore = 0.0
        $bestTarget = ""

        foreach ($alias in @($Entry.aliases)) {
            if (-not $alias) {
                continue
            }

            if ($alias -eq $term) {
                $bestScore = 1.0
                $bestTarget = $alias
                break
            }

            if ($alias.Contains($term) -or $term.Contains($alias)) {
                $candidate = 0.9
                if ($candidate -gt $bestScore) {
                    $bestScore = $candidate
                    $bestTarget = $alias
                }

                continue
            }

            $dice = Get-DiceScore -Left $alias -Right $term
            if ($dice -gt $bestScore) {
                $bestScore = $dice
                $bestTarget = $alias
            }
        }

        if ($bestScore -ge 0.55) {
            $weighted = [Math]::Round(($bestScore * $weight * 100), 2)
            $totalScore += $weighted
            $null = $matchedOriginalTerms.Add($term)
            $matchDetails.Add(("{0} -> {1}" -f $term, $bestTarget))
        }
    }

    if ($matchedOriginalTerms.Count -gt 0) {
        $coverageBonus = $matchedOriginalTerms.Count * 8
        $totalScore += $coverageBonus
    }

    return [pscustomobject]@{
        Score        = [Math]::Round($totalScore, 2)
        MatchSummary = ($matchDetails | Select-Object -Unique) -join "; "
    }
}

function ConvertTo-HtmlSafeText {
    param(
        [AllowNull()]
        [string]$Text
    )

    if ($null -eq $Text) {
        return ""
    }

    return [System.Net.WebUtility]::HtmlEncode($Text)
}

function Load-CatalogLookup {
    param(
        [string]$CatalogDirectory = "",

        [string[]]$Libraries = @()
    )

    if ([string]::IsNullOrWhiteSpace($CatalogDirectory)) {
        $CatalogDirectory = Get-CatalogDirectory
    }

    if (-not (Test-Path -LiteralPath $CatalogDirectory)) {
        throw "Catalog 目录不存在: $CatalogDirectory"
    }

    $lookup = @{}
    $catalogFiles = Get-ChildItem -LiteralPath $CatalogDirectory -Filter "*.json" -File
    if ($Libraries.Count -gt 0) {
        $librarySet = @{}
        foreach ($library in $Libraries) {
            if (-not [string]::IsNullOrWhiteSpace($library)) {
                $librarySet[$library.ToLowerInvariant()] = $true
            }
        }

        $catalogFiles = @(
            $catalogFiles | Where-Object {
                $baseName = [System.IO.Path]::GetFileNameWithoutExtension($_.Name)
                $librarySet.ContainsKey($baseName.ToLowerInvariant())
            }
        )
    }

    foreach ($catalogFile in $catalogFiles) {
        $items = @(Read-JsonFile -Path $catalogFile.FullName)
        foreach ($item in $items) {
            $lookup[[string]$item.uniqueKey] = $item
        }
    }

    return $lookup
}

<#
dist_id: 1a4fdc26-763eb547-7428ed1e-2f7883c3-a1d9399a-a010389e-89a8488e
resource_ref: 44a9df43-a23573a7-f9353ad0-c54c62d1-a12c73a7-f83e3acc-f3899a3b-27ccb3a6-c6053acf-d24c56c1-644f56c3-a23556ac-f8253bf8-c14046d3-a22757a5-d92a38d7-ec4f57f4-ac2e75a4-d00130ff-c84e79c2-a2047da7-ff123bfe-d14c62e1-a11550a4-de2d39d0-c14158e9-a0157fa5-d6043cc3-c64c70fa-a01351a5-c51f39c7-cb4d63e3-a23b72a0-c42837d3-e14c57ea-a22978a7-f80939d1-e9417ecf-a01165ac-f82539cb-d54f49fa-a11959a7-fb3438d6-dd4160fe-a30069a5-f73c3afd-cf416be0-a01264a4-de2d39de-c74c57ea-a7295d
#>
