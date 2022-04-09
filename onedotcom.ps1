<#
.SYNOPSIS
    Adds and deletes TXT record to your one.com domain with win-wacs.
.DESCRIPTION
    Works with win-wacs to add and delete TXT records for use with Let's encrypt certificates.
.NOTES
    File Name   : onedotcom.ps1
    Version     : 1.0 (Initial version)
    Author      : Morten Hansen
.LINK
    https://github.com/morhans/win-acme_dns_one.com
.EXAMPLE
    onedotcom.ps1 create <Identifier> <RecordName> <Token>
.EXAMPLE
    onedotcom.ps1 delete <Identifier> <RecordName> <Token>
.EXAMPLE
    onedotcom.ps1 setcred
#>

[CmdletBinding()]
    param(
        [Parameter(Position=0)]
        [string]$action,
        [Parameter(Position=1)]
        [string]$Identifier,
        [Parameter(Position=2)]
        [string]$RecordName,
        [Parameter(Position=3)]
        [string]$Token
    )

$global:apiRoot = 'https://www.one.com/admin'

function Add-DnsRecord {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory,Position=0)]
        [string]$Identifier,
        [Parameter(Mandatory,Position=1)]
        [string]$RecordName,
        [Parameter(Mandatory,Position=2)]
        [string]$TxtValue,
        [Parameter(Mandatory,Position=3)]
        [object]$LoginSession
    )

    # add the new TXT record
    $topdomain = getTopDomain $Identifier
    $RecordName = $RecordName.Substring(0,$RecordName.Length-$topdomain.Length-1)
    $PostData = @{type="dns_custom_records";attributes=@{priority=0;ttl=600;type="TXT";prefix=$RecordName;content=$TxtValue}}|ConvertTo-Json
    $url = "$apiRoot/api/domains/$topdomain/dns/custom_records"
    Write-Debug $url
    Write-Verbose "Adding $RecordName with value $TxtValue to $Identifier"
    try {    
        $webrequest = Invoke-WebRequest -Uri $url -Body $PostData -WebSession $LoginSession -Method POST -UseBasicParsing -ContentType "application/json" -ErrorAction Stop
    }
    catch [System.Net.WebException] { 
        Write-Verbose "An exception was caught: $($_.Exception.Message)"
        $_.Exception.Response
    }
    
    #Check if adding was a success
    $Result = ConvertFrom-Json $webrequest.content
    if ([String]::IsNullOrWhiteSpace($Result.result.data.id)) {
        throw "TXT record for $RecordName ws not added!"
    }

   <#
    .SYNOPSIS
        Add a DNS TXT record to One.com.
    .DESCRIPTION
        Use One.com api to add a TXT record to a One.com DNS zone.
    .PARAMETER Identifier
        DNS name to be added a TXT record. 
    .PARAMETER RecordName
        The fully qualified name of the TXT record.
    .PARAMETER TxtValue
        The value of the TXT record.
    .EXAMPLE
        Add-DnsRecord 'example.com' '_acme-challenge.site1' 'asdfqwer12345678' '$SessionID'
        Adds a TXT record for the specified site with the specified value.
    #>
}

function Remove-DnsRecord {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory,Position=0)]
        [string]$Identifier,
        [Parameter(Mandatory,Position=1)]
        [string]$RecordName,
        [Parameter(Mandatory,Position=2)]
        [string]$TxtValue,
        [Parameter(Mandatory,Position=3)]
        [object]$LoginSession
    )
    
    # check for an existing record
    $topdomain = getTopDomain $Identifier
    $RecordName = $RecordName.Substring(0,$RecordName.Length-$topdomain.Length-1)
    $RecId = Find-RecordId $topdomain $RecordName $TxtValue $LoginSession
    if ([String]::IsNullOrWhiteSpace($RecId)) {
        throw "Unable to find record id for $RecordName"
    }

    # remove the txt record if it exists
    Write-Verbose "Removing $RecordName with value $TxtValue from $Identifier"
    $url = "$apiRoot/api/domains/$topdomain/dns/custom_records/$RecId"
    Write-Debug $url
    try {    
        $webrequest = Invoke-WebRequest -Uri $url -WebSession $LoginSession -Method DELETE -UseBasicParsing -ContentType "application/json" -ErrorAction Stop
    }
    catch [System.Net.WebException] { 
        Write-Verbose "An exception was caught: $($_.Exception.Message)"
        $_.Exception.Response
    }

    # Check if removal was a success
    if (!($webrequest.content -eq '{"result":null,"metadata":null}')) {
        throw "Unable to delete record $RecordName!"
    }

    <#
    .SYNOPSIS
        Remove a DNS TXT record from One.com.
    .DESCRIPTION
        Use One.com api to remove a TXT record to a One.com DNS zone.
    .PARAMETER Identifier
        DNS name to have TXT record deleted.
    .PARAMETER RecordName
        The fully qualified name of the TXT record.
    .PARAMETER TxtValue
        The value of the TXT record.
    .EXAMPLE
        Remove-DnsRecord Example 'example.com' '_acme-challenge.site1' 'asdfqwer12345678' '$SessionID'
        Removes a TXT record for the specified site with the specified value.
    #>

}

function EncryptCred {
    
    #Ask for credentials
    $Credential = Get-Credential -Message "Login and password for One.com"

    #Save credentials
    $Credential | Export-CliXml -Path "${env:\userprofile}\One.com.dat"

    <#
    .SYNOPSIS
        Saves One.com credentials to file.
    .DESCRIPTION
        Encrypt credentials to use on One.com login. Credentials is only readable by the creating user.
    #>

}


############################
# Helper Functions
############################

function getTopDomain {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory,Position=0)]
        [string]$Identifier
    )
    
    $pieces = $Identifier.Split(".")
    for ($i=1; $i -lt ($pieces.Count-1); $i++) {
        $topdomain = "$( $pieces[$i..($pieces.Count-1)] -join '.' )"
    }
    if (([String]::IsNullOrWhiteSpace($topdomain))) {
        $topdomain = $Identifier
    }

    return $topdomain
}
function getCustomRecords {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory,Position=0)]
        [string]$Identifier,
        [Parameter(Mandatory,Position=1)]
        [object]$LoginSess
    )
    
    $url = "$apiroot/api/domains/$topdomain/dns/custom_records"
    Write-Debug $url
    try {        
        $webrequest = Invoke-WebRequest -Uri $url -Method Default -WebSession $LoginSess -UseBasicParsing -ErrorAction Stop
    }
    catch [System.Net.WebException] { 
        Write-Verbose "An exception was caught: $($_.Exception.Message)"
        $_.Exception.Response
    } 
    $jsonObj = ConvertFrom-Json $webrequest.content
    return $jsonObj.result.data
}

function Find-RecordId {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory,Position=0)]
        [string]$Identifier,
        [Parameter(Mandatory,Position=1)]
        [string]$RecordName,
        [Parameter(Mandatory,Position=2)]
        [object]$TxtValue,
        [Parameter(Mandatory,Position=3)]
        [object]$LoginSess
    )

    $RecObj = getCustomRecords $Identifier $LoginSess  
        
    ForEach($rec in $RecObj) {
        if ($rec.attributes.prefix -eq $RecordName -and $rec.attributes.content -eq $TxtValue -and $rec.attributes.type -eq "TXT") {
            $RecId = $rec.id
        }
         
    }
    Write-Debug "ID (Empty if not found): $RecId"
    return $RecId
}

function DecryptCred {

    if (!(Test-Path "${env:\userprofile}\One.com.dat"))  {
        throw "Login and password not set (run with option setcred to set them."
    }

    $Credential = Import-CliXml -Path "${env:\userprofile}\One.com.dat"


    return $Credential
}

function onedotcom_login {

    $SearchString = '<form id="kc-form-login" class="Login-form login autofill" onsubmit="login.disabled = true; return true;" action="'

    $odcCred = DecryptCred

    $usr = $odcCred.UserName
    $pwd = $odcCred.GetNetworkCredential().Password
    
    if (([String]::IsNullOrWhiteSpace($usr)) -or ([String]::IsNullOrWhiteSpace($pwd)))  {
        throw "Login and/or password are not set correctly. Reissue with option setcred"
    }

    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
   
    try {
        $webrequest = Invoke-WebRequest -Uri $apiRoot -Method Default -SessionVariable websession -UseBasicParsing -ErrorAction Stop
        $pos = $webrequest.content.LastIndexOf($SearchString) + $SearchString.Length 
        $resulttxt = $webrequest.content.Substring($pos)
    }
    catch [System.Net.WebException] { 
        Write-Verbose "An exception was caught: $($_.Exception.Message)"
        $_.Exception.Response
    }

    try { 
        $pos = $resulttxt.IndexOf('"')
        $LoginUrl = $resulttxt.Substring(0, $pos)
        $LoginUrl = $LoginUrl.replace('&amp;','&')
        $formFields = @{username=$usr;password=$pwd;credentialId=''}

        $webrequest = Invoke-WebRequest -Uri $LoginUrl -Body $formFields -WebSession $websession -Method POST -UseBasicParsing -ErrorAction Stop
    }
    catch [System.Net.WebException] { 
        Write-Verbose "An exception was caught: $($_.Exception.Message)"
        $_.Exception.Response
    }
    Remove-Variable usr, pwd

    return $websession
}

############################
# Main program
############################

$ProgressPreference = 'SilentlyContinue'
switch ($action) {
    "create" {
        if (!([String]::IsNullOrWhiteSpace($Identifier)) -and !([String]::IsNullOrWhiteSpace($RecordName)) -and !([String]::IsNullOrWhiteSpace($Token))) {
                $sess = onedotcom_login
                Add-DnsRecord $Identifier $RecordName $Token $Sess
        }
        else {
            Write-Error "Argument(s) Identifier, RecordName and/or Token were not applied!"
        }  
    }
    "delete" {
        if (!([String]::IsNullOrWhiteSpace($Identifier)) -and !([String]::IsNullOrWhiteSpace($RecordName)) -and !([String]::IsNullOrWhiteSpace($Token))) {
            $sess = onedotcom_login
            Remove-DnsRecord $Identifier $RecordName $Token $Sess
        }
        else {
            Write-Error "Argument(s) Identifier, RecordName and/or Token were not applied!"
        }    
    }
    "setcred" {
        EncryptCred
    }
    Default {
        Write-Error "No or wrong arguments were passed. Valid arguments are create, delete and setcred.`n
        Syntax:`n
        onedotcom.ps1 create <Identifier> <RecordName> <Token>`n
        onedotcom.ps1 delete <Identifier> <RecordName> <Token>`n
        onedotcom.ps1 setcred (Set the credentials for one.com)"
    }
    
}
