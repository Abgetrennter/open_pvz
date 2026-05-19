<#
.SYNOPSIS
    文档健康检查脚本。输出 warning 但不阻断开发。
.DESCRIPTION
    检查 5 项文档体系健康指标：agent 入口必读列表长度、ADR 完整性、
    本地 Markdown 链接、扩展草案列表、退役文档登记。
.PARAMETER ProjectRoot
    项目根目录。默认为脚本所在目录的上级。
#>
param(
    [string]$ProjectRoot = (Join-Path $PSScriptRoot "..")
)

$ErrorActionPreference = "Continue"
$ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
$warnings = 0

Write-Host "=== 文档健康检查 ==="
Write-Host ""

# ─── CHECK 1: agent 入口默认必读列表超过 5 项 ───

Write-Host "[CHECK 1] agent 入口默认必读列表"

function Get-DefaultReadItems {
    param([string]$FilePath)

    $content = Get-Content -Path $FilePath -Encoding UTF8 -Raw
    $lines = $content -split "`n"
    $capture = $false
    $items = @()

    foreach ($line in $lines) {
        if ($line -match '默认必读|核心入口|Default Read Order|Default.*read|required.*reading') {
            $capture = $true
            continue
        }
        if ($capture -and $line -match '^#{1,4}\s') {
            break
        }
        if ($capture -and $line -match '^\s*\d+\.\s+(`[^`]+\.md`|\[[^\]]+\.md\]\([^)]+\.md\))') {
            $items += $line.Trim()
        }
    }

    return $items
}

$agentEntryFiles = @("agent.md", "AGENTS.md")
foreach ($entryFile in $agentEntryFiles) {
    $entryPath = Join-Path $ProjectRoot $entryFile
    if (!(Test-Path $entryPath)) {
        Write-Host "  SKIP  $entryFile 不存在"
        continue
    }

    $requiredItems = @(Get-DefaultReadItems -FilePath $entryPath)
    if ($requiredItems.Count -eq 0) {
        Write-Host "  OK    $entryFile 未找到可识别的必读列表段落"
    } elseif ($requiredItems.Count -gt 5) {
        Write-Host "  WARN  $entryFile 必读列表有 $($requiredItems.Count) 项（上限 5）"
        $warnings++
        foreach ($item in $requiredItems) {
            Write-Host "        - $($item -replace '^\s*\d+\.\s*', '')"
        }
    } else {
        Write-Host "  OK    $entryFile 必读列表有 $($requiredItems.Count) 项"
    }
}

Write-Host ""

# ─── CHECK 2: wiki/decisions/ ADR 完整性 ───

Write-Host "[CHECK 2] wiki/decisions/ ADR 完整性"

$decisionsDir = Join-Path $ProjectRoot "wiki" "decisions"
$decisionsReadme = Join-Path $decisionsDir "README.md"

if (!(Test-Path $decisionsDir)) {
    Write-Host "  SKIP  wiki/decisions/ 目录不存在"
} elseif (!(Test-Path $decisionsReadme)) {
    Write-Host "  SKIP  wiki/decisions/README.md 不存在"
} else {
    # 扫描实际 ADR 文件
    $actualAdrs = @(Get-ChildItem -Path $decisionsDir -Filter "ADR-*.md" -File |
        ForEach-Object { $_.Name })

    # 从 README 中提取链接到的文件名
    $readmeContent = Get-Content -Path $decisionsReadme -Encoding UTF8 -Raw
    $linkedAdrs = @([regex]::Matches($readmeContent, '\[([^\]]*)\]\((ADR-[^)]+\.md)\)') |
        ForEach-Object { $_.Groups[2].Value })

    # 找出漏列的 ADR
    $missing = @($actualAdrs | Where-Object { $_ -notin $linkedAdrs })

    if ($missing.Count -eq 0) {
        Write-Host "  OK    $($actualAdrs.Count) 个 ADR 全部列在 README 中"
    } else {
        Write-Host "  WARN  $($missing.Count) 个 ADR 未在 README 中列出："
        $warnings++
        foreach ($m in $missing) {
            Write-Host "        - $m"
        }
    }
}

Write-Host ""

# ─── CHECK 3: 本地 Markdown 链接失效检查 ───

Write-Host "[CHECK 3] 本地 Markdown 链接检查"

$filesToCheck = @(
    (Join-Path $ProjectRoot "wiki" "index.md"),
    (Join-Path $ProjectRoot "wiki" "05-governance" "29-文档规范与维护约定.md"),
    (Join-Path $ProjectRoot "plans" "README.md")
)

$brokenLinks = @()

foreach ($filePath in $filesToCheck) {
    if (!(Test-Path $filePath)) {
        continue
    }
    $fileDir = [System.IO.Path]::GetDirectoryName($filePath)
    $relName = [System.IO.Path]::GetRelativePath($ProjectRoot, $filePath)
    $fileContent = Get-Content -Path $filePath -Encoding UTF8 -Raw

    # 匹配本地 Markdown 链接 [text](relative/path.md) 但排除 http:// https:// mailto:
    $linkMatches = [regex]::Matches($fileContent, '\[([^\]]*)\]\(([^)]+)\)')
    foreach ($match in $linkMatches) {
        $target = $match.Groups[2].Value
        # 跳过外部链接、锚点、图片
        if ($target -match '^(https?:|mailto:|#)' -or $target -match '^\s*$') {
            continue
        }
        # 去掉锚点后缀
        $targetPath = $target -replace '#.*$'
        # 去掉查询参数
        $targetPath = $targetPath -replace '\?.*$'

        $resolved = [System.IO.Path]::GetFullPath((Join-Path $fileDir $targetPath))
        if (!(Test-Path $resolved)) {
            $brokenLinks += "$relName -> $target"
        }
    }
}

if ($brokenLinks.Count -eq 0) {
    Write-Host "  OK    所有本地链接有效"
} else {
    Write-Host "  WARN  $($brokenLinks.Count) 个失效链接："
    $warnings++
    foreach ($link in $brokenLinks) {
        Write-Host "        - $link"
    }
}

Write-Host ""

# ─── CHECK 4: plans/draft/extension-system/ 草案列表完整性 ───

Write-Host "[CHECK 4] plans/draft/extension-system/ 草案列表"

$extDraftDir = Join-Path $ProjectRoot "plans" "draft" "extension-system"
$extDraftReadme = Join-Path $extDraftDir "README.md"

if (!(Test-Path $extDraftDir)) {
    Write-Host "  SKIP  plans/draft/extension-system/ 目录不存在"
} elseif (!(Test-Path $extDraftReadme)) {
    Write-Host "  SKIP  plans/draft/extension-system/README.md 不存在"
} else {
    # 扫描目录下所有 .md 文件（排除 README.md）
    $actualDrafts = @(Get-ChildItem -Path $extDraftDir -Filter "*.md" -File |
        Where-Object { $_.Name -ne "README.md" } |
        ForEach-Object { $_.Name })

    # 从 README 中提取列出的文件名
    $readmeContent = Get-Content -Path $extDraftReadme -Encoding UTF8 -Raw
    # 匹配表格中的文件引用（如 "37-扩展包新增效果与效果外置策略"）以及链接到的文件名
    $listedInReadme = @([regex]::Matches($readmeContent, '\[([^\]]*)\]\(([^)]+\.md)\)') |
        ForEach-Object { [System.IO.Path]::GetFileName($_.Groups[2].Value) })
    # 也匹配表格中直接出现的文件名（可能有或没有 .md 后缀）
    $tableFiles = @([regex]::Matches($readmeContent, '\|\s*(\d+-[^\s|]+?)(?:\.md)?\s*\|') |
        ForEach-Object {
            $name = $_.Groups[1].Value
            if (!$name.EndsWith(".md")) { $name += ".md" }
            $name
        })

    $allListed = @($listedInReadme + $tableFiles | Select-Object -Unique)

    # 找出未在 README 中列出的草案文件
    $missingDrafts = @($actualDrafts | Where-Object { $_ -notin $allListed })

    if ($missingDrafts.Count -eq 0) {
        Write-Host "  OK    所有草案文件均已在 README 中列出"
    } else {
        Write-Host "  WARN  $($missingDrafts.Count) 个草案未在 README 中列出："
        $warnings++
        foreach ($d in $missingDrafts) {
            Write-Host "        - $d"
        }
    }
}

Write-Host ""

# ─── CHECK 5: plans/archive/wiki-retired/ 未登记的 Markdown ───

Write-Host "[CHECK 5] plans/archive/wiki-retired/ 退役文档登记"

$retiredDir = Join-Path $ProjectRoot "plans" "archive" "wiki-retired"
$retiredIndex = Join-Path $ProjectRoot "wiki" "05-governance" "37-历史归档与退役文档索引.md"

if (!(Test-Path $retiredDir)) {
    Write-Host "  SKIP  plans/archive/wiki-retired/ 目录不存在"
} elseif (!(Test-Path $retiredIndex)) {
    Write-Host "  SKIP  wiki/05-governance/37-历史归档与退役文档索引.md 不存在"
} else {
    # 递归扫描 wiki-retired/ 下所有 .md 文件
    $actualRetired = @(Get-ChildItem -Path $retiredDir -Filter "*.md" -File -Recurse |
        ForEach-Object {
            [System.IO.Path]::GetRelativePath($retiredDir, $_.FullName) -replace '\\', '/'
        })

    # 从索引文件中提取引用的文件名
    $indexContent = Get-Content -Path $retiredIndex -Encoding UTF8 -Raw
    $indexLinks = @([regex]::Matches($indexContent, '\[([^\]]*)\]\(([^)]+\.md)\)') |
        ForEach-Object { $_.Groups[2].Value })

    # 构建索引中引用的相对路径集合（相对于 wiki-retired/）
    $referencedFiles = @()
    foreach ($link in $indexLinks) {
        # 解析相对于索引文件位置的链接
        $indexDir = [System.IO.Path]::GetDirectoryName($retiredIndex)
        $resolved = [System.IO.Path]::GetFullPath((Join-Path $indexDir $link))
        # 如果解析后落在 wiki-retired/ 内，则提取相对路径
        if ($resolved -like "$([System.IO.Path]::GetFullPath($retiredDir))*") {
            $rel = [System.IO.Path]::GetRelativePath($retiredDir, $resolved) -replace '\\', '/'
            $referencedFiles += $rel
        }
    }

    # 找出未登记的文件
    $unregistered = @($actualRetired | Where-Object { $_ -notin $referencedFiles })

    if ($unregistered.Count -eq 0) {
        Write-Host "  OK    所有退役文档均已登记在索引中"
    } else {
        Write-Host "  WARN  $($unregistered.Count) 个退役文档未在索引中登记："
        $warnings++
        foreach ($f in $unregistered) {
            Write-Host "        - $f"
        }
    }
}

Write-Host ""
Write-Host "=== 检查完成: $warnings warnings, 0 errors ==="

exit 0
