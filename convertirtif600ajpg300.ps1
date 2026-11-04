<#
Biblioteca Florentino Ameghino: Hecho con Claude.ai

USO DEL SCRIPT:
powershell -ExecutionPolicy Bypass -File .\convertirtif600ajpg300.ps1 "C:\ruta\a\la\carpeta"


.SYNOPSIS
    Convierte todos los archivos TIF/TIFF de una carpeta a JPG de 300 DPI.

.DESCRIPTION
    Por cada archivo TIF genera un JPG con el mismo nombre en la misma carpeta.
    Por defecto reduce los píxeles a la mitad (600 -> 300 DPI) para mantener
    el mismo tamaño físico de la imagen, y marca el JPG con 300 DPI.

.PARAMETER Ruta
    Ruta completa de la carpeta con los archivos TIF.

.PARAMETER DpiDestino
    DPI de salida. Por defecto 300.

.PARAMETER Calidad
    Calidad JPG de 1 a 100. Por defecto 90.

.PARAMETER SinRemuestrear
    Si se indica, NO cambia la cantidad de píxeles: solo cambia la etiqueta
    de DPI a 300 (la imagen quedaría del doble de tamaño físico).

.PARAMETER Sobrescribir
    Si se indica, reemplaza los JPG que ya existan. Por defecto se omiten.

.EXAMPLE
    .\convertirtif600ajpg300.ps1 "C:\Escaneos\Lote1"

.EXAMPLE
    .\convertirtif600ajpg300.ps1 "C:\Escaneos\Lote1" -Calidad 95 -Sobrescribir
#>

param(
    [Parameter(Position = 0)]
    [string]$Ruta,

    [int]$DpiDestino = 300,

    [ValidateRange(1, 100)]
    [int]$Calidad = 90,

    [switch]$SinRemuestrear,

    [switch]$Sobrescribir
)

if ([string]::IsNullOrWhiteSpace($Ruta)) {
    Write-Host ""
    Write-Host "//// USO DEL SCRIPT ////" -ForegroundColor Red
    Write-Host "	-Tienes que abrir PowerShell"
	Write-Host "	-Ejecutar la linea de comando:"
	Write-Host ""
    Write-Host 'powershell -ExecutionPolicy Bypass -File .\convertirtif600ajpg300.ps1 "C:\ruta\a\la\carpeta"'
    Write-Host ""
    Write-Host ""
#    Write-Host "Opciones (opcionales):"
#    Write-Host "  -DpiDestino 300     DPI de salida (por defecto 300)"
#    Write-Host "  -Calidad 90         Calidad JPG de 1 a 100 (por defecto 90)"
#    Write-Host "  -SinRemuestrear     Solo cambia la etiqueta de DPI, sin reducir los pixeles"
#    Write-Host "  -Sobrescribir       Reemplaza los JPG que ya existan"
    Write-Host ""
    exit 1
}

Add-Type -AssemblyName System.Drawing

if (-not (Test-Path -LiteralPath $Ruta -PathType Container)) {
    Write-Error "La carpeta no existe: $Ruta"
    exit 1
}

# Codificador JPEG con la calidad pedida
$codecJpeg = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() |
    Where-Object { $_.MimeType -eq 'image/jpeg' }
$parametros = New-Object System.Drawing.Imaging.EncoderParameters(1)
$parametros.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter(
    [System.Drawing.Imaging.Encoder]::Quality, [long]$Calidad)

$archivos = Get-ChildItem -LiteralPath $Ruta -File |
    Where-Object { $_.Extension -match '^\.tiff?$' }

if (-not $archivos) {
    Write-Warning "No se encontraron archivos TIF en: $Ruta"
    exit 0
}

$ok = 0; $omitidos = 0; $errores = 0

foreach ($archivo in $archivos) {
    $destino = Join-Path $archivo.DirectoryName ($archivo.BaseName + '.jpg')

    if ((Test-Path -LiteralPath $destino) -and -not $Sobrescribir) {
        Write-Host "Omitido (ya existe): $($archivo.BaseName).jpg" -ForegroundColor Yellow
        $omitidos++
        continue
    }

    $origen = $null; $bmp = $null; $g = $null
    try {
        $origen = [System.Drawing.Image]::FromFile($archivo.FullName)

        # DPI real del archivo (si no lo trae, se asume 600)
        $dpiOrigen = $origen.HorizontalResolution
        if ($dpiOrigen -le 0) { $dpiOrigen = 600 }

        if ($SinRemuestrear) {
            $nuevoAncho = $origen.Width
            $nuevoAlto  = $origen.Height
        }
        else {
            $factor     = $DpiDestino / $dpiOrigen
            $nuevoAncho = [int][Math]::Max(1, [Math]::Round($origen.Width  * $factor))
            $nuevoAlto  = [int][Math]::Max(1, [Math]::Round($origen.Height * $factor))
        }

        $bmp = New-Object System.Drawing.Bitmap($nuevoAncho, $nuevoAlto)
        $bmp.SetResolution($DpiDestino, $DpiDestino)

        $g = [System.Drawing.Graphics]::FromImage($bmp)
        $g.Clear([System.Drawing.Color]::White)   # fondo blanco (JPG no admite transparencia)
        $g.InterpolationMode  = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $g.SmoothingMode      = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
        $g.PixelOffsetMode    = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        $g.DrawImage($origen, 0, 0, $nuevoAncho, $nuevoAlto)

        $bmp.Save($destino, $codecJpeg, $parametros)

        Write-Host "OK: $($archivo.Name) -> $($archivo.BaseName).jpg ($nuevoAncho x $nuevoAlto px, $DpiDestino DPI)" -ForegroundColor Green
        $ok++
    }
    catch {
        Write-Host "ERROR en $($archivo.Name): $($_.Exception.Message)" -ForegroundColor Red
        $errores++
    }
    finally {
        if ($g)      { $g.Dispose() }
        if ($bmp)    { $bmp.Dispose() }
        if ($origen) { $origen.Dispose() }
    }
}

Write-Host ""
Write-Host "Terminado. Convertidos: $ok | Omitidos: $omitidos | Errores: $errores"
