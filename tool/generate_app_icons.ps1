# Generates the Gear Tracker launcher icon, adaptive icon layers, and splash
# logo from the app palette. Run from the project root:
#   powershell -ExecutionPolicy Bypass -File tool\generate_app_icons.ps1
Add-Type -AssemblyName System.Drawing

$ErrorActionPreference = 'Stop'

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$Res = Join-Path $ProjectRoot 'android\app\src\main\res'
$IosIcons = Join-Path $ProjectRoot 'ios\Runner\Assets.xcassets\AppIcon.appiconset'

$Background = [System.Drawing.Color]::FromArgb(255, 6, 14, 32)
$Accent = [System.Drawing.Color]::FromArgb(255, 78, 218, 163)

function Get-SmoothStep([double]$t) {
    $t = [Math]::Max(0.0, [Math]::Min(1.0, $t))
    return $t * $t * (3 - 2 * $t)
}

# Builds the outline of a cog: teeth with flat tips, soft root transitions.
function New-GearPath(
    [double]$cx, [double]$cy, [double]$rOuter, [double]$rRoot, [int]$teeth, [int]$samples
) {
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $points = New-Object System.Collections.Generic.List[System.Drawing.PointF]
    $pitch = 2 * [Math]::PI / $teeth

    for ($i = 0; $i -lt $teeth; $i++) {
        $base = $i * $pitch
        for ($s = 0; $s -lt $samples; $s++) {
            $t = $s / $samples
            $angle = $base + $t * $pitch

            if ($t -lt 0.20 -or $t -gt 0.80) {
                $radius = $rRoot
            } elseif ($t -lt 0.32) {
                $radius = $rRoot + (($rOuter - $rRoot) * (Get-SmoothStep(($t - 0.20) / 0.12)))
            } elseif ($t -le 0.68) {
                $radius = $rOuter
            } else {
                $radius = $rOuter + (($rRoot - $rOuter) * (Get-SmoothStep(($t - 0.68) / 0.12)))
            }

            $points.Add((New-Object System.Drawing.PointF(
                [float]($cx + $radius * [Math]::Cos($angle)),
                [float]($cy + $radius * [Math]::Sin($angle))
            )))
        }
    }

    $path.AddPolygon($points.ToArray())
    return $path
}

# Renders the icon into a new bitmap at 4x for clean downscaling.
function New-IconBitmap([int]$size, [bool]$opaque, [double]$gearScale, [double]$cornerScale) {
    $supersample = 4
    $canvas = $size * $supersample
    $pixel = [System.Drawing.Imaging.PixelFormat]::Format32bppArgb

    $work = New-Object System.Drawing.Bitmap($canvas, $canvas, $pixel)
    $g = [System.Drawing.Graphics]::FromImage($work)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
    $g.Clear([System.Drawing.Color]::FromArgb(0, 0, 0, 0))

    if ($opaque) {
        $bounds = New-Object System.Drawing.RectangleF(0, 0, $canvas, $canvas)
        $background = New-Object System.Drawing.SolidBrush($Background)
        if ($cornerScale -gt 0) {
            $plate = New-Object System.Drawing.Drawing2D.GraphicsPath
            $d = $canvas * $cornerScale
            $plate.AddArc(0, 0, $d, $d, 180, 90)
            $plate.AddArc($canvas - $d, 0, $d, $d, 270, 90)
            $plate.AddArc($canvas - $d, $canvas - $d, $d, $d, 0, 90)
            $plate.AddArc(0, $canvas - $d, $d, $d, 90, 90)
            $plate.CloseFigure()
            $g.FillPath($background, $plate)
            $plate.Dispose()
        } else {
            $g.FillRectangle($background, $bounds)
        }
        $background.Dispose()
    }

    $center = $canvas / 2
    $rOuter = $canvas * 0.42 * $gearScale
    $rRoot = $rOuter * 0.80
    $rHole = $rOuter * 0.34
    $rHub = $rOuter * 0.17

    $gear = New-GearPath $center $center $rOuter $rRoot 9 14
    $accent = New-Object System.Drawing.SolidBrush($Accent)
    $g.FillPath($accent, $gear)
    $gear.Dispose()

    # Punch the centre and draw the hub so the cog reads at launcher size.
    $g.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
    $clear = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(0, 0, 0, 0))
    $g.FillEllipse($clear, ($center - $rHole), ($center - $rHole), ($rHole * 2), ($rHole * 2))
    $g.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceOver
    $g.FillEllipse($accent, ($center - $rHub), ($center - $rHub), ($rHub * 2), ($rHub * 2))
    $accent.Dispose()
    $clear.Dispose()

    $g.Dispose()

    $final = New-Object System.Drawing.Bitmap($size, $size, $pixel)
    $fg = [System.Drawing.Graphics]::FromImage($final)
    $fg.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $fg.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $fg.DrawImage($work, 0, 0, $size, $size)
    $fg.Dispose()
    $work.Dispose()

    return $final
}

function Save-Icon([System.Drawing.Bitmap]$bitmap, [string]$path) {
    $dir = Split-Path -Parent $path
    if (-not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    $bitmap.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    $bitmap.Dispose()
    Write-Host "  $($path.Replace($ProjectRoot + '\', ''))"
}

# Renders the flat gear used on the splash and Android 12+ system splash.
function New-LogoBitmap([int]$size) {
    return New-IconBitmap -size $size -opaque $false -gearScale 0.82 -cornerScale 0
}

Write-Host 'Master icon'
$master = New-IconBitmap -size 1024 -opaque $true -gearScale 1.0 -cornerScale 0
Save-Icon $master (Join-Path $ProjectRoot 'tool\icon_master.png')

Write-Host 'Android legacy launcher icon'
$legacy = @{ 'mdpi' = 48; 'hdpi' = 72; 'xhdpi' = 96; 'xxhdpi' = 144; 'xxxhdpi' = 192 }
foreach ($density in $legacy.Keys) {
    Save-Icon (New-IconBitmap -size $legacy[$density] -opaque $true -gearScale 1.0 -cornerScale 0.22) `
        (Join-Path $Res "mipmap-$density\ic_launcher.png")
    Save-Icon (New-IconBitmap -size $legacy[$density] -opaque $true -gearScale 0.84 -cornerScale 0.5) `
        (Join-Path $Res "mipmap-$density\ic_launcher_round.png")
}

Write-Host 'Android adaptive icon foreground'
$adaptive = @{ 'mdpi' = 108; 'hdpi' = 162; 'xhdpi' = 216; 'xxhdpi' = 324; 'xxxhdpi' = 432 }
foreach ($density in $adaptive.Keys) {
    Save-Icon (New-IconBitmap -size $adaptive[$density] -opaque $false -gearScale 0.62 -cornerScale 0) `
        (Join-Path $Res "mipmap-$density\ic_launcher_foreground.png")
}

Write-Host 'Android splash logo'
$splash = @{ 'mdpi' = 72; 'hdpi' = 108; 'xhdpi' = 144; 'xxhdpi' = 216; 'xxxhdpi' = 288 }
foreach ($density in $splash.Keys) {
    Save-Icon (New-LogoBitmap $splash[$density]) (Join-Path $Res "drawable-$density\launch_logo.png")
}

Write-Host 'iOS app icon'
if (Test-Path -LiteralPath $IosIcons) {
    $iosSizes = @(
        'Icon-App-20x20@1x.png', 'Icon-App-20x20@2x.png', 'Icon-App-20x20@3x.png',
        'Icon-App-29x29@1x.png', 'Icon-App-29x29@2x.png', 'Icon-App-29x29@3x.png',
        'Icon-App-40x40@1x.png', 'Icon-App-40x40@2x.png', 'Icon-App-40x40@3x.png',
        'Icon-App-60x60@2x.png', 'Icon-App-60x60@3x.png',
        'Icon-App-76x76@1x.png', 'Icon-App-76x76@2x.png',
        'Icon-App-83.5x83.5@2x.png', 'Icon-App-1024x1024@1x.png'
    )
    $iosPixels = @(20, 40, 60, 29, 58, 87, 40, 80, 120, 120, 180, 76, 152, 167, 1024)
    for ($i = 0; $i -lt $iosSizes.Count; $i++) {
        Save-Icon (New-IconBitmap -size $iosPixels[$i] -opaque $true -gearScale 1.0 -cornerScale 0) `
            (Join-Path $IosIcons $iosSizes[$i])
    }
}

Write-Host ''
Write-Host 'Icon generation complete.'