Get-ChildItem src/*.pas | ForEach-Object {
    $content = Get-Content $_.FullName -Raw
    $content = $content -replace ': TDictionary<', ': specialize TDictionary<'
    $content = $content -replace ', TDictionary<', ', specialize TDictionary<'
    $content = $content -replace 'TList<', 'specialize TList<'
    Set-Content $_.FullName $content -NoNewline -Encoding UTF8
}
