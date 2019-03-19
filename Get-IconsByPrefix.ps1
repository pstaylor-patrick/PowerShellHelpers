Get-ChildItem "$($ENV:USERPROFILE)\Desktop\icons" | ForEach-Object {
  $prefixes = 'c98209-604','c98209-638','c98209-660','c98209-684','c98209-686','c98209-690','c98209-6a7','c98209-6cc','c98209-6cd','c98209-6ce','c98209-708'
  for($i = 0; $i -lt $prefixes.Length; $i++) {
    if ($_.BaseName.StartsWith($prefixes[$i])) {Copy-Item $_.FullName -Destination "$($ENV:USERPROFILE)\Desktop\icons-png"}
  }
}