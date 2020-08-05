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

    [string] $ApplicationControlPlane = "sharefile.com",
    [string] $Endpoint = "https://secure.sf-api.com/sf/v3/",

    [string] $SourceDirectory,

    [Parameter(Mandatory=$true)]
    [string] $DestinationDirectory,

    [switch] $ShareParentFolderLink,

    [string[]] $Include,

    [string[]] $Exclude,

    [datetime] $ExpirationDate = [datetime]::MaxValue,

    $Files
)

$UtilsScript = Join-Path $PSScriptRoot ShareFile-Utils.ps1
. $UtilsScript

$ShareFileClient = Connect-ShareFileClient -ClientID $ClientID -ClientSecret $ClientSecret -Username $Username -Password $Password -Subdomain $Subdomain -ApplicationControlPlane $ApplicationControlPlane -Endpoint $Endpoint

$CopyArgs = @{
    '-ShareFileClient'=$ShareFileClient;
    '-SourceDirectory'=$SourceDirectory;
    '-DestinationDirectory'=$DestinationDirectory;
    '-ExpirationDate'=$ExpirationDate;
    '-Files'=$Files
}
if ($Include)
{
    $CopyArgs.Add('-Include', $Include)
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
