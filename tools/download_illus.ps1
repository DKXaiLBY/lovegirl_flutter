# ============================================================
# LoveGirl illustration batch download script (54 images)
# Usage (run in project root D:\Projects\Personal\lovegirl):
#   powershell -ExecutionPolicy Bypass -File tools\download_illus.ps1
# Downloads originals, converts to 1024x1024 PNG, saves to
# assets\images\illus_gen\, verifies each file is non-empty.
# NOTE: ASCII-only on purpose (PS 5.1 ANSI codepage safety).
# ============================================================

$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Add-Type -AssemblyName System.Drawing

$dir = "D:\Projects\Personal\lovegirl\assets\images\illus_gen"
New-Item -ItemType Directory -Path $dir -Force | Out-Null
$tmpDir = Join-Path $env:TEMP "illus_dl"
New-Item -ItemType Directory -Path $tmpDir -Force | Out-Null

$files = @(
    @("https://aka.doubaocdn.com/s/9gU3nI6LEV", "illus_type_love_1.png"),
    @("https://aka.doubaocdn.com/s/i0tsxbUPsI", "illus_type_love_2.png"),
    @("https://aka.doubaocdn.com/s/3TnsxgMmXZ", "illus_type_birthday_1.png"),
    @("https://aka.doubaocdn.com/s/6vvqxVeiht", "illus_type_birthday_2.png"),
    @("https://aka.doubaocdn.com/s/NpsTUpOhXm", "illus_type_first_1.png"),
    @("https://aka.doubaocdn.com/s/IkBVRV8VyE", "illus_type_first_2.png"),
    @("https://aka.doubaocdn.com/s/gXzUk19evZ", "illus_type_custom_1.png"),
    @("https://aka.doubaocdn.com/s/X12VTcCAs5", "illus_type_custom_2.png"),
    @("https://aka.doubaocdn.com/s/uZ9T5wMSLv", "illus_anni_sleep_1.png"),
    @("https://aka.doubaocdn.com/s/1d2UvoH0fU", "illus_anni_sleep_2.png"),
    @("https://aka.doubaocdn.com/s/bcRya0E7MC", "illus_anni_house_1.png"),
    @("https://aka.doubaocdn.com/s/CS7TkmTuIY", "illus_anni_house_2.png"),
    @("https://aka.doubaocdn.com/s/26veizYEkS", "illus_anni_cake_1.png"),
    @("https://aka.doubaocdn.com/s/Rii1bIBizQ", "illus_anni_cake_2.png"),
    @("https://aka.doubaocdn.com/s/NJjCp8RyYS", "illus_anni_couple_1.png"),
    @("https://aka.doubaocdn.com/s/cdWDpIB6hO", "illus_anni_couple_2.png"),
    @("https://aka.doubaocdn.com/s/wY0O3vI8ex", "illus_anni_ring_1.png"),
    @("https://aka.doubaocdn.com/s/UvkCbD1zUB", "illus_anni_ring_2.png"),
    @("https://aka.doubaocdn.com/s/OlJ0e2CpnE", "illus_anni_letter_1.png"),
    @("https://aka.doubaocdn.com/s/GU3XWozzMF", "illus_anni_letter_2.png"),
    @("https://aka.doubaocdn.com/s/EqZCWCLYMC", "illus_tape_washi_1.png"),
    @("https://aka.doubaocdn.com/s/S9O3uu0JGp", "illus_tape_washi_2.png"),
    @("https://aka.doubaocdn.com/s/ATj69psNxj", "illus_tape_stripe_1.png"),
    @("https://aka.doubaocdn.com/s/7TPbVl5Azg", "illus_tape_stripe_2.png"),
    @("https://aka.doubaocdn.com/s/gLy943fQzR", "illus_sticker_heart_1.png"),
    @("https://aka.doubaocdn.com/s/3Ub8R7ttTG", "illus_sticker_heart_2.png"),
    @("https://aka.doubaocdn.com/s/EoquBQeOWU", "illus_sticker_star_1.png"),
    @("https://aka.doubaocdn.com/s/dUEGVUa2MQ", "illus_sticker_star_2.png"),
    @("https://aka.doubaocdn.com/s/kyABnbDbcM", "illus_sticker_cloud_1.png"),
    @("https://aka.doubaocdn.com/s/dhy8nkMHEu", "illus_sticker_cloud_2.png"),
    @("https://aka.doubaocdn.com/s/QPclrxCEHt", "illus_sticker_flower_1.png"),
    @("https://aka.doubaocdn.com/s/K8LdoVp9Vt", "illus_sticker_flower_2.png"),
    @("https://aka.doubaocdn.com/s/s6CoXs5qyj", "illus_sticker_smile_1.png"),
    @("https://aka.doubaocdn.com/s/FChxKVGX58", "illus_sticker_smile_2.png"),
    @("https://aka.doubaocdn.com/s/WzoPKovUjM", "illus_empty_photo_1.png"),
    @("https://aka.doubaocdn.com/s/M1Ur6BJPaB", "illus_empty_photo_2.png"),
    @("https://aka.doubaocdn.com/s/LO7KyJFq4o", "illus_empty_travel_1.png"),
    @("https://aka.doubaocdn.com/s/Vw4au88LHS", "illus_empty_travel_2.png"),
    @("https://aka.doubaocdn.com/s/N49a43b1UW", "illus_empty_ticket_1.png"),
    @("https://aka.doubaocdn.com/s/eURTjN0x4Z", "illus_empty_ticket_2.png"),
    @("https://aka.doubaocdn.com/s/Ly5MteOzlJ", "illus_empty_anniversary_1.png"),
    @("https://aka.doubaocdn.com/s/L5s0oMA3az", "illus_empty_anniversary_2.png"),
    @("https://aka.doubaocdn.com/s/zVucFdCnQR", "illus_empty_voucher_1.png"),
    @("https://aka.doubaocdn.com/s/mrj7f5ZkV6", "illus_empty_voucher_2.png"),
    @("https://aka.doubaocdn.com/s/BzcHjLvu29", "illus_empty_letter_1.png"),
    @("https://aka.doubaocdn.com/s/sOZVeC6svQ", "illus_empty_letter_2.png"),
    @("https://aka.doubaocdn.com/s/hpRuE0cwV8", "illus_weather_sunny_1.png"),
    @("https://aka.doubaocdn.com/s/0lJ7vYxPqS", "illus_weather_sunny_2.png"),
    @("https://aka.doubaocdn.com/s/gsgciTOmG3", "illus_weather_cloudy_1.png"),
    @("https://aka.doubaocdn.com/s/oxqKqbXo3v", "illus_weather_cloudy_2.png"),
    @("https://aka.doubaocdn.com/s/VNlOFilZFe", "illus_weather_rainy_1.png"),
    @("https://aka.doubaocdn.com/s/PJvSPCegaG", "illus_weather_rainy_2.png"),
    @("https://aka.doubaocdn.com/s/6xDatwRVUt", "illus_weather_snow_1.png"),
    @("https://aka.doubaocdn.com/s/Hbs8slOn9O", "illus_weather_snow_2.png"),
    @("https://aka.doubaocdn.com/s/TnV4mvVhVs", "illus_ui_boot_1.png"),
    @("https://aka.doubaocdn.com/s/0wegDeZYjE", "illus_ui_boot_2.png"),
    @("https://aka.doubaocdn.com/s/AChmgQ6J23", "illus_ui_couple_1.png"),
    @("https://aka.doubaocdn.com/s/AQvTuL57xq", "illus_ui_couple_2.png"),
    @("https://aka.doubaocdn.com/s/ynHxJ3jfTq", "illus_ui_kitchen_1.png"),
    @("https://aka.doubaocdn.com/s/zhFqe4qx7C", "illus_ui_kitchen_2.png"),
    @("https://aka.doubaocdn.com/s/8QDG59aPIg", "illus_ui_timeline_1.png"),
    @("https://aka.doubaocdn.com/s/IVZyFNFZx5", "illus_ui_timeline_2.png"),
    @("https://aka.doubaocdn.com/s/JYEoRqcCZ9", "illus_ui_report_1.png"),
    @("https://aka.doubaocdn.com/s/4c1SVFqiLN", "illus_ui_report_2.png"),
    @("https://aka.doubaocdn.com/s/dgSdGN2rUU", "illus_ui_lock_1.png"),
    @("https://aka.doubaocdn.com/s/FUUPcvKI5J", "illus_ui_lock_2.png")
)

$ok = 0; $fail = 0; $conv = 0
foreach ($f in $files) {
    $url = $f[0]; $name = $f[1]
    $tmp = Join-Path $tmpDir $name
    $out = Join-Path $dir $name
    try {
        Write-Host ("Downloading {0} ..." -f $name)
        Invoke-WebRequest -Uri $url -OutFile $tmp -UseBasicParsing -TimeoutSec 60 -MaximumRedirection 10
        $bytes = [System.IO.File]::ReadAllBytes($tmp)
        if ($bytes.Length -lt 8) { throw ("downloaded file too small: {0} bytes" -f $bytes.Length) }
        $isPng = ($bytes[0] -eq 0x89 -and $bytes[1] -eq 0x50 -and $bytes[2] -eq 0x4E -and $bytes[3] -eq 0x47)
        $isJpg = ($bytes[0] -eq 0xFF -and $bytes[1] -eq 0xD8)
        $converted = $false
        if ($isPng -or $isJpg) {
            $img = [System.Drawing.Image]::FromFile($tmp)
            try {
                if ($img.Width -ne 1024 -or $img.Height -ne 1024 -or (-not $isPng)) {
                    $bmp = New-Object System.Drawing.Bitmap 1024, 1024
                    $g = [System.Drawing.Graphics]::FromImage($bmp)
                    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
                    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
                    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
                    $g.Clear([System.Drawing.Color]::White)
                    $g.DrawImage($img, 0, 0, 1024, 1024)
                    $g.Dispose()
                    $bmp.Save($out, [System.Drawing.Imaging.ImageFormat]::Png)
                    $bmp.Dispose()
                    $converted = $true
                } else {
                    [System.IO.File]::Copy($tmp, $out, $true)
                }
            } finally { $img.Dispose() }
        } else {
            [System.IO.File]::Copy($tmp, $out, $true)
            Write-Host ("  WARN {0}: source is not PNG/JPEG, saved as-is" -f $name)
        }
        $sz = (Get-Item $out).Length
        if ($sz -gt 0) { $ok++ } else { throw "output file is empty" }
        if ($converted) { $conv++; Write-Host ("  OK  {0}  {1} bytes (converted to 1024x1024 PNG)" -f $name, $sz) }
        else { Write-Host ("  OK  {0}  {1} bytes" -f $name, $sz) }
        Remove-Item $tmp -ErrorAction SilentlyContinue
    } catch {
        Write-Host ("  FAIL {0} : {1}" -f $name, $_.Exception.Message)
        $fail++
    }
}

Write-Host ""
Write-Host ("=== Done: {0} OK / {1} failed / {2} converted to 1024x1024 PNG ===" -f $ok, $fail, $conv)
if ($fail -gt 0) { Write-Host "Some files failed: check network and re-run this script." }
Write-Host ("PNG files in {0} :" -f $dir)
Get-ChildItem $dir -Filter "*.png" | Sort-Object Name | ForEach-Object {
    Write-Host ("  {0}  {1} bytes" -f $_.Name, $_.Length)
}
