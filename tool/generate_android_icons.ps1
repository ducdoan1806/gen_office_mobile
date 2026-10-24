param(
    [string]$IconPath = (Join-Path $PSScriptRoot '../assets/branding/app_icon_1024.png')
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$projectRoot = Split-Path $PSScriptRoot -Parent
$res = Join-Path $projectRoot 'android/app/src/main/res'
$source = [System.Drawing.Image]::FromFile((Resolve-Path -LiteralPath $IconPath).Path)

# Render at 4x then downsample so the transparent rounded edge stays smooth.
function Write-Icon([string]$Destination, [int]$Canvas, [int]$Logo, [bool]$Rounded) {
    $scale = 4
    $bitmap = [System.Drawing.Bitmap]::new($Canvas*$scale, $Canvas*$scale)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $path = [System.Drawing.Drawing2D.GraphicsPath]::new()
    $attributes = [System.Drawing.Imaging.ImageAttributes]::new()
    try {
        $graphics.Clear([System.Drawing.Color]::Transparent)
        $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $attributes.SetWrapMode([System.Drawing.Drawing2D.WrapMode]::TileFlipXY)
        $edge = $Logo*$scale
        $offset = ($Canvas*$scale-$edge)/2
        if ($Rounded) {
            $diameter = $edge/2 # 25% corner radius
            $path.AddArc($offset,$offset,$diameter,$diameter,180,90)
            $path.AddArc($offset+$edge-$diameter,$offset,$diameter,$diameter,270,90)
            $path.AddArc($offset+$edge-$diameter,$offset+$edge-$diameter,$diameter,$diameter,0,90)
            $path.AddArc($offset,$offset+$edge-$diameter,$diameter,$diameter,90,90)
            $path.CloseFigure()
            $graphics.SetClip($path)
        }
        $graphics.DrawImage($source,[System.Drawing.Rectangle]::new($offset,$offset,$edge,$edge),0,0,$source.Width,$source.Height,[System.Drawing.GraphicsUnit]::Pixel,$attributes)
        $small = [System.Drawing.Bitmap]::new($Canvas,$Canvas)
        $output = [System.Drawing.Graphics]::FromImage($small)
        try {
            $output.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
            $output.DrawImage($bitmap,0,0,$Canvas,$Canvas)
            [void][System.IO.Directory]::CreateDirectory((Split-Path $Destination -Parent))
            $small.Save($Destination,[System.Drawing.Imaging.ImageFormat]::Png)
        } finally { $output.Dispose(); $small.Dispose() }
    } finally { $attributes.Dispose(); $path.Dispose(); $graphics.Dispose(); $bitmap.Dispose() }
}
try {
    if ($source.Width -ne $source.Height) { throw 'The launcher icon must be square.' }
    $densities = @{ 'mdpi'=1; 'hdpi'=1.5; 'xhdpi'=2; 'xxhdpi'=3; 'xxxhdpi'=4 }
    foreach ($density in $densities.Keys) {
        $factor = $densities[$density]
        Write-Icon "$res/mipmap-$density/ic_launcher.png" (48*$factor) (48*$factor) $true
        # Keep the complete rounded logo inside the 66dp safe circle on a 108dp layer.
        Write-Icon "$res/drawable-$density/ic_launcher_foreground.png" (108*$factor) (54*$factor) $true
        # 128dp rounded artwork fits entirely in Android 12's 192dp safe circle.
        Write-Icon "$res/drawable-$density/splash_icon.png" (288*$factor) (128*$factor) $true
        Write-Icon "$res/drawable-$density/splash_logo.png" (96*$factor) (96*$factor) $true
    }
} finally { $source.Dispose() }

# Shared wordmark for the platform splash branding slot and the legacy splash.
$bitmap = [System.Drawing.Bitmap]::new(800,320)
$graphics = [System.Drawing.Graphics]::FromImage($bitmap)
$font = [System.Drawing.Font]::new('Segoe UI',64,[System.Drawing.FontStyle]::Regular,[System.Drawing.GraphicsUnit]::Pixel)
$brush = [System.Drawing.SolidBrush]::new([System.Drawing.ColorTranslator]::FromHtml('#171D1B'))
$format = [System.Drawing.StringFormat]::new()
try {
    $graphics.Clear([System.Drawing.Color]::Transparent)
    $graphics.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
    $format.Alignment = [System.Drawing.StringAlignment]::Center
    $format.LineAlignment = [System.Drawing.StringAlignment]::Center
    $graphics.DrawString('VPIC1 Office',$font,$brush,[System.Drawing.RectangleF]::new(0,0,800,320),$format)
    $destination = "$res/drawable-xxxhdpi/splash_branding.png"
    $bitmap.Save($destination,[System.Drawing.Imaging.ImageFormat]::Png)
} finally { $format.Dispose(); $brush.Dispose(); $font.Dispose(); $graphics.Dispose(); $bitmap.Dispose() }
