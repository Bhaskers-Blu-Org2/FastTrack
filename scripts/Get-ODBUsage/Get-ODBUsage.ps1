<#       
    .DESCRIPTION
        Script to enumerate OneDrive for Business Sites along with their data usage and date created. 

        The sample scripts are not supported under any Microsoft standard support 
        program or service. The sample scripts are provided AS IS without warranty  
        of any kind. Microsoft further disclaims all implied warranties including,  
        without limitation, any implied warranties of merchantability or of fitness for 
        a particular purpose. The entire risk arising out of the use or performance of  
        the sample scripts and documentation remains with you. In no event shall 
        Microsoft, its authors, or anyone else involved in the creation, production, or 
        delivery of the scripts be liable for any damages whatsoever (including, 
        without limitation, damages for loss of business profits, business interruption, 
        loss of business information, or other pecuniary loss) arising out of the use 
        of or inability to use the sample scripts or documentation, even if Microsoft 
        has been advised of the possibility of such damages.

        Author: Alejandro Lopez - alejanl@microsoft.com

        Requirements: 
            SharePoint Online Management Shell : https://www.microsoft.com/en-us/download/details.aspx?id=35588

    .PARAMETER AdminSiteUrl
        Specifies the URL of the SharePoint Online Administration Center site.
	.PARAMETER ImportCSVFile
        This is optional. You can use this if you want to run the report against a subset of users. If empty, it'll run against all sites in the tenant. 
        The CSV file needs to have "LoginName" as the column header. 
    .EXAMPLE
        .\Get-ODBUsage.ps1 -AdminSiteUrl "https://domain-admin.sharepoint.com" -ImportCSVFile "c:\userslist.csv"
    .EXAMPLE
        .\Get-ODBUsage.ps1 -AdminSiteUrl "https://domain-admin.sharepoint.com" 
        
#>
[Cmdletbinding()]
Param (
    [Parameter(mandatory=$true)][String]$AdminSiteUrl,
	[Parameter(mandatory=$false)][String]$ImportCSVFile
)

begin 
{
    #Functions
    Function Write-LogEntry {
        param(
            [string] $LogName ,
            [string] $LogEntryText,
            [string] $ForegroundColor
        )
        if ($LogName -NotLike $Null) {
            # log the date and time in the text file along with the data passed
            "$([DateTime]::Now.ToShortDateString()) $([DateTime]::Now.ToShortTimeString()) : $LogEntryText" | Out-File -FilePath $LogName -append;
            if ($ForeGroundColor -NotLike $null) {
                # for testing i pass the ForegroundColor parameter to act as a switch to also write to the shell console
                write-host $LogEntryText -ForegroundColor $ForeGroundColor
            }
        }
    }
    
    Try{
        Import-Module Microsoft.Online.SharePoint.Powershell -DisableNameChecking -ErrorAction SilentlyContinue
        Connect-SPOService -Url $AdminSiteUrl
        $yyyyMMdd = Get-Date -Format 'yyyyMMdd'
        $computer = $env:COMPUTERNAME
        $user = $env:USERNAME
        $version = "2.20180814"
        $log = "$PSScriptRoot\Get-ODBUsage-$yyyyMMdd.log"
        $output = "$PSScriptRoot\Get-ODBUsage.csv"
        $MySiteHostURL = $AdminSiteUrl.replace("admin","my") + "/personal/" 

        Write-LogEntry -LogName:$Log -LogEntryText "User: $user Computer: $computer Version: $version" -foregroundcolor Yellow

    }
    catch{
        Write-LogEntry -LogName:$Log -LogEntryText "Pre-flight failed: $_" -foregroundcolor Red
    }
}

process 
{
    try{
        Write-LogEntry -LogName:$Log -LogEntryText "Collect ODB Sites..." -foregroundcolor Yellow
        If($ImportCSVFile){
            If(Test-Path $ImportCSVFile){
                $UsersLogin = Import-Csv $ImportCSVFile | %{$_.LoginName}
                Write-LogEntry -LogName:$Log -LogEntryText "Using csv file with user count: $($UsersLogin.count)" -foregroundcolor White
                $sites = new-object -typename System.Collections.Arraylist
                Foreach($user in $UsersLogin){
                    $odbURL = $MySiteHostURL + $user.Replace(".", "_").Replace("@", "_")
                    $odbSite = Get-SPOSite -Identity $odbURL
                    $sites.Add($odbSite) | Out-Null
                }
            }
            else{
                Write-Host "$($ImportCSVFile) file not found."
            }
        }
        Else{
            $sites = Get-SPOSite -IncludePersonalSite $true -Limit All -Filter "Url -like '*-my.sharepoint.com/personal/*'"
        }
    }
    catch{
        Write-LogEntry -LogName:$Log -LogEntryText "Error with: $_" -foregroundcolor Red
    }
    	
}

End
{
    Write-LogEntry -LogName:$Log -LogEntryText "Build report..." -foregroundcolor Yellow
    $listOfODBSites = New-Object -typename System.Collections.ArrayList
    Foreach($odbsite in $sites){
        $entry = [pscustomobject]@{URL = $odbSite.Url;
                                    Owner = $odbSite.Owner;
                                    Title = $odbSite.Title
                                    StorageQuotaInMB = $odbSite.StorageQuota;
                                    StorageUsageCurrentInMB = $odbSite.StorageUsageCurrent;
                                    LocaleID = $odbSite.LocaleID;
                                    SharingCapability = $odbSite.SharingCapability;
                                    SiteDefinedSharingCapability = $odbSite.SiteDefinedSharingCapability;
                                    }
        $listOfODBSites.add($entry) | Out-Null
    }
    $listOfODBSites | Export-CSV -Path $output -NoTypeInformation
    Write-LogEntry -LogName:$Log -LogEntryText "$output" -foregroundcolor Green
    ""
} 
 
