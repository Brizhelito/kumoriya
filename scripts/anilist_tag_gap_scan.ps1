$l10nPath = 'c:\Users\Reny\Documents\Kumoriya\apps\kumoriya_app\lib\src\app\l10n.dart'
$tagsPath = 'c:\Users\Reny\Documents\Kumoriya\anilist_tags_snapshot.json'
$l10n = Get-Content $l10nPath -Raw
$tagData = Get-Content $tagsPath -Raw | ConvertFrom-Json

function Get-Block($text, $startMarker) {
  $start = $text.IndexOf($startMarker)
  if ($start -lt 0) { return '' }
  $sub = $text.Substring($start)
  $end = $sub.IndexOf('};')
  if ($end -lt 0) { return '' }
  return $sub.Substring(0, $end + 2)
}

$exactBlock = Get-Block $l10n 'const Map<String, String> _tagTranslationsEs'
$wordBlock = Get-Block $l10n 'const Map<String, String> _tagWordTranslationsEs'
$keepBlock = Get-Block $l10n 'const Set<String> _tagWordsKeepAsIs'

$exactKeys = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
$wordKeys = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
$keepKeys = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

[regex]::Matches($exactBlock, "'([^']+)'\s*:") | ForEach-Object { [void]$exactKeys.Add($_.Groups[1].Value) }
[regex]::Matches($wordBlock, "'([^']+)'\s*:") | ForEach-Object { [void]$wordKeys.Add($_.Groups[1].Value) }
[regex]::Matches($keepBlock, "'([^']+)'") | ForEach-Object { [void]$keepKeys.Add($_.Groups[1].Value) }

$missingTags = New-Object System.Collections.Generic.List[string]
$missingTokenCounts = @{}

foreach ($entry in $tagData) {
  $name = [string]$entry.name
  if ($exactKeys.Contains($name)) { continue }

  $allCovered = $true
  foreach ($token in ($name -split ' ')) {
    if ([string]::IsNullOrWhiteSpace($token)) { continue }
    $lower = $token.ToLowerInvariant()

    if ($keepKeys.Contains($lower)) { continue }

    $parts = $lower -split '-'
    foreach ($part in $parts) {
      if ([string]::IsNullOrWhiteSpace($part)) { continue }
      if ($keepKeys.Contains($part)) { continue }
      if ($wordKeys.Contains($part)) { continue }
      $allCovered = $false
      if (-not $missingTokenCounts.ContainsKey($part)) { $missingTokenCounts[$part] = 0 }
      $missingTokenCounts[$part]++
    }
  }

  if (-not $allCovered) {
    $missingTags.Add($name)
  }
}

$sortedTokenGaps = $missingTokenCounts.GetEnumerator() | Sort-Object Value -Descending
$reportPath = 'c:\Users\Reny\Documents\Kumoriya\anilist_tag_translation_gap_report.txt'
@(
  "Total AniList tags: $($tagData.Count)",
  "Exact tag mappings: $($exactKeys.Count)",
  "Word mappings: $($wordKeys.Count)",
  "Keep-as-is words: $($keepKeys.Count)",
  "Estimated uncovered tags: $($missingTags.Count)",
  '',
  'Top missing word tokens:',
  ($sortedTokenGaps | Select-Object -First 120 | ForEach-Object { "- $($_.Key): $($_.Value)" }),
  '',
  'Sample uncovered tags (first 180):',
  ($missingTags | Select-Object -First 180 | ForEach-Object { "- $_" })
) | Set-Content -Encoding UTF8 $reportPath

Write-Output "Saved $reportPath"
Write-Output "Total tags: $($tagData.Count)"
Write-Output "Estimated uncovered tags: $($missingTags.Count)"
Write-Output 'Top 30 missing tokens:'
$sortedTokenGaps | Select-Object -First 30 | ForEach-Object { Write-Output ("{0} ({1})" -f $_.Key, $_.Value) }
