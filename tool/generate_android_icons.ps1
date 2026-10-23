param(
    [string]$IconPath = (Join-Path $PSScriptRoot '../assets/branding/app_icon_1024.png')
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$projectRoot = Split-Path $PSScriptRoot -Parent
$source = [System.Drawing.Image]::FromFile((Resolve-Path -LiteralPath $IconPath).Path)
try {
    if ($source.Width -ne $source.Height) { throw 'The launcher icon must be square.' }
    $sizes = @{ 'mdpi'=48; 'hdpi'=72; 'xhdpi'=96; 'xxhdpi'=144; 'xxxhdpi'=192 }
    foreach ($density in $sizes.Keys) {
        $size = $sizes[$density]
        $destination = Join-Path $projectRoot "android/app/src/main/res/mipmap-$density/ic_launcher.png"
        $bitmap = [System.Drawing.Bitmap]::new($size, $size)
        $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
        $attributes = [System.Drawing.Imaging.ImageAttributes]::new()
        try {
            $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
            $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
            $attributes.SetWrapMode([System.Drawing.Drawing2D.WrapMode]::TileFlipXY)
            $graphics.DrawImage($source, [System.Drawing.Rectangle]::new(0,0,$size,$size), 0,0,$source.Width,$source.Height, [System.Drawing.GraphicsUnit]::Pixel, $attributes)
            $bitmap.Save($destination, [System.Drawing.Imaging.ImageFormat]::Png)
        } finally { $attributes.Dispose(); $graphics.Dispose(); $bitmap.Dispose() }
    }
} finally { $source.Dispose() }
