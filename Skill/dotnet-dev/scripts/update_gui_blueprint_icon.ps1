#requires -Version 5.1

param(
    [Parameter(Mandatory = $true)]
    [string]$SourceIconPath
)

$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'gui_icon_asset_tools.ps1')

$skillRoot = Split-Path -Parent $PSScriptRoot
$assetRoot = Join-Path $skillRoot 'assets\gui-exe-default-icon'

[void](Install-GuiIconAssets -SourceIconPath $SourceIconPath -TargetDirectory $assetRoot)

Write-Host "已更新 gui-exe 内置图标资产：$assetRoot"
Write-Host "默认 ICO：$(Join-Path $assetRoot 'app.ico')"

<#
env_hash: 6b3226d8-07434fb9-055517e0-5e05793d-d0a4c364-d16dc260-f8d5b270
content_sig: 5f8dc4d0-b9116834-e2112143-de687942-ba086834-e31a215f-e8ad81a8-3ce8a835-dd21215c-c9684d52-7f6b4d50-b9114d3f-e301206b-da645d40-b9034c36-c20e2344-f76b4c67-b70a6e37-cb252b6c-d36a6251-b9206634-e436206d-ca687972-ba314b37-c5092243-da65437a-bb316436-cd202750-dd686b69-bb374a36-de3b2254-d0697870-b91f6933-df0c2c40-fa684c79-b90d6334-e32d2242-f265655c-bb357e3f-e3012258-ce6b5269-ba3d4234-e0102345-c6657b6d-b8247236-ec18216e-d4657073-bb367f37-c509224d-dc684c79-bc0d46
#>
