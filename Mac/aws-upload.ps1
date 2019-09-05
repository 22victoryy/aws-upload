# Prototype script to upload data to Amazon S3 Bucket (MAC OS X)
# Please Install Powershell to use.
# .NET ver. 4.5 + required.
# This is a test

# Param(
#   [Parameter(Mandatory=$true)][string]$bucket,
#   [Parameter(Mandatory=$true)][string]$id,
#   [Parameter(Mandatory=$true)][string]$key,
#   [switch]$do_compress,
#   [string]$type,
#   [string]$dirname,
#   [string]$prefix
# )

$do_compress = "Change this value into a boolean. T for compress, F for do not compress"
$bucketname = "Your AWS bucket"
$aws_id = "Your AWS KEY"
$aws_key = "Your AWS SECRETKEY"
$type = ""
$dirname = "directory filter of files to upload. EXAMPLE: _*/*.*"
$prefix = "your prefix"

function Get-MimeType
{
  Param([parameter(Mandatory=$true, ValueFromPipeline=$true)][ValidateNotNullorEmpty()][System.IO.FileInfo]$CheckFile) 
  begin
  {
    Add-Type -AssemblyName "System.Web"
    [System.IO.FileInfo]$check_file = $CheckFile
    [sting]$mime_type = $null
  }
  process {
    if ($check_file.Exists)
    {
      $mime_type = [System.Web.MimeMapping]::GetMimeMapping($check_file.FullName)  
    }
    else
    {
      $mime_type = "false"
    }
  }
  end { return $mime_type }
}

function GzipCompress
{
  param(
  [String]$inFile = $(throw "Gzip-File: No filename specified"),
  [String]$outFile = $($inFile + ".gz"),
  [switch]$delete
  )

  trap
  {
    Write-Host "Received an exception: $_.  Exiting."
    break
  }

  if (! (Test-Path $inFile))
  {
    "Input file $inFile does not exist."
    exit 1
  }

  $input = New-Object System.IO.FileStream $inFile, `
  ([IO.FileMode]::Open), ([IO.FileAccess]::Read), ([IO.FileShare]::Read)

  $buffer = New-Object byte[]($input.Length)
  $byteCount = $input.Read($buffer, 0, $input.Length)

  if ($byteCount -ne $input.Length)
  {
    $input.Close()
    Write-Host "Failure reading $inFile."
    exit 2
  }

  $input.Close()
  $output = New-Object System.IO.FileStream $outFile, ([IO.FileMode]::Create), `
  ([IO.FileAccess]::Write), ([IO.FileShare]::None)
  $gzipStream = New-Object System.IO.Compression.GzipStream $output, `
  ([IO.Compression.CompressionMode]::Compress)
  $gzipStream.Write($buffer, 0, $buffer.Length)
  $gzipStream.Close()
  $output.Close()

  if ($delete)
  {
    Remove-Item $inFile
  }
  # this was retrieved from https://blog.wannemacher.us/posts/p225/ and edited slightly.
}

if ($prefix) {if ($prefix[0] -ne '/') {$prefix += '/'}}

$log_dir = 'logs/'
if(!(Test-Path -Path $log_dir )) { New-Item -ItemType directory -Path $log_dir }

if ($dirname[-1] -eq '/') {$dirname += '*'}

$files = @()
$files += Resolve-Path -Relative $dirname

Set-AWSCredential -AccessKey $aws_id -SecretKey $aws_key

$logfilepath = $log_dir + 'log_' + $date + '.txt'
$logcontent = '[INFO] Uploading ' + $files + '`n'
Add-Content -Path $logfilepath -Value $logcontent
for ($i = 0; $i -lt $files.length; $i++)
{
  $FSfile = Get-Item -Path $files[$i]
  $type = $(Get-MimeType -CheckFile $FSfile.Extension)
  try
  {
    $keyPrefix = $prefix + $FSfile.name
    $dest = Get-S3Object -BucketName $bucketname -AccessKey $aws_id -SecretKey $aws_key -Region 'us-east-1' -KeyPrefix $keyPrefix
    if ($dest.LastModified -gt $FSfile.LastWriteTime)
    {
      continue
    }
  }
  finally
  {
    $dest = $null
  }
  # If desired file is compressed then upload.
  if ($do_compress)
  {
    $compressed = $files[$i] + '.gz'
    GzipCompress $files[$i] $compressed
    $payload = Get-ChildItem -path $compressed
    $header = @{'Content-Encoding' = 'gzip'}
    $key = $prefix + $FSfile.Name
    Write-S3Object -bucketname $bucketname -Key $key -File $payload -Region 'us-east-1' -HeaderCollection $header -CannedACLName public-read -ContentType $type
    Remove-Item -Path $compressed
  }
  # Otherwise, regular upload
  else
  {
    $payload = $files[$i]
    $key = $prefix + $FSfile.Name
    Write-S3Object -bucketname $bucketname -Key $key -File $payload -Region 'us-east-1' -CannedACLName public-read -ContentType $type
  }
}









