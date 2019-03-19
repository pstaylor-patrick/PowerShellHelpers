#region Establish a working directory

$timestamp = Get-Date -Format o | ForEach-Object {$_ -replace ":", "."}
$WorkingDirectory = New-Item "$env:USERPROFILE\Desktop\RepairKenticoMediaLibraryReferences-$timestamp" -ItemType Directory -Force -Verbose -ErrorAction Stop
Remove-Item "$($WorkingDirectory.FullName)\**" -Recurse -Force

#endregion

#region Get CMSConnectionString

function Get-CMSConnectionString () {
    [OutputType([string])]
    Param(
        [Parameter(Mandatory = $true)]
        [String]
        $KenticoDirectoryPath
    )

    $Directory_Kentico = Get-Item $KenticoDirectoryPath

    if(!$Directory_Kentico.PSIsContainer) {
        Write-Error "'$($Directory_Kentico.FullName)' IS NOT A DIRECTORY!"
        return ''
    }
    
    $File_WebConfig = Get-Item "$($Directory_Kentico)\CMS\web.config" -Verbose -ErrorAction Stop
    [xml]$XML_WebConfig = Get-Content $File_WebConfig.FullName
    $CMSConnectionString_Node = $XML_WebConfig.SelectSingleNode('/configuration/connectionStrings/add[@name="CMSConnectionString"]')
    $CMSConnectionString = $CMSConnectionString_Node.connectionString
    
    return $CMSConnectionString
}

$CMSConnectionString = Get-CMSConnectionString -KenticoDirectoryPath 'D:\git\BitWizardsWebsite_v11' # (Read-Host "Please provide the absolute path to your local Kentico solution directory, (e.g., C:\git\KenticoDirectory)")

#endregion

#region Scrape the database

function Get-KenticoMediaLibraryReferences () {
    [OutputType([System.Data.DataSet])]
    param(
        [Parameter(Mandatory = $true)]
        [String]
        $ConnectionString,
        
        [Parameter(Mandatory = $true)]
        [String[]]
        $Tables
    )

    $Columns = @('TABLE_NAME', 'COLUMN_NAME', 'PRIMARY_KEY_NAME', 'PRIMARY_KEY_VALUE', 'ROW_VALUE')
    $TableName = 'BW_KenticoMediaLibraryReferences'
    $Query = "SELECT $($Columns -join ',') FROM $TableName WHERE TABLE_NAME IN ('$($Tables -join ''',''')')"
    $Results = Invoke-Sqlcmd -ConnectionString $ConnectionString -Query $Query -MaxCharLength ([int]::MaxValue)

    return $Results
}

$Tables = @('BW_casestudy', 'BW_clients', 'BW_EmailTeaserImage', 'BW_employee', 'bw_fourcolumns', 'BW_LandingPage', 'BW_offer', 'BW_PageSlide', 'BW_PixelBG', 'bw_twocolumns', 'bw_webinar', 'CMS_CssStyleSheet', 'CMS_Document', 'CMS_ObjectVersionHistory', 'CMS_PageTemplate', 'CMS_VersionHistory', 'CONTENT_BlogPost', 'CONTENT_Event', 'CONTENT_News', 'CONTENT_Office', 'Newsletter_NewsletterIssue')
$KenticoMediaLibraryReferences = Get-KenticoMediaLibraryReferences -ConnectionString $CMSConnectionString -Tables $Tables

# Backup the results
Write-Host -ForegroundColor Cyan 'Backup the results'
$KenticoMediaLibraryReferences | Out-File "$($WorkingDirectory.FullName)\01-results.bak.txt"

#endregion

#region Update the local copy of the data

Write-Host -ForegroundColor Cyan 'Update the local copy of the data'
$Prefixes = @('/~', '~', '"', ')', '(', '''', 'http://bwwe.blob.core.windows.net/bwwemedia-dev', 'https://bwwe.blob.core.windows.net/bwwemedia-dev', 'http://bwwe.blob.core.windows.net/bwwemedia-staging', 'https://bwwe.blob.core.windows.net/bwwemedia-staging', 'http://bitwizardseast.blob.core.windows.net/cmsstorage', 'https://bitwizardseast.blob.core.windows.net/cmsstorage', 'http://mktg.blob.core.windows.net/cmsstorage', 'https://mktg.blob.core.windows.net/cmsstorage', 'http://bwwe.blob.core.windows.net/bwwemedia', 'https://bwwe.blob.core.windows.net/bwwemedia', 'http://dev.bitwizards.com', 'https://dev.bitwizards.com', 'http://mktg.bitwizards.com', 'https://mktg.bitwizards.com', 'http://bitwizards.com', 'https://bitwizards.com', '')
$NewPrefix = 'https://bwwe.blob.core.windows.net/bwwemedia'
$CoreSearchTerm = '/bitwizards/media'
# $SearchSuffix = '(\w|/|-|\.|\?|=|_|%|\d|\s){1,}'
$KenticoMediaLibraryReferences | ForEach-Object {
    # Write-Host $_.TABLE_NAME
    # Write-Host $_.COLUMN_NAME
    # Write-Host $_.PRIMARY_KEY_NAME
    # Write-Host $_.PRIMARY_KEY_VALUE
    # Write-Host $_.ROW_VALUE

    for($i=0;$i -lt $Prefixes.Count;$i++) {
        $OldPrefix = $Prefixes[$i]
        $SearchTerm = "$OldPrefix$CoreSearchTerm$SearchSuffix"
        $RowValue = $_.ROW_VALUE

        Add-Content "$($WorkingDirectory.FullName)\02-rowvalues.bak.txt" -Value $RowValue

        Write-Host "----"
        Write-Host "$RowValue"
        Write-Host "$OldPrefix$CoreSearchTerm"
        Write-Host "$NewPrefix$CoreSearchTerm"
        Write-Host ($RowValue -ireplace [regex]::Escape("$OldPrefix$CoreSearchTerm"), "$NewPrefix$CoreSearchTerm")

        Write-Host "----"

        Add-Content "$($WorkingDirectory.FullName)\03-rowvalues.revised.txt" -Value ($RowValue -ireplace [regex]::Escape("$OldPrefix$CoreSearchTerm"), "$NewPrefix$CoreSearchTerm")
    }
}

#endregion