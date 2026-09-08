param(
    [Parameter(Mandatory = $true)]
    [string[]]$Keyword,

    [int]$Top = 48,

    [string[]]$Library = @(),

    [string]$IndexPath = "",

    [string]$OutputHtml = "",

    [switch]$NoHtml
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot "icon_common.ps1")

function Get-SearchPreviewTemplatePath {
    return (Join-Path (Get-SkillRoot) "templates\search-icons-preview.html")
}

function Resolve-ColorSuggestions {
    param(
        [string[]]$Keyword,
        [string[]]$Libraries
    )

    $terms = New-Object System.Collections.Generic.List[string]
    foreach ($value in @($Keyword) + @($Libraries)) {
        if ([string]::IsNullOrWhiteSpace([string]$value)) {
            continue
        }
        $terms.Add(([string]$value).Trim().ToLowerInvariant())
    }

    $queryText = (" {0} " -f (($terms.ToArray() | Sort-Object -Unique) -join " "))

    function Test-ColorSuggestionTerm {
        param([string[]]$Candidates)

        foreach ($candidate in @($Candidates)) {
            $needle = [string]$candidate
            if ([string]::IsNullOrWhiteSpace($needle)) {
                continue
            }
            $normalized = $needle.Trim().ToLowerInvariant()
            if ($queryText.Contains((" {0} " -f $normalized)) -or $queryText.Contains($normalized)) {
                return $true
            }
        }

        return $false
    }

    $profiles = @{
        enterprise = [pscustomobject]@{
            id               = "enterprise"
            title            = "稳重企业风"
            summary          = "默认图标先用蓝灰，强调图标再上科技蓝，适合后台、SaaS、控制台。"
            theme            = "outline"
            color            = "#475569"
            secondaryColor   = "#2563EB"
            tertiaryColor    = "#FFFFFF"
            quaternaryColor  = "#DBEAFE"
            background       = "transparent"
        }
        tech = [pscustomobject]@{
            id               = "tech"
            title            = "科技蓝紫风"
            summary          = "偏冷、偏科技、偏数字感，适合 AI 工具、开发者产品、创新型页面。"
            theme            = "two-tone"
            color            = "#334155"
            secondaryColor   = "#4F46E5"
            tertiaryColor    = "#06B6D4"
            quaternaryColor  = "#E0E7FF"
            background       = "transparent"
        }
        commerce = [pscustomobject]@{
            id               = "commerce"
            title            = "支付电商风"
            summary          = "主色保持稳重，成功与优惠再做区分，适合钱包、支付、订单、资产。"
            theme            = "two-tone"
            color            = "#334155"
            secondaryColor   = "#16A34A"
            tertiaryColor    = "#F97316"
            quaternaryColor  = "#FEF3C7"
            background       = "transparent"
        }
        content = [pscustomobject]@{
            id               = "content"
            title            = "内容活力风"
            summary          = "更轻松、更年轻，适合社区、内容页、生活方式产品，但不要全页都高饱和。"
            theme            = "filled"
            color            = "#8B5CF6"
            secondaryColor   = "#EC4899"
            tertiaryColor    = "#FFFFFF"
            quaternaryColor  = "#FCE7F3"
            background       = "transparent"
        }
        dark = [pscustomobject]@{
            id               = "dark"
            title            = "深色界面风"
            summary          = "深色界面里图标要提亮，默认先用浅灰，再用亮蓝或亮紫做强调。"
            theme            = "outline"
            color            = "#E2E8F0"
            secondaryColor   = "#60A5FA"
            tertiaryColor    = "#A78BFA"
            quaternaryColor  = "#1E293B"
            background       = "transparent"
        }
        calm = [pscustomobject]@{
            id               = "calm"
            title            = "清爽冷静风"
            summary          = "适合通用功能图标和图表辅助图标，颜色克制，便于长期使用。"
            theme            = "outline"
            color            = "#334155"
            secondaryColor   = "#0891B2"
            tertiaryColor    = "#E0F2FE"
            quaternaryColor  = "#FFFFFF"
            background       = "transparent"
        }
        minimal = [pscustomobject]@{
            id               = "minimal"
            title            = "极简黑白风"
            summary          = "适合极简页面、白底界面和更克制的功能图标，优先用单色。"
            theme            = "outline"
            color            = "#0F172A"
            secondaryColor   = "#64748B"
            tertiaryColor    = "#F8FAFC"
            quaternaryColor  = "#E2E8F0"
            background       = "transparent"
        }
        warm = [pscustomobject]@{
            id               = "warm"
            title            = "暖色亲和风"
            summary          = "更亲和、更内容化，适合运营位、落地页、生活方式和暖色参考图。"
            theme            = "filled"
            color            = "#EA580C"
            secondaryColor   = "#FB7185"
            tertiaryColor    = "#FFF7ED"
            quaternaryColor  = "#FED7AA"
            background       = "transparent"
        }
        fresh = [pscustomobject]@{
            id               = "fresh"
            title            = "清新青绿风"
            summary          = "适合轻产品、工具页、健康类和偏清爽的页面气质。"
            theme            = "two-tone"
            color            = "#334155"
            secondaryColor   = "#14B8A6"
            tertiaryColor    = "#DCFCE7"
            quaternaryColor  = "#CCFBF1"
            background       = "transparent"
        }
        brand = [pscustomobject]@{
            id               = "brand"
            title            = "品牌强调风"
            summary          = "适合首页重点入口、品牌主视觉和需要更强识别度的按钮图标。"
            theme            = "two-tone"
            color            = "#1F2937"
            secondaryColor   = "#2563EB"
            tertiaryColor    = "#DBEAFE"
            quaternaryColor  = "#FFFFFF"
            background       = "transparent"
        }
        premium = [pscustomobject]@{
            id               = "premium"
            title            = "高级深金风"
            summary          = "适合会员、高级版、金融感和偏质感的深色或中性页面。"
            theme            = "filled"
            color            = "#3F3F46"
            secondaryColor   = "#D4A017"
            tertiaryColor    = "#F5F5F4"
            quaternaryColor  = "#E7E5E4"
            background       = "transparent"
        }
    }

    $orderedIds = New-Object System.Collections.Generic.List[string]
    function Add-ColorSuggestionId {
        param([string]$Id)

        if (-not [string]::IsNullOrWhiteSpace($Id) -and -not $orderedIds.Contains($Id) -and $profiles.ContainsKey($Id)) {
            $orderedIds.Add($Id)
        }
    }

    if (Test-ColorSuggestionTerm -Candidates @("dark", "dark mode", "深色", "夜间", "黑色背景")) {
        Add-ColorSuggestionId -Id "dark"
    }
    if (Test-ColorSuggestionTerm -Candidates @("react", "vue", "ai", "科技", "开发", "编程", "技术栈", "devicon", "developer", "saas")) {
        Add-ColorSuggestionId -Id "tech"
    }
    if (Test-ColorSuggestionTerm -Candidates @("后台", "控制台", "企业", "管理", "dashboard", "admin", "fluentui-system-icons", "bootstrap-icons")) {
        Add-ColorSuggestionId -Id "enterprise"
    }
    if (Test-ColorSuggestionTerm -Candidates @("支付", "钱包", "订单", "购物车", "电商", "账单", "资产")) {
        Add-ColorSuggestionId -Id "commerce"
    }
    if (Test-ColorSuggestionTerm -Candidates @("社区", "社交", "内容", "生活", "年轻", "活动", "marketing", "campaign")) {
        Add-ColorSuggestionId -Id "content"
    }
    if (Test-ColorSuggestionTerm -Candidates @("logo", "brand", "品牌", "主视觉", "首页", "banner", "landing", "simple-icons")) {
        Add-ColorSuggestionId -Id "brand"
    }
    if (Test-ColorSuggestionTerm -Candidates @("暖色", "温暖", "亲和", "生活", "活动", "橙色", "红色", "内容营销")) {
        Add-ColorSuggestionId -Id "warm"
    }
    if (Test-ColorSuggestionTerm -Candidates @("清新", "绿色", "青色", "健康", "轻盈", "工具页", "to c")) {
        Add-ColorSuggestionId -Id "fresh"
    }
    if (Test-ColorSuggestionTerm -Candidates @("极简", "黑白", "简约", "留白", "minimal", "plain")) {
        Add-ColorSuggestionId -Id "minimal"
    }
    if (Test-ColorSuggestionTerm -Candidates @("会员", "高级", "premium", "pro", "金融", "质感", "gold", "黑金")) {
        Add-ColorSuggestionId -Id "premium"
    }

    Add-ColorSuggestionId -Id "enterprise"
    Add-ColorSuggestionId -Id "tech"
    Add-ColorSuggestionId -Id "calm"
    Add-ColorSuggestionId -Id "minimal"
    Add-ColorSuggestionId -Id "fresh"
    Add-ColorSuggestionId -Id "warm"
    Add-ColorSuggestionId -Id "brand"
    Add-ColorSuggestionId -Id "premium"

    return @(
        foreach ($id in @($orderedIds.ToArray() | Select-Object -First 8)) {
            $profiles[$id]
        }
    )
}

function New-IconPreviewHtml {
    param(
        [Parameter(Mandatory = $true)]
        [object[]]$Items,

        [Parameter(Mandatory = $true)]
        [string[]]$Keyword,

        [string[]]$Libraries = @(),

        [Parameter(Mandatory = $true)]
        [string]$OutputPath
    )

    $queryText = (($Keyword | Where-Object { $_ }) -join " / ")
    $payload = [pscustomobject]@{
        queryText     = $queryText
        resultCount   = $Items.Count
        styleDefaults = [pscustomobject]@{
            theme           = "original"
            size            = 48
            color           = "#333333"
            secondaryColor  = "#2F88FF"
            tertiaryColor   = "#FFFFFF"
            quaternaryColor = "#43CCF8"
            strokeWidth     = 4
            strokeLinecap   = "round"
            strokeLinejoin  = "round"
            weight          = 400
            grade           = 0
            opticalSize     = 24
            background      = "transparent"
        }
        colorSuggestions = @(Resolve-ColorSuggestions -Keyword $Keyword -Libraries $Libraries)
        items         = @(
            foreach ($item in $Items) {
                [pscustomobject]@{
                    uniqueKey    = [string]$item.uniqueKey
                    title        = [string]$item.title
                    titleCN      = [string]$item.titleCN
                    name         = [string]$item.name
                    mainTitle    = [string]$item.mainTitle
                    subTitle     = [string]$item.subTitle
                    category     = [string]$item.categoryDisplay
                    library      = [string]$item.library
                    libraryTitle = [string]$item.libraryTitle
                    sourceId     = [string]$item.sourceId
                    variantText  = [string]$item.variantText
                    colorHex     = [string]$item.colorHex
                    svgMarkup    = [string]$item.svgMarkup
                    score        = $item.score
                }
            }
        )
    }

    $payloadJson = $payload | ConvertTo-Json -Depth 8
    $payloadJson = $payloadJson -replace '</script>', '<\/script>'
    $templatePath = Get-SearchPreviewTemplatePath
    if (-not (Test-Path -LiteralPath $templatePath)) {
        throw "搜索结果 HTML 模板不存在: $templatePath"
    }

    $htmlTemplate = [System.IO.File]::ReadAllText($templatePath, (Get-Utf8NoBomEncoding))
    $placeholder = "__ICON_DATA_PLACEHOLDER__"
    if (-not $htmlTemplate.Contains($placeholder)) {
        throw "搜索结果 HTML 模板缺少占位符: $placeholder"
    }

    $html = $htmlTemplate.Replace($placeholder, $payloadJson)
    Write-Utf8NoBomFile -Path $OutputPath -Content $html
}

function Get-DisplayTitleParts {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Item
    )

    $title = Get-OptionalTextProperty -Object $Item -Name "title"
    $titleCN = Get-OptionalTextProperty -Object $Item -Name "titleCN"
    $name = Get-OptionalTextProperty -Object $Item -Name "name"
    $mainTitle = $title
    $subTitle = $name

    if (-not [string]::IsNullOrWhiteSpace($titleCN) -and $titleCN -ne $title) {
        $mainTitle = $titleCN
        $subTitle = $title
    }
    elseif (-not [string]::IsNullOrWhiteSpace($title)) {
        $mainTitle = $title
        if (-not [string]::IsNullOrWhiteSpace($name) -and $name -ne $title) {
            $subTitle = $name
        }
        else {
            $subTitle = [string]$Item.uniqueKey
        }
    }

    return [pscustomobject]@{
        MainTitle = $mainTitle
        SubTitle  = $subTitle
    }
}

function Get-VariantText {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Item
    )

    $parts = New-Object System.Collections.Generic.List[string]
    $size = Get-OptionalTextProperty -Object $Item -Name "size"
    $styleCN = Get-OptionalTextProperty -Object $Item -Name "styleCN"
    $styleLabel = Get-OptionalTextProperty -Object $Item -Name "styleLabel"
    $variantCN = Get-OptionalTextProperty -Object $Item -Name "variantCN"
    $variantLabel = Get-OptionalTextProperty -Object $Item -Name "variantLabel"

    if (-not [string]::IsNullOrWhiteSpace($size)) {
        $parts.Add(("{0}px" -f $size))
    }

    if (-not [string]::IsNullOrWhiteSpace($styleCN)) {
        $parts.Add($styleCN)
    }
    elseif (-not [string]::IsNullOrWhiteSpace($styleLabel)) {
        $parts.Add($styleLabel)
    }

    if ($parts.Count -eq 0) {
        if (-not [string]::IsNullOrWhiteSpace($variantCN)) {
            return $variantCN
        }

        if (-not [string]::IsNullOrWhiteSpace($variantLabel)) {
            return $variantLabel
        }

        return ""
    }

    return ($parts -join " ")
}

function Get-OptionalTextProperty {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Object,

        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) {
        return ""
    }

    return [string]$property.Value
}

function Get-LibraryFilterSet {
    param(
        [string[]]$Library
    )

    $result = @{}
    foreach ($item in @($Library)) {
        if (-not [string]::IsNullOrWhiteSpace($item)) {
            $result[$item.Trim().ToLowerInvariant()] = $true
        }
    }

    return $result
}

function Resolve-AutoLibraries {
    param(
        [string[]]$Keyword,
        [object[]]$TermSpecs
    )

    $termSet = @{}
    foreach ($value in @($Keyword)) {
        $normalized = Normalize-IconText -Text ([string]$value)
        if (-not [string]::IsNullOrWhiteSpace($normalized)) {
            $termSet[$normalized] = $true
        }
    }
    foreach ($termSpec in @($TermSpecs)) {
        $normalized = Normalize-IconText -Text ([string]$termSpec.Term)
        if (-not [string]::IsNullOrWhiteSpace($normalized)) {
            $termSet[$normalized] = $true
        }
    }

    $queryBlob = " {0} " -f (($termSet.Keys | Sort-Object) -join " ")
    $libraries = New-Object System.Collections.Generic.List[string]

    function Add-AutoLibrary {
        param([string]$LibraryName)

        if (-not [string]::IsNullOrWhiteSpace($LibraryName) -and -not $libraries.Contains($LibraryName)) {
            $libraries.Add($LibraryName)
        }
    }

    function Test-AutoKeywordMatch {
        param([string[]]$Candidates)

        foreach ($candidate in @($Candidates)) {
            $normalized = Normalize-IconText -Text $candidate
            if ([string]::IsNullOrWhiteSpace($normalized)) {
                continue
            }
            if ($termSet.ContainsKey($normalized)) {
                return $true
            }
            if ($queryBlob.Contains(" $normalized ")) {
                return $true
            }
            if ($normalized.Contains(" ") -and $queryBlob.Contains($normalized)) {
                return $true
            }
        }

        return $false
    }

    $isWindowsScene = Test-AutoKeywordMatch -Candidates @(
        "windows", "winui", "fluent", "office", "excel", "word", "powerpoint", "outlook", "teams",
        "microsoft", "windows 风格", "office 风格", "企业系统", "企业内部", "桌面工具", "桌面应用"
    )
    if ($isWindowsScene) {
        Add-AutoLibrary -LibraryName "fluentui-system-icons"
        return @($libraries.ToArray())
    }

    $isTechStack = Test-AutoKeywordMatch -Candidates @(
        "react", "vue", "angular", "svelte", "nextjs", "nuxt", "node", "nodejs", "javascript", "typescript",
        "python", "java", "go", "golang", "rust", "php", "mysql", "postgres", "postgresql", "mongodb", "redis",
        "docker", "kubernetes", "k8s", "nginx", "git", "github", "gitlab", "devops",
        "技术栈", "开发", "编程", "框架", "语言", "数据库", "前端", "后端", "云原生"
    )
    if ($isTechStack) {
        Add-AutoLibrary -LibraryName "devicon"
        return @($libraries.ToArray())
    }

    $isBrandScene = Test-AutoKeywordMatch -Candidates @(
        "logo", "brand", "品牌", "商标", "官方", "社交", "wechat", "weixin", "微信", "youtube", "facebook",
        "twitter", "x", "抖音", "tiktok", "小红书", "bilibili", "微博", "支付宝", "alipay", "淘宝", "taobao"
    )
    if ($isBrandScene) {
        Add-AutoLibrary -LibraryName "simple-icons"
        return @($libraries.ToArray())
    }

    $isExportScene = Test-AutoKeywordMatch -Candidates @(
        "下载", "导出", "export", "excel", "sheet", "csv", "文件", "document", "file", "表格", "文件输出"
    )
    if ($isExportScene) {
        Add-AutoLibrary -LibraryName "tabler-icons"
        Add-AutoLibrary -LibraryName "bootstrap-icons"
        return @($libraries.ToArray())
    }

    $isChineseBusinessScene = Test-AutoKeywordMatch -Candidates @(
        "会员", "账号", "个人中心", "支付", "钱包", "订单", "购物车", "店铺", "服务", "中文", "国内"
    )
    if ($isChineseBusinessScene) {
        Add-AutoLibrary -LibraryName "tabler-icons"
        Add-AutoLibrary -LibraryName "iconpark"
        return @($libraries.ToArray())
    }

    Add-AutoLibrary -LibraryName "tabler-icons"
    Add-AutoLibrary -LibraryName "heroicons"
    return @($libraries.ToArray())
}

function Get-EntryLibraryName {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Entry
    )

    return (Get-OptionalTextProperty -Object $Entry -Name "library")
}

function Get-UniqueKeyLibraryName {
    param(
        [Parameter(Mandatory = $true)]
        [string]$UniqueKey
    )

    $separatorIndex = $UniqueKey.IndexOf(":")
    if ($separatorIndex -lt 0) {
        return ""
    }

    return $UniqueKey.Substring(0, $separatorIndex)
}

function Test-LibraryAllowed {
    param(
        [Parameter(Mandatory = $true)]
        [string]$LibraryName,

        [Parameter(Mandatory = $true)]
        [hashtable]$LibraryFilterSet
    )

    if ($LibraryFilterSet.Count -eq 0) {
        return $true
    }

    return $LibraryFilterSet.ContainsKey($LibraryName.ToLowerInvariant())
}

function Get-JsonObjectPropertyValue {
    param(
        [Parameter(Mandatory = $true)]
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

function Get-JsonObjectPropertyNames {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Object
    )

    return @($Object.PSObject.Properties | ForEach-Object { $_.Name })
}

function Resolve-OutputHtmlPath {
    param(
        [string]$Path,
        [string]$SkillRoot
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        throw "未启用 -NoHtml 时，必须通过 -OutputHtml 传入用户项目里的外部 HTML 绝对路径。"
    }

    $resolvedPath = Assert-ExternalOutputPath -Path $Path -ParameterName "OutputHtml" -SkillRoot $SkillRoot
    if (-not $resolvedPath.EndsWith(".html", [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "参数 -OutputHtml 必须是 .html 文件绝对路径: $resolvedPath"
    }

    return $resolvedPath
}

function Get-EntrySearchTerms {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Entry
    )

    $existingTerms = Get-JsonObjectPropertyValue -Object $Entry -Name "searchTerms"
    if ($null -ne $existingTerms) {
        return @($existingTerms | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique)
    }

    $textValues = New-Object System.Collections.Generic.List[string]
    foreach ($name in @("uniqueKey", "displayName", "library", "libraryTitle", "sourceId", "category", "categoryCN", "categoryDisplay", "name", "title", "svgFileName", "normalizedName", "titleCN", "style", "styleCN", "styleLabel", "variant", "variantCN", "variantLabel", "size", "hex")) {
        $value = Get-OptionalTextProperty -Object $Entry -Name $name
        if (-not [string]::IsNullOrWhiteSpace($value)) {
            $textValues.Add($value)
        }
    }

    foreach ($item in @((Get-JsonObjectPropertyValue -Object $Entry -Name "tags"))) {
        foreach ($value in @($item)) {
            if (-not [string]::IsNullOrWhiteSpace([string]$value)) {
                $textValues.Add([string]$value)
            }
        }
    }

    foreach ($item in @((Get-JsonObjectPropertyValue -Object $Entry -Name "aliases"))) {
        foreach ($value in @($item)) {
            if (-not [string]::IsNullOrWhiteSpace([string]$value)) {
                $textValues.Add([string]$value)
            }
        }
    }

    return @(Split-SearchTokens -TextList @($textValues.ToArray()))
}

function Add-CandidateMatch {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$CandidateMap,

        [Parameter(Mandatory = $true)]
        [string]$UniqueKey,

        [Parameter(Mandatory = $true)]
        [string]$Term,

        [Parameter(Mandatory = $true)]
        [string]$MatchedToken,

        [Parameter(Mandatory = $true)]
        [double]$Score
    )

    if (-not $CandidateMap.ContainsKey($UniqueKey)) {
        $CandidateMap[$UniqueKey] = @{
            Score = 0.0
            Terms = @{}
        }
    }

    $candidate = $CandidateMap[$UniqueKey]
    if ($candidate.Terms.ContainsKey($Term)) {
        $existing = $candidate.Terms[$Term]
        if ([double]$existing.Score -ge $Score) {
            return
        }

        $candidate.Score += ($Score - [double]$existing.Score)
    }
    else {
        $candidate.Score += $Score
    }

    $candidate.Terms[$Term] = @{
        Score = $Score
        Token = $MatchedToken
    }
}

function Resolve-SearchCandidatesFromTokenIndex {
    param(
        [Parameter(Mandatory = $true)]
        [object]$TokenIndexData,

        [Parameter(Mandatory = $true)]
        [object[]]$TermSpecs,

        [Parameter(Mandatory = $true)]
        [hashtable]$LibraryFilterSet
    )

    $candidateMap = @{}
    $tokensObject = Get-JsonObjectPropertyValue -Object $TokenIndexData -Name "tokens"
    if ($null -eq $tokensObject) {
        return $candidateMap
    }

    $tokenNames = @(Get-JsonObjectPropertyNames -Object $tokensObject)
    foreach ($termSpec in $TermSpecs) {
        $term = [string]$termSpec.Term
        $weight = [double]$termSpec.Weight
        if ([string]::IsNullOrWhiteSpace($term)) {
            continue
        }

        $matched = $false
        $postings = @(Get-JsonObjectPropertyValue -Object $tokensObject -Name $term)
        if ($postings.Count -gt 0) {
            foreach ($uniqueKey in $postings) {
                if ([string]::IsNullOrWhiteSpace([string]$uniqueKey)) {
                    continue
                }

                $libraryName = Get-UniqueKeyLibraryName -UniqueKey ([string]$uniqueKey)
                if (-not (Test-LibraryAllowed -LibraryName $libraryName -LibraryFilterSet $LibraryFilterSet)) {
                    continue
                }

                Add-CandidateMatch -CandidateMap $candidateMap -UniqueKey ([string]$uniqueKey) -Term $term -MatchedToken $term -Score ([Math]::Round(($weight * 100), 2))
                $matched = $true
            }
        }

        if ($matched -or $term.Length -lt 2) {
            continue
        }

        $fallbackTokens = @(
            $tokenNames |
            Where-Object { $_ -like "$term*" -or $_.Contains($term) } |
            Select-Object -First 12
        )

        foreach ($tokenName in $fallbackTokens) {
            $factor = if ($tokenName -like "$term*") { 0.72 } else { 0.55 }
            foreach ($uniqueKey in @(Get-JsonObjectPropertyValue -Object $tokensObject -Name $tokenName)) {
                if ([string]::IsNullOrWhiteSpace([string]$uniqueKey)) {
                    continue
                }

                $libraryName = Get-UniqueKeyLibraryName -UniqueKey ([string]$uniqueKey)
                if (-not (Test-LibraryAllowed -LibraryName $libraryName -LibraryFilterSet $LibraryFilterSet)) {
                    continue
                }

                Add-CandidateMatch -CandidateMap $candidateMap -UniqueKey ([string]$uniqueKey) -Term $term -MatchedToken $tokenName -Score ([Math]::Round(($weight * 100 * $factor), 2))
            }
        }
    }

    foreach ($candidate in @($candidateMap.Values)) {
        $candidate.Score = [Math]::Round(([double]$candidate.Score + ($candidate.Terms.Count * 8)), 2)
    }

    return $candidateMap
}

function Load-TokenIndexDataForLibraries {
    param(
        [string[]]$Libraries = @()
    )

    $mergedTokens = @{}
    $libraryList = @($Libraries | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique)
    foreach ($libraryName in $libraryList) {
        $path = Get-SearchTokenPath -Library $libraryName
        if (-not (Test-Path -LiteralPath $path)) {
            continue
        }

        $tokenIndexData = Read-JsonFile -Path $path
        $tokensObject = Get-JsonObjectPropertyValue -Object $tokenIndexData -Name "tokens"
        if ($null -eq $tokensObject) {
            continue
        }

        foreach ($tokenName in @(Get-JsonObjectPropertyNames -Object $tokensObject)) {
            $mergedTokens[$tokenName] = @(Get-JsonObjectPropertyValue -Object $tokensObject -Name $tokenName)
        }
    }

    return [pscustomobject]@{
        tokens = [pscustomobject]$mergedTokens
    }
}

function Load-SearchEntryLookup {
    param(
        [string[]]$Libraries = @()
    )

    $lookup = @{}
    $libraryList = @($Libraries | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique)
    foreach ($libraryName in $libraryList) {
        $path = Get-SearchLibraryPath -Library $libraryName
        if (-not (Test-Path -LiteralPath $path)) {
            continue
        }

        $items = @(Read-JsonFile -Path $path)
        foreach ($item in $items) {
            $lookup[[string]$item.uniqueKey] = $item
        }
    }

    return $lookup
}

function Get-EntryRankBonus {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Entry,

        [Parameter(Mandatory = $true)]
        [hashtable]$Candidate
    )

    $name = Normalize-IconText -Text (Get-OptionalTextProperty -Object $Entry -Name "name")
    $title = Normalize-IconText -Text (Get-OptionalTextProperty -Object $Entry -Name "title")
    $category = Normalize-IconText -Text (Get-OptionalTextProperty -Object $Entry -Name "category")
    $categoryCN = Normalize-IconText -Text (Get-OptionalTextProperty -Object $Entry -Name "categoryCN")
    $bonus = 0.0

    foreach ($term in @($Candidate.Terms.Keys)) {
        if ($name -eq $term) {
            $bonus += 28
            continue
        }

        if ($title -eq $term) {
            $bonus += 22
            continue
        }

        if ($category -eq $term -or $categoryCN -eq $term) {
            $bonus += 14
            continue
        }

        if (($name -and $name.Contains($term)) -or ($title -and $title.Contains($term))) {
            $bonus += 10
        }
    }

    return [Math]::Round($bonus, 2)
}

function Get-CandidateMatchSummary {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Candidate
    )

    $parts = foreach ($term in @($Candidate.Terms.Keys | Sort-Object)) {
        $token = [string]$Candidate.Terms[$term].Token
        "{0} -> {1}" -f $term, $token
    }

    return ($parts -join "; ")
}

function Get-EntryFallbackMatch {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Entry,

        [Parameter(Mandatory = $true)]
        [object[]]$TermSpecs
    )

    $searchTerms = @(Get-EntrySearchTerms -Entry $Entry)
    $termSet = @{}
    foreach ($term in $searchTerms) {
        $termSet[[string]$term] = $true
    }

    $searchBlob = " {0} " -f (($searchTerms -join " ").Trim())
    $name = Normalize-IconText -Text (Get-OptionalTextProperty -Object $Entry -Name "name")
    $title = Normalize-IconText -Text (Get-OptionalTextProperty -Object $Entry -Name "title")
    $category = Normalize-IconText -Text (Get-OptionalTextProperty -Object $Entry -Name "category")
    $categoryCN = Normalize-IconText -Text (Get-OptionalTextProperty -Object $Entry -Name "categoryCN")
    $score = 0.0
    $terms = @{}

    foreach ($termSpec in $TermSpecs) {
        $term = [string]$termSpec.Term
        $weight = [double]$termSpec.Weight
        if ([string]::IsNullOrWhiteSpace($term)) {
            continue
        }

        $bestScore = 0.0
        $bestToken = ""
        if ($termSet.ContainsKey($term)) {
            $bestScore = [Math]::Round(($weight * 100), 2)
            $bestToken = $term
        }
        elseif (($searchBlob).Contains((" {0} " -f $term))) {
            $bestScore = [Math]::Round(($weight * 86), 2)
            $bestToken = $term
        }
        elseif (($name -and $name.Contains($term)) -or ($title -and $title.Contains($term)) -or ($category -and $category.Contains($term)) -or ($categoryCN -and $categoryCN.Contains($term))) {
            $bestScore = [Math]::Round(($weight * 74), 2)
            $bestToken = $term
        }

        if ($bestScore -le 0) {
            continue
        }

        $terms[$term] = @{
            Score = $bestScore
            Token = $bestToken
        }
        $score += $bestScore

        if ($name -eq $term) {
            $score += 28
        }
        elseif ($title -eq $term) {
            $score += 22
        }
        elseif ($category -eq $term -or $categoryCN -eq $term) {
            $score += 14
        }
    }

    if ($terms.Count -gt 0) {
        $score += ($terms.Count * 8)
    }

    return [pscustomobject]@{
        Score        = [Math]::Round($score, 2)
        MatchSummary = (Get-CandidateMatchSummary -Candidate @{ Terms = $terms })
    }
}

$skillRoot = Get-SkillRoot
$termSpecs = @(Expand-SearchKeywords -Keyword $Keyword)
$requestedLibraries = @($Library | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
$effectiveLibraries = if ($requestedLibraries.Count -gt 0) {
    @($requestedLibraries)
}
else {
    @(Resolve-AutoLibraries -Keyword $Keyword -TermSpecs $termSpecs)
}
$libraryMode = if ($requestedLibraries.Count -gt 0) { "explicit" } else { "auto" }
$libraryFilterSet = Get-LibraryFilterSet -Library $effectiveLibraries
$catalogLookup = $null
$indexPathInput = $IndexPath
$defaultIndexPath = Get-SearchIndexPath
$IndexPath = Get-SearchIndexPath -Path $IndexPath
$useOptimizedArtifacts = $false
if ([string]::IsNullOrWhiteSpace($indexPathInput)) {
    $useOptimizedArtifacts = $true
}
elseif ((Test-Path -LiteralPath $IndexPath) -and (Test-Path -LiteralPath $defaultIndexPath)) {
    $useOptimizedArtifacts = ((Resolve-Path -LiteralPath $IndexPath).Path -eq (Resolve-Path -LiteralPath $defaultIndexPath).Path)
}
$ranked = @()

if ($useOptimizedArtifacts -and (Test-Path -LiteralPath (Get-SearchTokenIndexPath)) -and (Test-Path -LiteralPath (Get-SearchLibraryDirectory))) {
    if ($libraryFilterSet.Count -gt 0 -and (Test-Path -LiteralPath (Get-SearchTokenDirectory))) {
        $tokenIndexData = Load-TokenIndexDataForLibraries -Libraries @($effectiveLibraries)
    }
    else {
        $tokenIndexData = Read-JsonFile -Path (Get-SearchTokenIndexPath)
    }

    $candidateMap = Resolve-SearchCandidatesFromTokenIndex -TokenIndexData $tokenIndexData -TermSpecs $termSpecs -LibraryFilterSet $libraryFilterSet
    $candidateKeys = @($candidateMap.Keys)
    $candidateLibraries = @(
        $candidateKeys |
        ForEach-Object { Get-UniqueKeyLibraryName -UniqueKey ([string]$_) } |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        Select-Object -Unique
    )
    $entryLookup = Load-SearchEntryLookup -Libraries $candidateLibraries

    $ranked = foreach ($uniqueKey in $candidateKeys) {
        if (-not $entryLookup.ContainsKey([string]$uniqueKey)) {
            continue
        }

        $entry = $entryLookup[[string]$uniqueKey]
        $candidate = $candidateMap[[string]$uniqueKey]
        $score = [Math]::Round(([double]$candidate.Score + (Get-EntryRankBonus -Entry $entry -Candidate $candidate)), 2)
        if ($score -le 0) {
            continue
        }

        [pscustomobject]@{
            uniqueKey       = [string]$entry.uniqueKey
            library         = [string]$entry.library
            libraryTitle    = [string]$entry.libraryTitle
            sourceId        = [string]$entry.sourceId
            name            = [string]$entry.name
            title           = [string]$entry.title
            category        = [string]$entry.category
            categoryCN      = [string]$entry.categoryCN
            categoryDisplay = [string]$entry.categoryDisplay
            tags            = @($entry.tags)
            score           = $score
            matchSummary    = (Get-CandidateMatchSummary -Candidate $candidate)
        }
    }
}
else {
    if (-not (Test-Path -LiteralPath $IndexPath)) {
        throw "Search index not found: $IndexPath"
    }

    $entries = @(Read-JsonFile -Path $IndexPath)
    $ranked = foreach ($entry in $entries) {
        $libraryName = Get-EntryLibraryName -Entry $entry
        if (-not (Test-LibraryAllowed -LibraryName $libraryName -LibraryFilterSet $libraryFilterSet)) {
            continue
        }

        $match = Get-EntryFallbackMatch -Entry $entry -TermSpecs $termSpecs
        if ($match.Score -le 0) {
            continue
        }

        [pscustomobject]@{
            uniqueKey       = [string]$entry.uniqueKey
            library         = [string]$entry.library
            libraryTitle    = [string]$entry.libraryTitle
            sourceId        = [string]$entry.sourceId
            name            = [string]$entry.name
            title           = [string]$entry.title
            category        = [string]$entry.category
            categoryCN      = [string]$entry.categoryCN
            categoryDisplay = [string]$entry.categoryDisplay
            tags            = @($entry.tags)
            score           = $match.Score
            matchSummary    = $match.MatchSummary
        }
    }
}

$topItems = @(
    $ranked |
    Sort-Object -Property @{ Expression = "score"; Descending = $true }, @{ Expression = "uniqueKey"; Descending = $false } |
    Select-Object -First $Top
)

if (-not $NoHtml) {
    $librariesToLoad = @(
        $topItems |
        ForEach-Object { [string]$_.library } |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        Select-Object -Unique
    )
    $catalogLookup = Load-CatalogLookup -Libraries $librariesToLoad

    foreach ($item in $topItems) {
        $catalogItem = $catalogLookup[$item.uniqueKey]
        if ($catalogItem) {
            $item | Add-Member -NotePropertyName svgMarkup -NotePropertyValue ([string]$catalogItem.svg) -Force
            $item | Add-Member -NotePropertyName titleCN -NotePropertyValue (Get-OptionalTextProperty -Object $catalogItem -Name "titleCN") -Force
            $item | Add-Member -NotePropertyName styleCN -NotePropertyValue (Get-OptionalTextProperty -Object $catalogItem -Name "styleCN") -Force
            $item | Add-Member -NotePropertyName styleLabel -NotePropertyValue (Get-OptionalTextProperty -Object $catalogItem -Name "styleLabel") -Force
            $item | Add-Member -NotePropertyName variantCN -NotePropertyValue (Get-OptionalTextProperty -Object $catalogItem -Name "variantCN") -Force
            $item | Add-Member -NotePropertyName variantLabel -NotePropertyValue (Get-OptionalTextProperty -Object $catalogItem -Name "variantLabel") -Force
            $item | Add-Member -NotePropertyName size -NotePropertyValue (Get-OptionalTextProperty -Object $catalogItem -Name "size") -Force
            $item | Add-Member -NotePropertyName colorHex -NotePropertyValue (Get-OptionalTextProperty -Object $catalogItem -Name "hex") -Force
            $item | Add-Member -NotePropertyName libraryTitle -NotePropertyValue (Get-OptionalTextProperty -Object $catalogItem -Name "libraryTitle") -Force
        }
        else {
            $item | Add-Member -NotePropertyName svgMarkup -NotePropertyValue '<svg viewBox="0 0 48 48" xmlns="http://www.w3.org/2000/svg"><rect x="8" y="8" width="32" height="32" rx="6" fill="#e2e8f0"/><path d="M16 16H32V32H16Z" fill="#94a3b8"/></svg>' -Force
            $item | Add-Member -NotePropertyName titleCN -NotePropertyValue "" -Force
            $item | Add-Member -NotePropertyName styleCN -NotePropertyValue "" -Force
            $item | Add-Member -NotePropertyName styleLabel -NotePropertyValue "" -Force
            $item | Add-Member -NotePropertyName variantCN -NotePropertyValue "" -Force
            $item | Add-Member -NotePropertyName variantLabel -NotePropertyValue "" -Force
            $item | Add-Member -NotePropertyName size -NotePropertyValue "" -Force
            $item | Add-Member -NotePropertyName colorHex -NotePropertyValue "" -Force
        }

        $titleParts = Get-DisplayTitleParts -Item $item
        $item | Add-Member -NotePropertyName mainTitle -NotePropertyValue ([string]$titleParts.MainTitle) -Force
        $item | Add-Member -NotePropertyName subTitle -NotePropertyValue ([string]$titleParts.SubTitle) -Force
        $item | Add-Member -NotePropertyName variantText -NotePropertyValue ([string](Get-VariantText -Item $item)) -Force
    }

    $OutputHtml = Resolve-OutputHtmlPath -Path $OutputHtml -SkillRoot $skillRoot

    New-IconPreviewHtml -Items $topItems -Keyword $Keyword -Libraries $effectiveLibraries -OutputPath $OutputHtml
}

$outputItems = foreach ($item in $topItems) {
    [pscustomobject]@{
        uniqueKey       = $item.uniqueKey
        library         = $item.library
        sourceId        = $item.sourceId
        category        = $item.category
        categoryCN      = $item.categoryCN
        categoryDisplay = $item.categoryDisplay
        name            = $item.name
        title           = $item.title
        score           = $item.score
        matchSummary    = $item.matchSummary
    }
}

$result = [pscustomobject]@{
    query         = @($Keyword)
    libraries     = @($effectiveLibraries)
    requestedLibraries = @($requestedLibraries)
    libraryMode   = $libraryMode
    expandedTerms = @($termSpecs | Select-Object -ExpandProperty Term)
    htmlPath      = if ($NoHtml) { "" } else { $OutputHtml }
    resultCount   = $outputItems.Count
    note          = if ($libraryMode -eq "auto") { "当前未传 -Library，脚本已按关键词自动选择库。请把 uniqueKey 原样传给 get_icon_svg.ps1；若要生成 HTML，必须通过 -OutputHtml 传入 skill 外部的绝对路径。" } else { "请把 uniqueKey 原样传给 get_icon_svg.ps1；若要生成 HTML，必须通过 -OutputHtml 传入 skill 外部的绝对路径。" }
    items         = @($outputItems)
}

Write-Output ($result | ConvertTo-Json -Depth 6)

<#
dist_id: 18b8bfc3-74c9d6a2-76df8efb-2d8fe026-a32e5a7f-a2e75b7b-8b5f2b6b
cache_key: 29569949-cfca35ad-94ca7cda-a8b324db-ccd335ad-95c17cc6-9e76dc31-4a33f5ac-abfa7cc5-bfb310cb-09b010c9-cfca10a6-95da7df2-acbf00d9-cfd811af-b4d57edd-81b011fe-c1d133ae-bdfe76f5-a5b13fc8-cffb3bad-92ed7df4-bcb324eb-ccea16ae-b3d27fda-acbe1ee3-cdea39af-bbfb7ac9-abb336f0-cdec17af-a8e07fcd-a6b225e9-cfc434aa-a9d771d9-8cb311e0-cfd63ead-95f67fdb-84be38c5-cdee23a6-95da7fc1-b8b00ff0-cce61fad-96cb7edc-b0be26f4-ceff2faf-9ac37cf7-a2be2dea-cded22ae-b3d27fd4-aab311e0-cad61b
#>
