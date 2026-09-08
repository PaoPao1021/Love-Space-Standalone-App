[CmdletBinding()]
param(
  [switch]$AllowOccupiedPorts
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$checks = [System.Collections.Generic.List[object]]::new()

function Add-Check {
  param(
    [Parameter(Mandatory = $true)][string]$Name,
    [Parameter(Mandatory = $true)][ValidateSet('PASS', 'WARN', 'FAIL')][string]$Status,
    [Parameter(Mandatory = $true)][string]$Detail
  )
  $checks.Add([pscustomobject]@{
    Status = $Status
    Check = $Name
    Detail = $Detail
  }) | Out-Null
}

function Invoke-NativeText {
  param(
    [Parameter(Mandatory = $true)][string]$FilePath,
    [string[]]$Arguments = @()
  )
  $previousPreference = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  try {
    $output = & $FilePath @Arguments 2>&1
    $exitCode = $LASTEXITCODE
    [pscustomobject]@{
      ExitCode = $exitCode
      Output = (($output | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine).Trim()
    }
  } finally {
    $ErrorActionPreference = $previousPreference
  }
}

Write-Host 'LoveSpace 后端启动前检查（只读，不会安装或启动组件）' -ForegroundColor Cyan

$javaCommand = Get-Command java -ErrorAction SilentlyContinue
if (-not $javaCommand) {
  Add-Check 'Java' 'FAIL' '未找到 Java；需要 JDK 21 或更高版本。'
} else {
  $javaResult = Invoke-NativeText $javaCommand.Source @('-version')
  $javaVersionText = $javaResult.Output
  $javaMatch = [regex]::Match($javaVersionText, 'version\s+"(?<major>\d+)(?:\.(?<minor>\d+))?')
  if (-not $javaMatch.Success) {
    Add-Check 'Java' 'WARN' "已找到 $($javaCommand.Source)，但无法识别版本。"
  } else {
    $javaMajor = [int]$javaMatch.Groups['major'].Value
    if ($javaMajor -eq 1 -and $javaMatch.Groups['minor'].Success) {
      $javaMajor = [int]$javaMatch.Groups['minor'].Value
    }
    if ($javaMajor -lt 21) {
      Add-Check 'Java' 'FAIL' "当前 Java $javaMajor，项目需要 21 或更高版本。"
    } else {
      Add-Check 'Java' 'PASS' "Java $javaMajor：$($javaCommand.Source)"
    }
  }
}

$configuredJavaHome = [Environment]::GetEnvironmentVariable('JAVA_HOME', 'Process')
if ($configuredJavaHome -and -not (Test-Path -LiteralPath (Join-Path $configuredJavaHome 'bin\java.exe'))) {
  Add-Check 'JAVA_HOME' 'WARN' '当前 JAVA_HOME 已失效；仓库 mvnw.cmd 会自动改用 PATH 中的 Java。'
} elseif ($configuredJavaHome) {
  Add-Check 'JAVA_HOME' 'PASS' $configuredJavaHome
} else {
  Add-Check 'JAVA_HOME' 'PASS' '未设置；仓库 mvnw.cmd 会自动定位 Java。'
}

$wrapper = Join-Path $projectRoot 'server\mvnw.cmd'
if (Test-Path -LiteralPath $wrapper) {
  Add-Check 'Maven Wrapper' 'PASS' $wrapper
} else {
  Add-Check 'Maven Wrapper' 'FAIL' '缺少 server\mvnw.cmd。'
}

$dockerCommand = Get-Command docker -ErrorAction SilentlyContinue
$dockerReady = $false
if (-not $dockerCommand) {
  Add-Check 'Docker CLI' 'FAIL' '未安装 Docker Desktop，或 docker 未加入 PATH。'
} else {
  $composeResult = Invoke-NativeText $dockerCommand.Source @('compose', 'version')
  if ($composeResult.ExitCode -ne 0) {
    Add-Check 'Docker Compose' 'FAIL' 'Docker CLI 存在，但 compose 子命令不可用。'
  } else {
    Add-Check 'Docker Compose' 'PASS' $composeResult.Output
  }

  $dockerResult = Invoke-NativeText $dockerCommand.Source @('info', '--format', '{{.ServerVersion}}')
  $serverVersion = $dockerResult.Output
  if ($dockerResult.ExitCode -eq 0 -and $serverVersion) {
    $dockerReady = $true
    Add-Check 'Docker Engine' 'PASS' "服务端版本 $serverVersion"
  } else {
    Add-Check 'Docker Engine' 'FAIL' 'Docker Desktop 尚未启动，或当前用户无法连接。'
  }
}

$wslCommand = Get-Command wsl -ErrorAction SilentlyContinue
if ($wslCommand) {
  $wslResult = Invoke-NativeText $wslCommand.Source @('--status')
  if ($wslResult.ExitCode -eq 0) {
    Add-Check 'WSL 2' 'PASS' '状态正常。'
  } elseif ($dockerReady) {
    Add-Check 'WSL 2' 'WARN' '状态检查未通过，但 Docker Engine 当前可用。'
  } else {
    Add-Check 'WSL 2' 'FAIL' 'WSL 2 内核未就绪；需要明确授权后执行系统更新。'
  }
} elseif (-not $dockerReady) {
  Add-Check 'WSL 2' 'FAIL' '未找到 WSL；Docker Desktop 的 Linux 容器后端无法启动。'
}

foreach ($port in @(3306, 8080, 9090)) {
  $listeners = @(Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue)
  if ($listeners.Count -eq 0) {
    Add-Check "端口 $port" 'PASS' '当前可用。'
    continue
  }

  $owners = @($listeners | ForEach-Object {
    $process = Get-Process -Id $_.OwningProcess -ErrorAction SilentlyContinue
    if ($process) { "$($process.ProcessName) (PID $($_.OwningProcess))" } else { "PID $($_.OwningProcess)" }
  } | Sort-Object -Unique)
  $status = if ($AllowOccupiedPorts) { 'WARN' } else { 'FAIL' }
  $detail = "已有监听：" + ($owners -join ', ') + '。默认阻止继续，避免 Compose 或 Java 启动后才因端口冲突失败。'
  if ($AllowOccupiedPorts) {
    $detail += ' 已显式使用 -AllowOccupiedPorts 跳过阻断，请确认监听者确为本项目服务。'
  }
  Add-Check "端口 $port" $status $detail
}

Write-Host ''
$checks | Format-Table -AutoSize -Wrap

$failures = @($checks | Where-Object { $_.Status -eq 'FAIL' })
if ($failures.Count -gt 0) {
  Write-Host "检查未通过：$($failures.Count) 项需要处理。" -ForegroundColor Red
  Write-Host '当前机器若仍保持“不安装环境”，可继续写代码和运行非 Docker 单元测试，但无法进行真实 MySQL/S3 联调。'
  exit 1
}

Write-Host '检查通过，可以启动本地依赖。' -ForegroundColor Green
Write-Host '下一步：docker compose -f server/compose.yml up -d --wait'
