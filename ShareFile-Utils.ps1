function Connect-ShareFileClient
{
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
        [string] $Endpoint = "https://secure.sf-api.com/sf/v3/"
    )
    Setup-ShareFile | Out-Null

    $sfClient = New-Object ShareFile.Api.Client.ShareFileClient $Endpoint
    $oauthService = New-Object ShareFile.Api.Client.Security.Authentication.OAuth2.OAuthService ($sfClient, $ClientID, $ClientSecret)

    $task = $oauthService.PasswordGrantAsync($Username, $Password, $Subdomain, $ApplicationControlPlane)
    $task.Wait()

    $oauthToken = $task.Result
    $sfClient.AddOAuthCredentials($oauthToken)
    $sfClient.BaseUri = $oauthToken.GetUri()
    $sfClient.Sessions.Login().Execute() | Out-Null
    return $sfClient
}

function Setup-ShareFile
{
    $DllPath = Join-Path $PSScriptRoot ".\lib\netstandard1.3\ShareFile.Api.Client.dll"
    Add-Type -Path $DllPath -ErrorAction Stop
}

function Copy-ToShareFile
{
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory=$true)]
        [ShareFile.Api.Client.ShareFileClient] $ShareFileClient,

        [string] $SourceDirectory,

        [Parameter(Mandatory=$true)]
        [string] $DestinationDirectory,

        [switch] $ShareParentFolderLink,

        [string[]] $Include,

        [string[]] $Exclude,

        [datetime] $ExpirationDate = [datetime]::MaxValue,

        $Files
    )
    Setup-ShareFile | Out-Null

    if ($null -eq $Files) 
    {
        $SourceDirectory = (Get-Item $SourceDirectory).FullName
        $Files = Get-ChildItem -Recurse $SourceDirectory -Exclude $Exclude -Include $Include -File
    }
    else
    {
        # If it's a list of strings, turn them into System.IO.FileInfos
        if ($Files[0].GetType() -eq [System.String])
        {
            $Files = Get-ChildItem $Files
        }
    }

    if (!$Files)
    {
        throw "No files were specified or source directory is empty."
    }

    $share = New-Object ShareFile.Api.Client.Models.Share
    $share.RequireLogin = $false
    $share.ShareType = [ShareFile.Api.Client.Models.ShareType]::Send
    $share.ExpirationDate = $ExpirationDate
    $share.Items = New-Object System.Collections.Generic.List[ShareFile.Api.Client.Models.Item]

    $Files | ForEach-Object {
        $FileToUpload = $_
        if ($SourceDirectory)
        {
            $SubPath = $FileToUpload.FullName.Replace($SourceDirectory, '')
        }
        else
        {
            $SubPath = $FileToUpload.FullName.Replace((Get-Location).Path, '')
        }
        $FullDstPath = Join-Path $DestinationDirectory $SubPath

        if ($pscmdlet.ShouldProcess("Upload $($_.FullName) to $($FullDstPath).", "", "")) {
            # Create required directories
            $tmp = $FullDstPath
            $dirs = New-Object System.Collections.ArrayList
            while ($tmp)
            {
                $tmp = [System.IO.Path]::GetDirectoryName($tmp)
                if ($tmp)
                {
                    $dirs.Add($tmp) | Out-Null
                }
            }
            $dirs.Reverse()
            $ParentDirItem = $ShareFileClient.Items.ByPath("/").Execute()
            foreach ($dir in $dirs)
            {
                $dir = $dir.Replace("\", "/")
                try
                {
                    $ParentDirItem = $ShareFileClient.Items.ByPath($dir).Execute()
                }
                catch [ShareFile.Api.Client.Exceptions.ODataException]
                {
                    $folder = New-Object ShareFile.Api.Client.Models.Folder 
                    $folder.Name = $dir.Split("/")[-1]
                    Write-Verbose "Creating directory `"$($folder.Name)`" on ShareFile."
                    $ParentDirItem = $ShareFileClient.Items.CreateFolder($ParentDirItem.Url, $folder, $false).execute()
                }
            }

            # Can't copy to a file path. Must be a directory path.
            $FullDstDir = [System.IO.Path]::GetDirectoryName($FullDstPath)
            $FullDstDir = $FullDstDir.Replace("\", "/")

            $UploadRequest = New-Object ShareFile.Api.Client.Transfers.UploadSpecificationRequest
            $UploadRequest.FileName = $FileToUpload.Name
            $UploadRequest.FileSize = $FileToUpload.Length
            $UploadRequest.Parent = $ParentDirItem.Url

            $stream = $FileToUpload.OpenRead()
            try
            {
                $Uploader = $ShareFileClient.GetFileUploader($UploadRequest, $stream)
                $UploadedFile = $Uploader.Upload()

                if (!$ShareParentFolderLink)
                {
                    $shareItem = New-Object ShareFile.Api.Client.Models.Item
                    $shareItem.Id = $UploadedFile.Id
                    $share.Items.Add($shareItem)
                }
            }
            finally
            {
                $stream.Close()
            }
        }
    }

    if ($ShareParentFolderLink)
    {
        if ($pscmdlet.ShouldProcess("ShareFile public share link will point to parent folder $DestinationDirectory.", "", "")) {
            $sfItem = $ShareFileClient.Items.ByPath($DestinationDirectory).Execute()
            $shareItem = New-Object ShareFile.Api.Client.Models.Item
            $shareItem.Id = $sfItem.Id
            $share.Items.Add($shareItem)
        }
    }

    if ($pscmdlet.ShouldProcess("Create public share link on ShareFile.", "", "")) {
        $ShareResult = $ShareFileClient.Shares.Create($share).Execute()
        $ShareResult.Uri.AbsoluteUri
    }
}
