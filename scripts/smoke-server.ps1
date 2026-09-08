[CmdletBinding()]
param(
  [string]$BaseUrl = 'http://127.0.0.1:8080/api/v1',
  [string]$DevSecret = 'local-only'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$api = $BaseUrl.TrimEnd('/')
$origin = $api -replace '/api/v1$', ''
$runId = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds().ToString()

function Assert-True {
  param([bool]$Condition, [string]$Message)
  if (-not $Condition) { throw "验收失败：$Message" }
}

function Assert-Code {
  param($Response, [int]$Expected, [string]$Step)
  $actual = if ($null -ne $Response -and $null -ne $Response.code) { [int]$Response.code } else { $null }
  if ($actual -ne $Expected) {
    $body = $Response | ConvertTo-Json -Depth 20 -Compress
    throw "验收失败：$Step，期望 code=$Expected，实际响应 $body"
  }
}

function Invoke-Json {
  param(
    [string]$Method,
    [string]$Path,
    $Body,
    [string]$Token = '',
    [hashtable]$ExtraHeaders = @{}
  )

  $headers = @{}
  foreach ($entry in $ExtraHeaders.GetEnumerator()) { $headers[$entry.Key] = $entry.Value }
  if ($Token) { $headers.Authorization = "Bearer $Token" }
  $request = @{
    Method = $Method
    Uri = "$api$Path"
    Headers = $headers
    TimeoutSec = 20
  }
  if ($null -ne $Body) {
    $request.ContentType = 'application/json; charset=utf-8'
    $request.Body = $Body | ConvertTo-Json -Depth 30 -Compress
  }
  Invoke-RestMethod @request
}

function Login-Dev {
  param([string]$User)
  $response = Invoke-Json 'Post' '/auth/dev' @{ devUser = $User } '' @{
    'X-Dev-Auth-Secret' = $DevSecret
  }
  Assert-Code $response 0 "登录 $User"
  Assert-True ([bool]$response.token) "$User 未返回 JWT"
  $response
}

function Invoke-Function {
  param([string]$Token, [string]$Name, [string]$Action, $Data = @{})
  Invoke-Json 'Post' "/functions/$Name" @{ action = $Action; data = $Data } $Token
}

function Get-CoupleId {
  param($Info)
  if ($null -eq $Info.couple) { return '' }
  if ($null -ne $Info.couple._id) { return [string]$Info.couple._id }
  if ($null -ne $Info.couple.id) { return [string]$Info.couple.id }
  ''
}

function Upload-SmokeImage {
  param([string]$Token)
  Add-Type -AssemblyName System.Net.Http
  $png = [Convert]::FromBase64String(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9Y9ZFsAAAAASUVORK5CYII=')
  $client = [System.Net.Http.HttpClient]::new()
  $form = [System.Net.Http.MultipartFormDataContent]::new()
  $content = [System.Net.Http.ByteArrayContent]::new($png)
  try {
    $client.DefaultRequestHeaders.Authorization =
      [System.Net.Http.Headers.AuthenticationHeaderValue]::new('Bearer', $Token)
    $content.Headers.ContentType =
      [System.Net.Http.Headers.MediaTypeHeaderValue]::new('image/png')
    $form.Add($content, 'file', "lovespace-smoke-$runId.png")
    $httpResponse = $client.PostAsync("$api/files/images", $form).GetAwaiter().GetResult()
    $text = $httpResponse.Content.ReadAsStringAsync().GetAwaiter().GetResult()
    if (-not $httpResponse.IsSuccessStatusCode) {
      throw "图片上传 HTTP $([int]$httpResponse.StatusCode)：$text"
    }
    $result = $text | ConvertFrom-Json
    Assert-Code $result 0 '上传图片'
    $result
  } finally {
    $content.Dispose()
    $form.Dispose()
    $client.Dispose()
  }
}

function Request-FileDelete {
  param([string]$Token, [string]$FileId)
  $encoded = [Uri]::EscapeDataString($FileId)
  Invoke-Json 'Delete' "/files?fileID=$encoded" $null $Token
}

function Invoke-CleanupStep {
  param(
    [Parameter(Mandatory = $true)][scriptblock]$Action,
    [Parameter(Mandatory = $true)][string]$Step
  )
  try {
    $response = & $Action
    $code = $response.PSObject.Properties['code']
    if ($null -eq $code -or [int]$code.Value -ne 0) {
      $body = $response | ConvertTo-Json -Depth 20 -Compress
      Write-Warning "$Step 未完成，可能残留联调数据：$body"
      return $false
    }
    return $true
  } catch {
    Write-Warning "$Step 未完成，可能残留联调数据：$($_.Exception.Message)"
    return $false
  }
}

Write-Host 'LoveSpace 双账号端到端验收' -ForegroundColor Cyan
Write-Host "API: $api"

$health = Invoke-RestMethod -Method Get -Uri "$origin/actuator/health" -TimeoutSec 15
Assert-True ($health.status -eq 'UP') '健康检查不是 UP（请确认 MySQL 与 S3Mock 都已就绪）'
Write-Host '[PASS] 健康检查'

try {
  Invoke-RestMethod -Method Post -Uri "$api/functions/couple" -ContentType 'application/json' `
    -Body '{"action":"getInfo","data":{}}' -TimeoutSec 15 | Out-Null
  throw '验收失败：无 JWT 请求没有被拒绝'
} catch {
  $status = if ($_.Exception.Response) { [int]$_.Exception.Response.StatusCode } else { 0 }
  if ($status -ne 401) { throw }
}
Write-Host '[PASS] 无 JWT 返回 401'

$partnerA = Login-Dev 'partnerA'
$partnerB = Login-Dev 'partnerB'
Assert-True ($partnerA.openid -eq 'dev-partner-a') 'partnerA 身份映射错误'
Assert-True ($partnerB.openid -eq 'dev-partner-b') 'partnerB 身份映射错误'
Write-Host '[PASS] partnerA / partnerB 登录与身份映射'

$infoA = Invoke-Function $partnerA.token 'couple' 'getInfo'
$infoB = Invoke-Function $partnerB.token 'couple' 'getInfo'
Assert-Code $infoA 0 '读取 partnerA 情侣空间'
Assert-Code $infoB 0 '读取 partnerB 情侣空间'
$coupleA = Get-CoupleId $infoA
$coupleB = Get-CoupleId $infoB
$createdCouple = $false
$joinedDuringRun = $false
$completed = $false
$createAttempted = $false
$createResponseReceived = $false
$assetId = ''
$momentId = ''
$inviteCode = ''

try {
  if (-not $coupleA -and -not $coupleB) {
    $createAttempted = $true
    $create = Invoke-Function $partnerA.token 'couple' 'create' @{
      nickName = '联调账号 A'
      avatarUrl = ''
      startDate = (Get-Date).ToString('yyyy-MM-dd')
    }
    $createResponseReceived = $true
    $createCode = $create.PSObject.Properties['code']
    if ($null -ne $createCode -and [int]$createCode.Value -eq 0) {
      $createdCouple = $true
    }
    Assert-Code $create 0 'partnerA 创建情侣空间'
    $coupleA = [string]$create.coupleId
    $inviteCode = [string]$create.inviteCode
    Assert-True ([bool]$coupleA -and [bool]$inviteCode) '创建空间未返回 coupleId 或 inviteCode'
    Write-Host '[PASS] partnerA 创建情侣空间'
  } elseif ($coupleA -and $coupleA -eq $coupleB) {
    Write-Host '[PASS] 两个开发账号已在同一情侣空间，复用现有绑定'
  } else {
    throw '验收前置条件不满足：partnerA / partnerB 只有一方已绑定，或分属不同空间。请在开发数据中先解除旧绑定。'
  }

  $upload = Upload-SmokeImage $partnerA.token
  $assetId = [string]$upload.fileID
  Assert-True ($assetId.StartsWith('asset://')) '上传没有返回稳定的 asset:// 文件 ID'
  Write-Host '[PASS] 私有图片上传'

  $addMoment = Invoke-Function $partnerA.token 'moments' 'add' @{
    title = '自动联调记录'
    content = "smoke-$runId"
    images = @($assetId)
    tags = @('自动联调')
    eventDate = (Get-Date).ToString('yyyy-MM-dd')
  }
  Assert-Code $addMoment 0 '新增点滴'
  $momentId = [string]$addMoment.id
  Assert-True ([bool]$momentId) '新增点滴未返回 ID'
  Write-Host '[PASS] partnerA 新增带图点滴'

  if ($createdCouple) {
    $beforeJoinFile = Invoke-Json 'Post' '/files/temp-url' @{ fileID = $assetId } $partnerB.token
    Assert-Code $beforeJoinFile -1 '加入前读取 partnerA 图片应被拒绝'
    $beforeJoinMoment = Invoke-Function $partnerB.token 'moments' 'get' @{ id = $momentId }
    Assert-Code $beforeJoinMoment -1 '加入前读取 partnerA 点滴应被拒绝'
    Write-Host '[PASS] partnerB 加入前无法访问空间数据与图片'

    $join = Invoke-Function $partnerB.token 'couple' 'join' @{
      inviteCode = $inviteCode
      nickName = '联调账号 B'
      avatarUrl = ''
    }
    Assert-Code $join 0 'partnerB 加入情侣空间'
    Assert-True ([string]$join.coupleId -eq $coupleA) '加入后 coupleId 不一致'
    $joinedDuringRun = $true
    Write-Host '[PASS] partnerB 使用邀请码加入'
  }

  $joinedInfoA = Invoke-Function $partnerA.token 'couple' 'getInfo'
  $joinedInfoB = Invoke-Function $partnerB.token 'couple' 'getInfo'
  Assert-True ((Get-CoupleId $joinedInfoA) -eq (Get-CoupleId $joinedInfoB)) '双方情侣空间 ID 不一致'
  $roles = @([string]$joinedInfoA.user.role, [string]$joinedInfoB.user.role)
  Assert-True (($roles -contains 'creator') -and ($roles -contains 'partner')) '双方角色不是 creator / partner'
  Write-Host '[PASS] 双方空间与角色一致'

  $sharedMoment = Invoke-Function $partnerB.token 'moments' 'get' @{ id = $momentId }
  Assert-Code $sharedMoment 0 'partnerB 读取共享点滴'
  Assert-True (@($sharedMoment.data.imageAssetIds) -contains $assetId) '共享点滴未保留 asset ID'

  $tempUrl = Invoke-Json 'Post' '/files/temp-url' @{ fileID = $assetId } $partnerB.token
  Assert-Code $tempUrl 0 'partnerB 获取签名 URL'
  $download = Invoke-WebRequest -Method Get -Uri $tempUrl.tempFileURL -TimeoutSec 15 -UseBasicParsing
  Assert-True ([int]$download.StatusCode -eq 200) '签名 URL 无法下载图片'
  Write-Host '[PASS] partnerB 可读取共享点滴与签名图片'

  $update = Invoke-Function $partnerB.token 'moments' 'update' @{
    id = $momentId
    title = '自动联调记录（已更新）'
    content = "smoke-updated-$runId"
  }
  Assert-Code $update 0 'partnerB 更新点滴'
  $updated = Invoke-Function $partnerA.token 'moments' 'get' @{ id = $momentId }
  Assert-Code $updated 0 'partnerA 读取更新后的点滴'
  Assert-True ($updated.data.content -eq "smoke-updated-$runId") '更新内容未被另一账号读到'
  Write-Host '[PASS] 双账号点滴读写一致'

  $deleteReferenced = Request-FileDelete $partnerB.token $assetId
  Assert-Code $deleteReferenced -1 '被引用图片应禁止直接删除'
  Write-Host '[PASS] 被业务记录引用的图片禁止删除'

  $deleteMoment = Invoke-Function $partnerA.token 'moments' 'delete' @{ id = $momentId }
  Assert-Code $deleteMoment 0 '删除联调点滴'
  $deletedAssetId = $assetId
  $momentId = ''
  $assetId = ''
  $afterDelete = Invoke-Json 'Post' '/files/temp-url' @{ fileID = $deletedAssetId } $partnerA.token
  Assert-Code $afterDelete -1 '删除最后引用后图片应失效'
  Write-Host '[PASS] 删除记录后自动清理无引用图片'

  $completed = $true
} finally {
  if ($momentId) {
    Invoke-CleanupStep {
      Invoke-Function $partnerA.token 'moments' 'delete' @{ id = $momentId }
    } '清理临时点滴' | Out-Null
  } elseif ($assetId) {
    Invoke-CleanupStep {
      Request-FileDelete $partnerA.token $assetId
    } '清理临时图片' | Out-Null
  }
  if (-not $completed -and $createdCouple) {
    Invoke-CleanupStep {
      Invoke-Function $partnerA.token 'couple' 'dissolve'
    } '回滚本次新建情侣空间' | Out-Null
  } elseif (-not $completed -and $createAttempted -and -not $createResponseReceived) {
    Write-Warning '创建情侣空间请求的结果不确定，未自动解除以避免误删。真实测试前请用 partnerA 调用 getInfo 确认。'
  }
}

Write-Host ''
Write-Host '双账号核心链路验收通过。' -ForegroundColor Green
if ($createdCouple -and $joinedDuringRun) {
  Write-Host 'partnerA / partnerB 已保留为同一开发情侣空间，联调产生的临时点滴和图片已清理。'
}
