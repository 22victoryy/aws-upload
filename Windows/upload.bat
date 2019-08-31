@echo off

::
:: S3 credentials
::
set AWS_ID= "Insert your AWS Key"
set AWS_KEY= "Insert your AWS Secret Key"

::
:: Upload...
::
echo Uploading to AWS...

:: Compress
powershell -File ".\aws-upload.ps1" -do_compress -bucketname "Insert your bucket name" -id %AWS_ID% -key %AWS_KEY% -dirname "EXAMPLE: _*/*.*"

:: Do not compress
powershell -File ".\aws-upload.ps1" -bucket "Insert your bucket name" -id %AWS_ID% -key %AWS_KEY% -dirname "EXAMPLE: _*/*.*"

echo Done.
exit /b
