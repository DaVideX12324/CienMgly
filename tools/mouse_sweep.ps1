# Przesuwa kursor sinusoidą po oknie 1280x720 ustawionym na (100,100): 8 s spokoju, potem 12 s ruchu (~250 zdarzeń/s).
# Użycie: uruchomić równolegle z Godotem (tests/repro_mouse_stall.gd). Nie ruszać wtedy myszą.
Add-Type @"
using System.Runtime.InteropServices;
public class MouseSweep { [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y); }
"@
Start-Sleep -Seconds 8
$end = (Get-Date).AddSeconds(12); $i = 0
while ((Get-Date) -lt $end) {
	$x = 300 + 800 * (0.5 + 0.5 * [math]::Sin($i / 15))
	$y = 300 + 400 * (0.5 + 0.5 * [math]::Sin($i / 9))
	[MouseSweep]::SetCursorPos([int]$x, [int]$y) | Out-Null
	Start-Sleep -Milliseconds 4
	$i++
}
