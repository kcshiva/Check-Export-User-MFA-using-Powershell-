#This fucntions opens file dialog which allows to save admin .csv file to admin's desire location
Function Save-File ([string]$initialDirectory) {

    $SaveInitialPath = "C:\"
	$SaveFileName = "Report"

    [System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") | Out-Null
    
    $OpenFileDialog = New-Object System.Windows.Forms.SaveFileDialog
    $OpenFileDialog.initialDirectory = $SaveInitialPath
    $OpenFileDialog.Filter = 'CSV (*.csv)| *.csv|txt files (*.txt)|*.txt'
    $OpenFileDialog.FileName = $SaveFileName
    $OpenFileDialog.ShowDialog() | Out-Null

    return $OpenFileDialog.filename

}

#Check if MSOnline Moudule exists if not install it
if(Get-Module -ListAvailable -Name MSOnline) {
    Write-Host "MSOnline Module Exists, Proceeding futher"
}
else {
Write-Host "Installing MSOnline Module"
Install-Module -Name MSOnline # install MSOnline Module if not is not already installed.Click to Yes and Yes to All when prompted.
}

#Connect to Azure active directory
Connect-MsolService

#Find MFA Methods
CLS
$Domain = Read-Host -Prompt "Enter Domain Name to check users MFA methods (for eg. 'contoso.com')"
Write-Host "Finding Azure Active Directory Accounts..." -ForegroundColor Green
$Users = Get-MsolUser -All | Where {$_.UserPrincipalName -like "*$Domain"} | ? {$_.IsLicensed -eq $True}
$Report = [System.Collections.Generic.List[Object]]::new() # Create output file
Write-Host "Processing" $Users.Count "accounts..." 
ForEach ($User in $Users) {
   $MFAMethods = $User.StrongAuthenticationMethods.MethodType
   $MFAEnforced = $User.StrongAuthenticationRequirements.State
   $DefaultMFAMethod = ($User.StrongAuthenticationMethods | ? {$_.IsDefault -eq "True"}).MethodType
   If (($MFAEnforced -eq "Enforced") -or ($MFAEnforced -eq "Enabled")) {
      Switch ($DefaultMFAMethod) {
        "OneWaySMS"             { $MethodUsed = "One-way SMS" }
        "PhoneAppNotification"  { $MethodUsed = "Authenticator app" }
      } #End Switch
    }
    Else {
          $MFAEnforced= "Not Enabled"
          $MethodUsed = "MFA Not Used" }
  
   $ReportLine = [PSCustomObject] @{
           User        = $User.UserPrincipalName
           Name        = $User.DisplayName
           MFAUsed     = $MFAEnforced
           Default_MFA_Method   = $DefaultMFAMethod
           License     = $User.IsLicensed
           Available_MFA_Methods = (@($MFAMethods) -join', ') }
          
                 
    $Report.Add($ReportLine) 
} # End For

#Prompts asking if admin want to export report in .csv format
$export_file = Read-Host -Prompt "Do you want to export user MFA status list (Y/N)"
While ($true) {
    if ($export_file.ToUpper() -contains 'Y' -or 'N'){
        if ($export_file.ToUpper() -eq 'Y'){
            $SaveMyFile = Save-File
            $Report | Export-CSV -Path $SaveMyFile
            Write-Host "Exporting Report"
            Write-Host "Report has been exported to your selected file location, Please check File Explorer in your computer to access .csv file" -ForegroundColor Magenta
            break
        }elseif ($export_file.ToUpper() -eq 'N') {
            Write-Host "No Need to export list, Exiting"
            break
    }else {
        Write-Host "Invalid Character! Please type valid characer" -ForegroundColor Red
        $export_file = Read-Host -Prompt "Do you want to export user MFA status list (Y/N)"
        }
    }
       
}

<#Prompts asking if admin wants instant access to user MFA Status list. If admin enter Y then it will open new winodws with users's MFA details, if admin enter N then it exits and finish powershell command.
if admin types character other than 'Y/y' and 'N/n' then it will keeps asking for right input. #>

$Instant_mfa_list = Read-Host -Prompt "Do you want instant access to users MFA status list of",$Domain," ? (Y/N)"
While ($true) {
    
    if ($Instant_mfa_list.ToUpper() -contains 'Y' -or 'N') {
        if ($Instant_mfa_list.ToUpper() -eq 'Y'){
            Write-Host " Users MFA Status list for",$Domain "will now open in new window" -ForegroundColor Green
            $Report | Select Name,License, MFAUsed, Default_MFA_Method, Available_MFA_Methods | Out-GridView
            break
        }elseif ($Instant_mfa_list.ToUpper() -eq 'N') {
            Write-Host "Exiting"
            break
    }else {
        Write-Host "Invalid Character!!!" -ForegroundColor Red
        $Instant_mfa_list = Read-Host -Prompt "Do you want instant access to users MFA status  list of",$Domain,"? (Y/N)"
        }
    }
}



