[CmdletBinding()]
param(
    [ValidateRange(30, 86400)]
    [int] $IntervalSeconds = 300
)

$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Set-Location $repo

$descriptionPath = 'todo/repository-description.txt'
$descriptionMaxLength = 350
$protectedPaths = @(
    'index.html', 'app.js', 'style.css', 'favicon.svg', 'og-image.svg',
    '404.html', 'robots.txt', 'sitemap.xml', '.nojekyll', 'README.md',
    'src/', 'tests/', '.github/', 'visitas_totals.json'
)
$privatePathPattern = '(?i)(?:^|/)(?:var|config|credentials?|secrets?|sandbox|shots|capturas|screenshots|prints|github-setup|\.freebuff)(?:/|$)|(?:^|[._-])(?:password|passwd|token|secret|login|account|username|savefile|baus)(?:[._-]|$)|\.(?:env|token|pem|key|sav|es3|log|db)$'
$expectedCommitSubject = 'chore: update redacted repository description'

function Get-RedactedReadmeDescription {
    # Only a fixed vocabulary of technology labels may leave the README.
    # No author names, project/game handles, links, paths, or free-form prose are copied.
    $readme = Get-Content -LiteralPath (Join-Path $repo 'README.md') -Raw
    $allowedTerms = @(
        @{ Pattern = '(?i)\bPython\b'; Label = 'Python' },
        @{ Pattern = '(?i)\bHTML\b'; Label = 'HTML' },
        @{ Pattern = '(?i)\bCSS\b'; Label = 'CSS' },
        @{ Pattern = '(?i)\bJavaScript\b'; Label = 'JavaScript' },
        @{ Pattern = '(?i)\bNode(?:\.js)?\b'; Label = 'Node.js' },
        @{ Pattern = '(?i)\bFlask\b'; Label = 'Flask' },
        @{ Pattern = '(?i)\bFastAPI\b'; Label = 'FastAPI' },
        @{ Pattern = '(?i)\bSQLite\b'; Label = 'SQLite' },
        @{ Pattern = '(?i)\bPine(?:\s*v\d+)?\b'; Label = 'Pine Script' },
        @{ Pattern = '(?i)\bMQL5\b'; Label = 'MQL5' },
        @{ Pattern = '(?i)\bOpenCV\b'; Label = 'OpenCV' },
        @{ Pattern = '(?i)\bArduino\b'; Label = 'Arduino' },
        @{ Pattern = '(?i)\bCCXT\b'; Label = 'CCXT' }
    )
    $technologies = @(
        foreach ($term in $allowedTerms) {
            if ([regex]::IsMatch($readme, $term.Pattern)) { $term.Label }
        }
    ) | Select-Object -Unique
    if ($technologies.Count -eq 0) { $technologies = @('desenvolvimento de software') }
    $description = 'Portfolio de projetos de software e automação com ' + ($technologies -join ', ') + '.'
    if ($description.Length -gt $descriptionMaxLength) {
        $description = $description.Substring(0, $descriptionMaxLength).TrimEnd()
    }
    return $description
}

function Invoke-Git([string[]] $GitArgs) {
    $null = & git @GitArgs 2>$null
    if ($LASTEXITCODE -ne 0) {
        throw "Falha ao executar uma operação Git ($($GitArgs[0])). Consulte o estado do repositório."
    }
}

function Get-ChangedEntries {
    $status = @(& git status --porcelain=v1 --untracked-files=all 2>$null)
    if ($LASTEXITCODE -ne 0) { throw 'Não foi possível ler o estado Git.' }
    $entries = @()
    foreach ($line in $status) {
        if ($line.Length -ge 3) {
            $entries += [pscustomobject]@{
                Code = $line.Substring(0, 2)
                Path = $line.Substring(3).Trim('"').Replace('\', '/')
            }
        }
    }
    return $entries
}

function Test-ProtectedPath([string] $Path) {
    foreach ($protected in $protectedPaths) {
        if ($protected.EndsWith('/')) {
            if ($Path.StartsWith($protected, [StringComparison]::OrdinalIgnoreCase)) { return $true }
        } elseif ($Path.Equals($protected, [StringComparison]::OrdinalIgnoreCase)) {
            return $true
        }
    }
    return $false
}

function Get-SafePathLabel([string] $Path) {
    $extension = [IO.Path]::GetExtension($Path)
    if (-not $extension) { $extension = '[sem extensão]' }
    return "[caminho censurado] $extension"
}

function Write-SafeChangeSummary($Entries) {
    Write-Host ("Alterações detetadas: {0} ficheiro(s). Nomes e conteúdos ocultos para proteger dados pessoais." -f $Entries.Count) -ForegroundColor Yellow
    $groups = @($Entries | ForEach-Object {
        [pscustomobject]@{ Code = $_.Code; Label = Get-SafePathLabel $_.Path }
    } | Group-Object Code, Label | Sort-Object Name)
    foreach ($group in $groups) {
        $item = $group.Group[0]
        Write-Host ("  estado {0}, {1}: {2} ficheiro(s)" -f $item.Code, $item.Label, $group.Count)
    }
    Write-Host 'Nenhum diff bruto é mostrado: pode conter passwords, APIs, contas ou nicks.' -ForegroundColor DarkGray
}

function Get-Upstream {
    $upstream = & git rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $upstream) { return $null }
    return [string]$upstream
}

function Get-AheadCount([string] $Upstream) {
    $count = & git rev-list --count "$Upstream..HEAD" 2>$null
    if ($LASTEXITCODE -ne 0) { return $null }
    return [int]$count
}

function Test-PendingCommitSafe([string] $Upstream, [string] $ExpectedDescription) {
    $ahead = Get-AheadCount $Upstream
    if ($null -eq $ahead -or $ahead -ne 1) { return $false }
    $subject = & git log -1 --format=%s 2>$null
    if ($LASTEXITCODE -ne 0 -or $subject -cne $expectedCommitSubject) { return $false }
    $paths = @(& git diff --name-only "$Upstream..HEAD" 2>$null)
    if ($LASTEXITCODE -ne 0 -or $paths.Count -ne 1 -or $paths[0] -cne $descriptionPath) { return $false }
    $committedDescription = & git show "HEAD:$descriptionPath" 2>$null
    if ($LASTEXITCODE -ne 0) { return $false }
    return ((($committedDescription -join "`n").Trim()) -ceq $ExpectedDescription)
}

function Update-Description([string] $Description) {
    $absolutePath = Join-Path $repo $descriptionPath
    Set-Content -LiteralPath $absolutePath -Value $Description -Encoding UTF8
    Write-Host ("Descrição censurada regenerada a partir do README: {0} tecnologia(s), {1} caracteres." -f (($Description -split ', ').Count), $Description.Length) -ForegroundColor Green

    # The GitHub CLI receives only the prebuilt allowlisted summary, never raw README text.
    $gh = Get-Command 'gh' -ErrorAction SilentlyContinue
    if (-not $gh) {
        Write-Host 'GitHub CLI não instalado; descrição local atualizada, descrição remota inalterada.' -ForegroundColor DarkGray
        return
    }
    $remoteDescription = & gh repo view --json description --jq '.description' 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Host 'Descrição remota não verificada (repo/autenticação indisponível); nenhuma alteração remota feita.' -ForegroundColor DarkGray
        return
    }
    if ([string]$remoteDescription -cne $Description) {
        $null = & gh repo edit --description $Description 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Host 'Descrição pública do repositório atualizada com texto censurado.' -ForegroundColor Green
        } else {
            Write-Host 'Não foi possível atualizar a descrição remota; a descrição local continua atualizada.' -ForegroundColor Yellow
        }
    }
}

function Try-PushSafePendingCommit([string] $Upstream, [string] $Description) {
    if (-not (Test-PendingCommitSafe $Upstream $Description)) { return $false }
    Write-Host 'Encontrei um único commit automático já validado (apenas descrição censurada); a tentar enviá-lo.' -ForegroundColor Cyan
    $null = & git push 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host 'Push concluído.' -ForegroundColor Green
    } else {
        Write-Host 'Push não concluído; será novamente tentado no próximo ciclo.' -ForegroundColor Yellow
    }
    return $true
}

function Invoke-AuditCycle {
    Write-Host ''
    Write-Host ('=' * 72) -ForegroundColor DarkGray
    Write-Host ("[{0}] Auditoria" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')) -ForegroundColor Cyan

    $description = Get-RedactedReadmeDescription
    Update-Description $description
    $entries = @(Get-ChangedEntries)
    if ($entries.Count -gt 0) { Write-SafeChangeSummary $entries }

    $upstream = Get-Upstream
    if (-not $upstream) {
        Write-Host 'Sem upstream Git configurado; publicação automática desativada.' -ForegroundColor Yellow
        return
    }

    if (Try-PushSafePendingCommit $upstream $description) { return }

    if ($entries.Count -eq 0) {
        Write-Host 'Sem alterações locais.' -ForegroundColor DarkGray
        $ahead = Get-AheadCount $upstream
        if ($null -ne $ahead -and $ahead -gt 0) {
            Write-Host ("Existem {0} commit(s) locais não reconhecidos como publicação segura; não serão enviados." -f $ahead) -ForegroundColor Yellow
        }
        return
    }

    # Only the generated description can ever be committed. All site files, README changes,
    # user files, secrets, game accounts, and unknown nicks are left untouched for manual review.
    if ($entries.Count -ne 1 -or $entries[0].Path -cne $descriptionPath) {
        Write-Host 'Publicação bloqueada: há alterações fora do ficheiro de descrição gerado. Nada foi staged, commitado ou enviado.' -ForegroundColor Yellow
        return
    }
    if (Test-ProtectedPath $entries[0].Path) {
        Write-Host 'Publicação bloqueada por proteção de caminho.' -ForegroundColor Yellow
        return
    }
    if (Test-Path -LiteralPath (Join-Path $repo $descriptionPath) -PathType Leaf) {
        $onDisk = (Get-Content -LiteralPath (Join-Path $repo $descriptionPath) -Raw).Trim()
        if ($onDisk -cne $description) {
            Write-Host 'Publicação bloqueada: a descrição não coincide com o texto técnico censurado gerado.' -ForegroundColor Yellow
            return
        }
    } else {
        Write-Host 'Publicação bloqueada: ficheiro gerado não encontrado.' -ForegroundColor Yellow
        return
    }

    & git diff --cached --quiet
    if ($LASTEXITCODE -ne 0) {
        Write-Host 'Há alterações staged preexistentes; não serão alteradas nem incluídas.' -ForegroundColor Yellow
        return
    }
    $ahead = Get-AheadCount $upstream
    if ($null -eq $ahead -or $ahead -ne 0) {
        Write-Host 'Há commits locais pendentes ou não foi possível confirmar a branch; nada será enviado.' -ForegroundColor Yellow
        return
    }

    Invoke-Git @('add', '--', $descriptionPath)
    $staged = @(& git diff --cached --name-only 2>$null)
    if ($LASTEXITCODE -ne 0 -or $staged.Count -ne 1 -or $staged[0] -cne $descriptionPath) {
        Write-Host 'Verificação staged falhou; commit cancelado e staging mantido para inspeção.' -ForegroundColor Yellow
        return
    }
    $stagedText = (& git show ":$descriptionPath" 2>$null) -join "`n"
    if ($LASTEXITCODE -ne 0 -or $stagedText.Trim() -cne $description) {
        Write-Host 'Conteúdo staged não corresponde à descrição censurada; commit bloqueado.' -ForegroundColor Yellow
        return
    }

    Write-Host ("Alteração segura aprovada: {0} (somente texto gerado de tecnologias permitidas)." -f (Get-SafePathLabel $descriptionPath)) -ForegroundColor Cyan
    Invoke-Git @('commit', '-m', $expectedCommitSubject)
    $null = & git push 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host 'Commit e push da descrição censurada concluídos.' -ForegroundColor Green
    } else {
        Write-Host 'Push falhou; só será tentado de novo se o commit continuar a corresponder às verificações de segurança.' -ForegroundColor Yellow
    }
}

Write-Host 'Loop seguro iniciado. O site e README nunca são commitados ou enviados. Ctrl+C para parar.' -ForegroundColor Green
Write-Host "Ciclo: $IntervalSeconds segundos (5 minutos por omissão). Inicia via PowerShell com .\autopush-loop.bat" -ForegroundColor Green
while ($true) {
    try {
        Invoke-AuditCycle
    } catch {
        Write-Host 'Erro no ciclo; sem ignorar verificações de segurança. Será tentado novamente no próximo.' -ForegroundColor Red
    }
    Write-Host ("Próxima verificação em {0} minuto(s). Ctrl+C para parar." -f [math]::Round($IntervalSeconds / 60, 1)) -ForegroundColor DarkGray
    Start-Sleep -Seconds $IntervalSeconds
}
