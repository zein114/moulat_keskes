# Run from the repository root after replacing assets/images/logo.png.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$root = Split-Path $PSScriptRoot -Parent
$source = [System.Drawing.Bitmap]::FromFile((Join-Path $root 'assets/images/logo.png'))
function New-IconPng([int]$size, [double]$fraction = 1.0) {
    $bitmap = New-Object System.Drawing.Bitmap $size, $size
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    try {
        $graphics.Clear($source.GetPixel(0, 0))
        $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        $scale = $size * $fraction / [Math]::Max($source.Width, $source.Height)
        $width = [int][Math]::Round($source.Width * $scale)
        $height = [int][Math]::Round($source.Height * $scale)
        $rect = New-Object System.Drawing.Rectangle ([int](($size - $width) / 2)), ([int](($size - $height) / 2)), $width, $height
        $graphics.DrawImage($source, $rect)
        $stream = New-Object System.IO.MemoryStream
        try {
            $bitmap.Save($stream, [System.Drawing.Imaging.ImageFormat]::Png)
            return ,$stream.ToArray()
        } finally { $stream.Dispose() }
    } finally { $graphics.Dispose(); $bitmap.Dispose() }
}
function Save-Icon([string]$path, [int]$size, [double]$fraction = 1.0) {
    [System.IO.File]::WriteAllBytes((Join-Path $root $path), (New-IconPng $size $fraction))
}
try {
    $densities = @{ mdpi = 48; hdpi = 72; xhdpi = 96; xxhdpi = 144; xxxhdpi = 192 }
    foreach ($density in $densities.Keys) {
        Save-Icon "android/app/src/main/res/mipmap-$density/ic_launcher.png" $densities[$density]
    }
    foreach ($platform in @('ios', 'macos')) {
        $directory = "$platform/Runner/Assets.xcassets/AppIcon.appiconset"
        $catalog = Get-Content (Join-Path $root "$directory/Contents.json") -Raw | ConvertFrom-Json
        foreach ($entry in $catalog.images) {
            $size = [double]::Parse($entry.size.Split('x')[0], [Globalization.CultureInfo]::InvariantCulture)
            $scale = [double]::Parse($entry.scale.TrimEnd('x'), [Globalization.CultureInfo]::InvariantCulture)
            Save-Icon "$directory/$($entry.filename)" ([int]($size * $scale))
        }
    }
    Save-Icon 'web/favicon.png' 32
    foreach ($size in @(192, 512)) {
        Save-Icon "web/icons/Icon-$size.png" $size
        # Fit the full artwork inside the central mask-safe circle.
        Save-Icon "web/icons/Icon-maskable-$size.png" $size 0.56
    }
    $sizes = @(16, 24, 32, 48, 64, 128, 256)
    $frames = @($sizes | ForEach-Object { ,(New-IconPng $_) })
    $file = [System.IO.File]::Create((Join-Path $root 'windows/runner/resources/app_icon.ico'))
    $writer = New-Object System.IO.BinaryWriter $file
    try {
        $writer.Write([uint16]0); $writer.Write([uint16]1); $writer.Write([uint16]$sizes.Count)
        $offset = 6 + 16 * $sizes.Count
        for ($i = 0; $i -lt $sizes.Count; $i++) {
            $dimension = if ($sizes[$i] -eq 256) { 0 } else { $sizes[$i] }
            $writer.Write([byte]$dimension); $writer.Write([byte]$dimension)
            $writer.Write([byte]0); $writer.Write([byte]0)
            $writer.Write([uint16]1); $writer.Write([uint16]32)
            $writer.Write([uint32]$frames[$i].Length); $writer.Write([uint32]$offset)
            $offset += $frames[$i].Length
        }
        foreach ($frame in $frames) { $writer.Write([byte[]]$frame) }
    } finally { $writer.Dispose() }
} finally { $source.Dispose() }
Write-Output 'Generated Android, iOS, macOS, Windows, and web icons.'
