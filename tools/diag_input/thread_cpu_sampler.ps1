param([int]$ProcId, [double]$Seconds = 25, [int]$IntervalMs = 100)
# Co IntervalMs zapisuje zużycie CPU (ms) każdego wątku procesu w tym przedziale; wypisuje wątki z > 3 ms.
$inv = [Globalization.CultureInfo]::InvariantCulture
$p = Get-Process -Id $ProcId
$prev = @{}
foreach ($t in $p.Threads) { try { $prev[$t.Id] = $t.TotalProcessorTime.TotalMilliseconds } catch {} }
$end = (Get-Date).AddSeconds($Seconds)
while ((Get-Date) -lt $end) {
	Start-Sleep -Milliseconds $IntervalMs
	try { $p.Refresh() } catch { break }
	if ($p.HasExited) { break }
	$now = ([DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds() / 1000.0).ToString("F3", $inv)
	$parts = @()
	foreach ($t in $p.Threads) {
		try {
			$ms = $t.TotalProcessorTime.TotalMilliseconds
			$d = $ms - ($(if ($prev.ContainsKey($t.Id)) { $prev[$t.Id] } else { $ms }))
			$prev[$t.Id] = $ms
			$st = "$($t.ThreadState)"
			if ($st -eq "Wait") { $st = "W-$($t.WaitReason)" }
			if ($d -gt 3) { $parts += ("{0}:{1:F0}:{2}" -f $t.Id, $d, $st) }
		} catch {}
	}
	"$now " + ($parts -join " ")
}
