#Author: Morten Hansen
#
#
# Note: Script requires the credentials is set before add and remove functionality can be used.
#       Do this by running the script with option setcred. 
#
#Version history:
#1.0   : Initial version

$global:apiRoot = 'https://www.one.com/admin/'

function Add-DnsTxtGDNS {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory,Position=0)]
        [string]$Identifier,
        [Parameter(Mandatory,Position=1)]
        [string]$RecordName,
        [Parameter(Mandatory,Position=2)]
        [string]$TxtValue,
        [Parameter(Mandatory=$false,Position=3)]
        [boolean]$AcceptTerms=$true
    )


    $loginsess = gratisdns_login($AcceptTerms)

    Write-Verbose "Attempting to find hosted zone for $Identifier"
    $ZoneName = Find-GDNSZone $Identifier $loginsess
    if ([String]::IsNullOrWhiteSpace($ZoneName)) {
        throw "Unable to find zone for $Identifier"
    }
    
    # add the new TXT record
    $url = "$apiRoot/?action=dns_primary_record_added_txt&user_domain=$ZoneName&name=$RecordName&txtdata=$txtvalue&ttl=1"
    Write-Verbose "Adding $RecordName with value $TxtValue to $ZoneName"
    try {    
        $webrequest = Invoke-WebRequest -Uri $url -WebSession $loginsess -UseBasicParsing
        $StatusCode = $webrequest.StatusCode
    }
    catch {
        $StatusCode = $_.Exception.Response.StatusCode.value__
    }
    
    #Check if add was a success
    if (!($webrequest.content -like "*table-success*")) {
        throw "Unable to create entry"
    }


   <#
    .SYNOPSIS
        Add a DNS TXT record to GratisDNS.
    .DESCRIPTION
        Use GratisDNS api to add a TXT record to a GratisDNS DNS zone.
    .PARAMETER Identifier
        DNS name to be evaluated. 
    .PARAMETER RecordName
        The fully qualified name of the TXT record.
    .PARAMETER TxtValue
        The value of the TXT record.
    .EXAMPLE
        Add-DnsTxtExample 'example.com' '_acme-challenge.site1.example.com' 'asdfqwer12345678'
        Adds a TXT record for the specified site with the specified value.
    #>
}

function Remove-DnsTxtGDNS {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory,Position=0)]
        [string]$Identifier,
        [Parameter(Mandatory,Position=1)]
        [string]$RecordName,
        [Parameter(Mandatory,Position=2)]
        [string]$TxtValue,
        [Parameter(Mandatory=$false,Position=3)]
        [boolean]$AcceptTerms=$true
    )

    $loginsess = gratisdns_login($AcceptTerms)
    
    Write-Verbose "Attempting to find hosted zone for $Identifier"
    $ZoneName = Find-GDNSZone $Identifier $loginsess
    if ([String]::IsNullOrWhiteSpace($ZoneName)) {
        throw "Unable to find zone for $Identifier"
    }
    
    # check for an existing record
    $RecId = Find-GDNSRecordId $RecordName $TxtValue $loginsess
    if ([String]::IsNullOrWhiteSpace($RecId)) {
        throw "Unable to find record id for $RecordName"
    }

    # remove the txt record if it exists
    Write-Verbose "Removing $RecordName with value $TxtValue from $Identifier"
    $url = "$apiRoot/?action=dns_primary_delete_txt&user_domain=$ZoneName&id=$RecId"
    try {    
        $webrequest = Invoke-WebRequest -Uri $url -WebSession $loginsess -UseBasicParsing
        $StatusCode = $webrequest.StatusCode
    }
    catch {
        $StatusCode = $_.Exception.Response.StatusCode.value__
    }

    # Check if removal was a success
    if (!($webrequest.content -like "*table-success*")) {
        throw "Unable to delete entry"
    }

    <#
    .SYNOPSIS
        Remove a DNS TXT record from GratisDNS.
    .DESCRIPTION
        Use GratisDNS api to remove a TXT record to a GratisDNS DNS zone.
    .PARAMETER Identifier
        DNS name to be evaluated.
    .PARAMETER RecordName
        The fully qualified name of the TXT record.
    .PARAMETER TxtValue
        The value of the TXT record.
    .EXAMPLE
        Remove-DnsTxtExample 'example.com' '_acme-challenge.site1.example.com' 'asdfqwer12345678'
        Removes a TXT record for the specified site with the specified value.
    #>

}

function EncryptCred {
    
    #Ask for credentials
    $Credential = Get-Credential -Message "Login and password for GratisDNS"

    #Save credentials
    $Credential | Export-CliXml -Path "${env:\userprofile}\GDNS.dat"

    <#
    .SYNOPSIS
        Saves GratisDNS credentials to file.
    .DESCRIPTION
        Encrypt credentials to use on GratisDNS login. Credentials is only readable by the creating user.
    #>

}


############################
# Helper Functions
############################

function Check-GDNSTOC {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false,Position=0)]
        [boolean]$autoaccept = $true,
        [Parameter(Mandatory,Position=1)]
        [object]$LoginSess
    )
    
    try {        
        $webrequest = Invoke-WebRequest -Uri $url -WebSession $loginsess -UseBasicParsing
        $StatusCode = $webrequest.StatusCode
    }
    catch {
        $StatusCode = $_.Exception.Response.StatusCode.value__
    } 
    


}

function Find-GDNSZone {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory,Position=0)]
        [string]$Identifier,
        [Parameter(Mandatory,Position=1)]
        [object]$LoginSess
    )

    $url = "$apiRoot/?action=dns_primarydns"
    try {        
        $webrequest = Invoke-WebRequest -Uri $url -WebSession $loginsess -UseBasicParsing
        $StatusCode = $webrequest.StatusCode
    }
    catch {
        $StatusCode = $_.Exception.Response.StatusCode.value__
    } 
      
    $pieces = $RecordName.Split('.')
    for ($i=1; $i -lt ($pieces.Count-1); $i++) {
        $topdomain = "$( $pieces[$i..($pieces.Count-1)] -join '.' )"
    }
    
    if($webrequest.content -like "*$topdomain*") {
        return $topdomain
    }
    else {
        return $null
    }
}

function Find-GDNSRecordId {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory,Position=0)]
        [string]$RecordName,
        [Parameter(Mandatory,Position=1)]
        [object]$TxtValue,
        [Parameter(Mandatory,Position=2)]
        [object]$LoginSess
    )

    $url = "$apiRoot/?action=dns_primary_changeDNSsetup&user_domain=$ZoneName"

    try {    
        $webrequest = Invoke-WebRequest -Uri $url -WebSession $loginsess -UseBasicParsing
        $StatusCode = $webrequest.StatusCode
    }
    catch {
        $StatusCode = $_.Exception.Response.StatusCode.value__
    }
    
        
    $tmpid = ForEach-Object { [regex]::matches( $webrequest.content, "<td>$([regex]::escape($RecordName))</td>\s*<td>$([regex]::escape($TxtValue))</td>[^?]*[^&]*&id=[^&]*" ) }
    if ([String]::IsNullOrWhiteSpace($tmpid)) {
        $id = $null
    }
    else {
        $id= $tmpid.Value.Substring($tmpid.Value.LastIndexOf('=')+1)
    }
    
    return $id
}

function DecryptCred {

    if (!(Test-Path "${env:\userprofile}\GDNS.dat"))  {
        throw "Login and password not set (run with option setcred to set them."
    }

    $Credential = Import-CliXml -Path "${env:\userprofile}\GDNS.dat"


    return $Credential
}

function onedotcom_login {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false,Position=0)]
        [boolean]$AcceptTerms=$true
    )

    $SearchString = '<form id="kc-form-login" class="Login-form login autofill" onsubmit="login.disabled = true; return true;" action="'

    #$odcCred = DecryptCred

    #$usr = $odcCred.UserName
    #$pwd = $odcCred.GetNetworkCredential().Password

    $usr = 'hostmaster@jumbogris.dk'
    $pwd = '7zH%.!WbN@&uU*2'
    
    if (([String]::IsNullOrWhiteSpace($usr)) -or ([String]::IsNullOrWhiteSpace($pwd)))  {
        throw "Login and/or password are not set correctly. Reissue with option setcred"
    }

    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
   
    try {
        $webrequest = Invoke-WebRequest -Uri $apiRoot -Method Default -SessionVariable websession -UseBasicParsing
        $webrequest.content | Out-File -FilePath "C:\Users\Programmering\Desktop\output_before.txt"
        $pos = $webrequest.content.LastIndexOf($SearchString) + $SearchString.Length 
        $resulttxt = $webrequest.content.Substring($pos)
        $pos = $resulttxt.IndexOf('"')
        $LoginUrl = $resulttxt.Substring(0, $pos)
        $LoginUrl = $LoginUrl.replace('&amp;','&')
        $LoginUrl | Out-File -FilePath "C:\Users\Programmering\Desktop\output_login.txt"
        $formFields = @{username=$usr;password=$pwd;credentialId=''}

        $webrequest = Invoke-WebRequest -Uri $LoginUrl -Body $formFields -WebSession $websession -Method POST -UseBasicParsing
        $webrequest.content | Out-File -FilePath "C:\Users\Programmering\Desktop\output_after.txt"
        $webrequest.StatusDescriptionOK
        $StatusCode = $webrequest.StatusCode
    }
    catch {
        $StatusCode = $_.Exception.Response.StatusCode.value__
    }
    
    if($webrequest.content -like "*table-danger*") {
        throw "One.com login failed for user $usr"
    }

    if($webrequest.content -like "*You have not been accepting our terms*") {
        if($AcceptTerms) {
            $url = "$apiRoot/?approveterms=yes"
            try {    
                $webrequest = Invoke-WebRequest -Uri $url -WebSession $websession -UseBasicParsing
                $StatusCode = $webrequest.StatusCode
            }
            catch {
                $StatusCode = $_.Exception.Response.StatusCode.value__
            }

        }
        else {
            throw "GratisDNS ask for acceptence of terms for $usr. DeclineTerms option enabled."
        }
    }
    
    Remove-Variable usr, pwd

    return $websession
}

onedotcom_login

<#
$action = $args[0]
if($action -eq "create") {
	$zone = $args[1]
    $name = $args[2]
    $text = $args[3]
    $terms = $true
    if($args[4] -eq "DeclineTerms") {
        $terms = $false
    }
	Add-DnsTxtGDNS $zone $name $text $terms
}elseif($action -eq "delete") {
	$zone = $args[1]
    $name = $args[2]
    $text = $args[3]
    $terms = $true
    if($args[4] -eq "DeclineTerms") {
        $terms = $false
    }
	Remove-DnsTxtGDNS $zone $name $text $terms
}elseif($action -eq "setcred") {
    EncryptCred
}
else {
    Write-Verbose "No arguments given. Please see documentation."
}
#>