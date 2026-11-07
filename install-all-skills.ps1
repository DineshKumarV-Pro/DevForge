# Installs every non-template skill recorded in the supplied skills registry.
# Run this from the project folder where you want the skills installed.
# Uses npx.cmd to avoid the common PowerShell npx.ps1 execution-policy issue.

$ErrorActionPreference = 'Continue'
$total = 1446
$completed = 0
$failed = [System.Collections.Generic.List[string]]::new()

$skills = @(
    @{ Source = 'google/skills'; Skill = 'google-cloud-waf-sustainability' },
    @{ Source = 'Emmraan/agent-skills'; Skill = 'grow-website' },
    @{ Source = 'Emmraan/agent-skills'; Skill = 'gsap-frameworks' },
    @{ Source = 'Emmraan/agent-skills'; Skill = 'gsap-react' },
    @{ Source = 'google/skills'; Skill = 'iam-helper-for-policy-simulator' },
    @{ Source = 'loginvijayan/ai-agent-skills'; Skill = 'mobile-software-engineer' },
    @{ Source = 'Emmraan/agent-skills'; Skill = 'php-pro' },
    @{ Source = 'podo/design-agent-skills'; Skill = 'phuryn-pm-skills' },
    @{ Source = 'UnitOneAI/SecuritySkills'; Skill = 'pipeline-security' },
    @{ Source = 'Emmraan/agent-skills'; Skill = 'pixijs-2d' },
    @{ Source = 'podo/design-agent-skills'; Skill = 'plan-design-review' },
    @{ Source = 'dtgbao/agent-skills'; Skill = 'planning-and-task-breakdown' },
    @{ Source = 'anyulled/architecture-guardrails-skills'; Skill = 'platform-and-infrastructure-boundary-evaluator' },
    @{ Source = 'dlazy-ai/ecommerce-skills'; Skill = 'platform-compliance' },
    @{ Source = 'Owl-Listener/designer-skills'; Skill = 'platform-conventions' },
    @{ Source = 'podo/design-agent-skills'; Skill = 'platform-design-skills' },
    @{ Source = 'Emmraan/agent-skills'; Skill = 'playcanvas-engine' },
    @{ Source = 'getpoweredbyai/DesignSkills'; Skill = 'playwright' },
    @{ Source = 'petrkindlmann/qa-skills'; Skill = 'playwright-automation' }
)

foreach ($item in $skills) {
    $completed++
    Write-Host "[$completed/$total] Installing $($item.Skill) from $($item.Source)" -ForegroundColor Cyan
    & npx.cmd skills add $item.Source --skill $item.Skill -y
    if ($LASTEXITCODE -ne 0) {
        $failed.Add("$($item.Source) --skill $($item.Skill) (exit $LASTEXITCODE)")
        Write-Warning "Failed: $($item.Skill)"
    }
}

Write-Host "`nInstallation run finished. Successful attempts: $($total - $failed.Count) / $total" -ForegroundColor Green
if ($failed.Count -gt 0) {
    $failureFile = Join-Path (Get-Location) 'skills-install-failures.txt'
    $failed | Set-Content -Path $failureFile -Encoding UTF8
    Write-Warning "$($failed.Count) skills failed. See: $failureFile"
} else {
    Write-Host 'No installation errors were reported.' -ForegroundColor Green
}
