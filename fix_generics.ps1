# Mass-fix remaining generic issues in src/*.pas
$files = Get-ChildItem "src\*.pas" -File
$count = 0
foreach ($f in $files) {
    $content = Get-Content $f.FullName -Raw -Encoding UTF8
    $original = $content
    
    # Fix: := TDictionary<string without specialize
    $content = $content -replace ':= (TDictionary<string)', ':= specialize $1'
    
    # Fix: := TList< without specialize  (but not "specialize TList")
    $content = $content -replace ':= (TList<)(?!specialize)', ':= specialize $1'
    
    # Fix: := TObjectList< without specialize
    $content = $content -replace ':= (TObjectList<)(?!specialize)', ':= specialize $1'
    
    if ($content -ne $original) {
        [System.IO.File]::WriteAllText($f.FullName, $content, (New-Object System.Text.UTF8Encoding $false))
        Write-Host "Fixed: $($f.Name)"
        $count++
    }
}
Write-Host "`nTotal files fixed: $count"
