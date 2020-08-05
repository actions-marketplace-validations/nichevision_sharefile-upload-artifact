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

    try
    {
        $task = $oauthService.PasswordGrantAsync($Username, $Password, $Subdomain, $ApplicationControlPlane)
        $task.Wait()

        $oauthToken = $task.Result
        $sfClient.AddOAuthCredentials($oauthToken)
        $sfClient.BaseUri = $oauthToken.GetUri()
        $sfClient.Sessions.Login().Execute() | Out-Null
        return $sfClient
    }
    catch
    {
        throw
    }
}

function Setup-ShareFile
{
    $DllPath = Join-Path $PSScriptRoot ".\lib\netstandard1.3\ShareFile.Api.Client.dll"
    Add-Type -Path $DllPath -ErrorAction Stop
}

function Copy-ToShareFile
{
    <#
        .SYNOPSIS
        Copy one or more file or directories to a destination on ShareFile.

        .PARAMETER ShareFileClient
        The ShareFile client with authorization to upload files, create folders, and create
        a Share at the specified destination.

        .PARAMETER Destination
        The directory name on ShareFile where files will be uploaded to.

        .PARAMETER ShareParentFolderLink
        If specified, the Share link that is created will point directly to DestinationDirectory,
        instead of to the individually uploaded files. This means the directory structure will be
        displayed in the share.

        .PARAMETER ExpirationDate
        The expiration date of the created Share. The default of [datetime]::MaxValue means
        the Share does not expire.

        .PARAMETER Files
        A collection of files and/or directories to upload.

        Directories are uploaded as-is, preserving their name and entire structure to DestinationDirectory.

        Individual files are uploaded directly to DestinationDirectory, without preserving their parent
        directories.

        .PARAMETER Exclude
        A collection of strings used to exclude files. Supports typical powershell wildcards.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory=$true)]
        [ShareFile.Api.Client.ShareFileClient] $ShareFileClient,

        [Parameter(Mandatory=$true)]
        $Files,

        [Parameter(Mandatory=$true)]
        [string] $DestinationDirectory,

        [switch] $ShareParentFolderLink,

        [datetime] $ExpirationDate = [datetime]::MaxValue,

        [System.String[]] $Exclude
    )

    Setup-ShareFile | Out-Null

    if ($null -eq $Files) 
    {
        throw "No files were specified.";
    }

    $share = New-Object ShareFile.Api.Client.Models.Share
    $share.RequireLogin = $false
    $share.ShareType = [ShareFile.Api.Client.Models.ShareType]::Send
    $share.ExpirationDate = $ExpirationDate
    $share.Items = New-Object System.Collections.Generic.List[ShareFile.Api.Client.Models.Item]

    $Files | ForEach-Object {
        # Get-Item below does not throw an error if the item does not exist and $Exclude has a value, so
        # we call it here separately to allow the error to raise.
        Get-Item $_ -ErrorAction Stop | Out-Null
        foreach ($FileToUpload in (Get-Item $_ -Exclude $Exclude))
        {
            $IsDirectory = [bool]($FileToUpload.Attributes -band [System.IO.FileAttributes]::Directory)
            
            if ($IsDirectory)
            {
                $SubFiles = Get-ChildItem -r $FileToUpload -File -Exclude $Exclude
                foreach ($f in $SubFiles)
                {
                    $UploadedFile = Upload-ToShareFile -File $f -PreserveRelativeTo $FileToUpload.Parent -DestinationDirectory $DestinationDirectory        
                    if (!$ShareParentFolderLink)
                    {
                        $shareItem = New-Object ShareFile.Api.Client.Models.Item
                        $shareItem.Id = $UploadedFile.Id
                        $share.Items.Add($shareItem)
                    }
                }
            }
            else
            {
                $UploadedFile = Upload-ToShareFile -File $FileToUpload -DestinationDirectory $DestinationDirectory
                if (!$ShareParentFolderLink)
                {
                    $shareItem = New-Object ShareFile.Api.Client.Models.Item
                    $shareItem.Id = $UploadedFile.Id
                    $share.Items.Add($shareItem)
                }
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

function Upload-ToShareFile {
    <#
        .SYNOPSIS
        Upload a file to a directory on ShareFile.

        .PARAMETER File
        The file to upload. Must be a file, and not a directory.

        .PARAMETER PreserveRelativeTo
        If not specified, the File is uploaded directly to Destination, without
        preserving subdirectories.
        
        If specified, the directories containing File will be preserved in the
        destination, not including the name of $PreserveRelativeTo.

        .PARAMETER DestinationDirectory
        The directory on ShareFile to upload File to.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [System.IO.FileInfo] $File,
        [System.IO.DirectoryInfo] $PreserveRelativeTo,
        [string] $DestinationDirectory
    )
    if ($PreserveRelativeTo)
    {
        $Name = $File.FullName.Replace($PreserveRelativeTo.FullName, '')
    }
    else
    {
        $Name = $File.Name
    }

    $FullDstPath = Join-Path $DestinationDirectory $Name

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
            if ($pscmdlet.ShouldProcess("Create destination directory $dir.", "", "")) {
                $ParentDirItem = $ShareFileClient.Items.CreateFolder($ParentDirItem.Url, $folder, $false).execute()
            }
        }
    }

    $UploadRequest = New-Object ShareFile.Api.Client.Transfers.UploadSpecificationRequest
    $UploadRequest.FileName = $File.Name
    $UploadRequest.FileSize = $File.Length
    $UploadRequest.Parent = $ParentDirItem.Url

    if ($pscmdlet.ShouldProcess("Upload $($File.FullName) to $FullDstPath.", "", "")) {

        $stream = $File.OpenRead()
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
            
            $UploadedFile
        }
        finally
        {
            $stream.Close()
        }
    }
}
