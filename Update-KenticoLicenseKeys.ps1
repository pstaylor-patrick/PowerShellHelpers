Install-Module -Name SqlServer -AllowClobber

$KenticoDirectory = Get-Item (Read-Host "Please provide the local path to the Kentico solution directory, (e.g., D:\tfs\ATNWorkingProject\Kentico11\ATNKv*_Production)") -Verbose -ErrorAction Stop

if(!$KenticoDirectory.PSIsContainer) {
    Write-Error "'$($KenticoDirectory.FullName)' IS NOT A DIRECTORY!"
}

$WebConfigFile = Get-Item "$($KenticoDirectory)\CMS\web.config" -Verbose -ErrorAction Stop
[xml]$WebConfigXml = Get-Content $WebConfigFile.FullName
$CmsConnectionStringNode = $WebConfigXml.SelectSingleNode('/configuration/connectionStrings/add[@name="CMSConnectionString"]')
$CmsConnectionStringValue = $CmsConnectionStringNode.connectionString
$LicenseKeyValues = Invoke-Sqlcmd -ConnectionString $CmsConnectionStringValue -Query "SELECT * FROM CMS_LicenseKey"
$KenticoVersion = (Invoke-Sqlcmd -ConnectionString $CmsConnectionStringValue -Query "SELECT KeyValue FROM CMS_SettingsKey WHERE KeyName = 'CMSDBVersion'").KeyValue

$ResultsCount = 1
$SingletonExists = $true
if($LicenseKeyValues.length -gt 0) {
    $SingletonExists = $false
    $ResultsCount = $LicenseKeyValues.length
}

for($i = 0; $i -lt $ResultsCount; $i++) {
    $LicenseKeyDataRow = $LicenseKeyValues[$i]

    if($SingletonExists) {
        $LicenseKeyDataRow = $LicenseKeyValues
    }

    $LicenseKeyID = $LicenseKeyDataRow.LicenseKeyID
    $LicenseDomain = $LicenseKeyDataRow.LicenseDomain
    $LicenseKey = $LicenseKeyDataRow.LicenseKey
    $LicenseEdition = $LicenseKeyDataRow.LicenseEdition
    $LicenseExpiration = $LicenseKeyDataRow.LicenseExpiration
    $LicenseServers = $LicenseKeyDataRow.LicenseServers

    if($LicenseEdition -eq 'U') {
        $LicenseEdition = 'V'
    }

    $a = new-object -comobject wscript.shell 
    $intAnswer = $a.popup("Do you want to update the Kentico v$($KenticoVersion) license key for the domain '$($LicenseDomain)'?", ` 
    0,"Update License",4) 
    If ($intAnswer -ne 6) {
        continue
    }

    $NewLicenseKeyFile = Get-Item (Read-Host "Please provide the local path to the Kentico v$($KenticoVersion) license for the domain '$($LicenseDomain)', (e.g., C:\license_[domain]_v11.txt") -Verbose -ErrorAction Stop
    Invoke-Sqlcmd -ConnectionString $CmsConnectionStringValue -Query "UPDATE CMS_LicenseKey SET LicenseKey = '$(Get-Content $NewLicenseKeyFile.FullName -Raw -Verbose -ErrorAction Stop)', LicenseEdition = 'V' WHERE LicenseDomain = '$($LicenseDomain)'"
    # Invoke-Sqlcmd -ConnectionString $CmsConnectionStringValue -Query "DELETE FROM CMS_LicenseKey WHERE LicenseDomain = '$($LicenseDomain)'"
    # Invoke-Sqlcmd -ConnectionString $CmsConnectionStringValue -Query "INSERT INTO CMS_LicenseKey (LicenseDomain, LicenseKey, LicenseEdition, LicenseExpiration, LicenseServers) VALUES ('$($LicenseDomain)', '$(Get-Content $NewLicenseKeyFile.FullName -Raw -Verbose -ErrorAction Stop)', '$($LicenseEdition)', '$($LicenseExpiration)', '$($LicenseServers)')"
}