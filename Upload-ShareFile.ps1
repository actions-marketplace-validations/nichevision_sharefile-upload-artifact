
<#
    .SYNOPSIS
    Upload one or more file or directories to a destination on ShareFile.

    .PARAMETER Files
    A collection of files and/or directories to upload.

    Directories are uploaded as-is, preserving their name and entire structure to DestinationDirectory.

    Individual files are uploaded directly to DestinationDirectory, without preserving their parent
    directories.

    .PARAMETER Destination
    The directory name on ShareFile where files will be uploaded to.

    .PARAMETER Exclude
    A collection of strings used to exclude files. Supports typical powershell wildcards.

    .PARAMETER ShareParentFolderLink
    If specified, the Share link that is created will point directly to DestinationDirectory,
    instead of to the individually uploaded files. This means the directory structure will be
    displayed in the share.

    .PARAMETER ExpirationDate
    The expiration date of the created Share. The default of [datetime]::MaxValue means
    the Share does not expire.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory=$True)]
    [string] $ClientID,
    [Parameter(Mandatory=$True)]
    [string] $ClientSecret,
    [Parameter(Mandatory=$True)]
    [string] $Username,
    [Parameter(Mandatory=$True)]
    [string] $Password,
    [Parameter(Mandatory=$True)]
    [string] $Subdomain,

    [Parameter(Mandatory=$true)]
    $Files,
    [Parameter(Mandatory=$true)]
    [string] $DestinationDirectory,
    [string[]] $Exclude,

    [switch] $ShareParentFolderLink,

    [datetime] $ExpirationDate = [datetime]::MaxValue,

    [string] $ApplicationControlPlane = "sharefile.com",

    [string] $Endpoint = "https://secure.sf-api.com/sf/v3/"
)

$UtilsScript = Join-Path $PSScriptRoot ShareFile-Utils.ps1
. $UtilsScript

$ShareFileClient = Connect-ShareFileClient -ClientID $ClientID -ClientSecret $ClientSecret -Username $Username -Password $Password -Subdomain $Subdomain -ApplicationControlPlane $ApplicationControlPlane -Endpoint $Endpoint

$CopyArgs = @{
    '-ShareFileClient'=$ShareFileClient;
    '-DestinationDirectory'=$DestinationDirectory;
    '-ExpirationDate'=$ExpirationDate;
    '-Files'=$Files
}
if ($Exclude)
{
    $CopyArgs.Add('-Exclude', $Exclude)
}
if ($ShareParentFolderLink)
{
    $CopyArgs.Add('-ShareParentFolderLink', $ShareParentFolderLink)
}

Copy-ToShareFile @CopyArgs
