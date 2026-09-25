# Quick Git Push & Vercel Deployment Script
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "  EXECUTIVE PROJECT TRACKER" -ForegroundColor White
Write-Host "  Automated Git Push & Vercel Deploy" -ForegroundColor Yellow
Write-Host "=============================================" -ForegroundColor Cyan

# Stage all changes
Write-Host "`n[1/3] Staging project changes..." -ForegroundColor Green
git add .

# Prompt or default commit message
$commitMsg = Read-Host "`nEnter commit message (Press Enter for default: 'Weekly updates & reports update')"
if ([string]::IsNullOrWhiteSpace($commitMsg)) {
    $dateStr = Get-Date -Format "yyyy-MM-dd HH:mm"
    $commitMsg = "Weekly updates & reports update - $dateStr"
}

Write-Host "`n[2/3] Committing changes..." -ForegroundColor Green
git commit -m "$commitMsg"

# Check remote
$remote = git remote
if ([string]::IsNullOrWhiteSpace($remote)) {
    Write-Host "`n[!] No Git remote configured yet." -ForegroundColor Yellow
    Write-Host "To link to your GitHub repository and enable automated Vercel deployment:" -ForegroundColor White
    Write-Host "  1. Create a new repo on GitHub (e.g., incubator-project-tracker)" -ForegroundColor Gray
    Write-Host "  2. Run:" -ForegroundColor Gray
    Write-Host "     git remote add origin https://github.com/YOUR_USERNAME/YOUR_REPO.git" -ForegroundColor Cyan
    Write-Host "     git branch -M main" -ForegroundColor Cyan
    Write-Host "     git push -u origin main" -ForegroundColor Cyan
    Write-Host "  3. Import this repository in Vercel (https://vercel.com/new). Every push will automatically deploy!" -ForegroundColor Green
} else {
    Write-Host "`n[3/3] Pushing to Git remote (Triggers Vercel Live Deployment)..." -ForegroundColor Green
    git push
    Write-Host "`n✓ Push completed! Your live Vercel link is deploying now." -ForegroundColor Cyan
}

Write-Host "`nAlternatively, to deploy directly without git push using Vercel CLI:" -ForegroundColor White
Write-Host "  npx vercel --prod`n" -ForegroundColor Yellow
