# Check for unmatched { in GenrePlugin.pas
$file = Get-Content 'src/GenrePlugin.pas' -Encoding UTF8
$level = 0
$errors = @()
for ($i = 0; $i -lt $file.Count; $i++) {
    $line = $file[$i]
    # Count { and } excluding string literals (simplified)
    $opens = ([regex]::Matches($line, '\{')).Count
    $closes = ([regex]::Matches($line, '\}')).Count
    if ($opens -gt 0 -or $closes -gt 0) {
        Write-Host "L$($i+1): level=$level opens=$opens closes=$closes : $($line.Trim())"
    }
    $level += $opens - $closes
}
Write-Host "`nFinal nesting level: $level"
if ($level -ne 0) { Write-Host "WARNING: Unmatched braces!" }
