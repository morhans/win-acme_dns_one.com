warning: LF will be replaced by CRLF in onedotcom.ps1.
The file will have its original line endings in your working directory
[1mdiff --cc README.md[m
[1mindex 33bbae6,40689e1..0000000[m
[1m--- a/README.md[m
[1m+++ b/README.md[m
[36m@@@ -1,5 -1,5 +1,10 @@@[m
[32m++<<<<<<< HEAD[m
[32m +# win-acme dns api for danish DNS provider gratisdns.dk[m
[32m +win-acme_dns_GratisDNS[m
[32m++=======[m
[32m+ # win-acme dns api for DNS provider one.com[m
[32m+ win-acme_dns_one.com[m
[32m++>>>>>>> 11e45d70f6c9c1f662d5972a384561ad25c02407[m
  [m
  **Author:** Morten Hansen[m
  [m
[36m@@@ -49,4 -49,3 +54,7 @@@[m [mExample in settings.json file[m
  #### Information on using WACS[m
  [m
  Please see win-acme website found at https://www.win-acme.com[m
[32m++<<<<<<< HEAD[m
[32m + [m
[32m++=======[m
[32m++>>>>>>> 11e45d70f6c9c1f662d5972a384561ad25c02407[m
[1mdiff --cc onedotcom.ps1[m
[1mindex 6635609,8528dbd..0000000[m
[1m--- a/onedotcom.ps1[m
[1m+++ b/onedotcom.ps1[m
[36m@@@ -1,316 -1,316 +1,635 @@@[m
[31m -<#[m
[31m -.SYNOPSIS[m
[31m -    Adds and deletes TXT record to your one.com domain with win-wacs.[m
[31m -.DESCRIPTION[m
[31m -    Works with win-wacs to add and delete TXT records for use with Let's encrypt certificates.[m
[31m -.NOTES[m
[31m -    File Name   : onedotcom.ps1[m
[31m -    Version     : 1.0 (Initial version)[m
[31m -    Author      : Morten Hansen[m
[31m -.LINK[m
[31m -    https://github.com/morhans/win-acme_dns_one.com[m
[31m -.EXAMPLE[m
[31m -    onedotcom.ps1 create <Identifier> <RecordName> <Token>[m
[31m -.EXAMPLE[m
[31m -    onedotcom.ps1 delete <Identifier> <RecordName> <Token>[m
[31m -.EXAMPLE[m
[31m -    onedotcom.ps1 setcred[m
[31m -#>[m
[31m -[m
[31m -[CmdletBinding()][m
[31m -    param([m
[31m -        [Parameter(Position=0)][m
[31m -        [string]$action,[m
[31m -        [Parameter(Position=1)][m
[31m -        [string]$Identifier,[m
[31m -        [Parameter(Position=2)][m
[31m -        [string]$RecordName,[m
[31m -        [Parameter(Position=3)][m
[31m -        [string]$Token[m
[31m -    )[m
[31m -[m
[31m -$global:apiRoot = 'https://www.one.com/admin'[m
[31m -[m
[31m -function Add-DnsRecord {[m
[31m -    [CmdletBinding()][m
[31m -    param([m
[31m -        [Parameter(Mandatory,Position=0)][m
[31m -        [string]$Identifier,[m
[31m -        [Parameter(Mandatory,Position=1)][m
[31m -        [string]$RecordName,[m
[31m -        [Parameter(Mandatory,Position=2)][m
[31m -        [string]$TxtValue,[m
[31m -        [Parameter(Mandatory,Position=3)][m
[31m -        [object]$LoginSession[m
[31m -    )[m
[31m -[m
[31m -    # add the new TXT record[m
[31m -    $topdomain = getTopDomain $Identifier[m
[31m -    $RecordName = $RecordName.Substring(0,$RecordName.Length-$topdomain.Length-1)[m
[31m -    $PostData = @{type="dns_custom_records";attributes=@{priority=0;ttl=600;type="TXT";prefix=$RecordName;content=$TxtValue}}|ConvertTo-Json[m
[31m -    $url = "$apiRoot/api/domains/$topdomain/dns/custom_records"[m
[31m -    Write-Debug $url[m
[31m -    Write-Verbose "Adding $RecordName with value $TxtValue to $Identifier"[m
[31m -    try {    [m
[31m -        $webrequest = Invoke-WebRequest -Uri $url -Body $PostData -WebSession $LoginSession -Method POST -UseBasicParsing -ContentType "application/json" -ErrorAction Stop[m
[31m -    }[m
[31m -    catch [System.Net.WebException] { [m
[31m -        Write-Verbose "An exception was caught: $($_.Exception.Message)"[m
[31m -        $_.Exception.Response[m
[31m -    }[m
[31m -    [m
[31m -    #Check if adding was a success[m
[31m -    $Result = ConvertFrom-Json $webrequest.content[m
[31m -    if ([String]::IsNullOrWhiteSpace($Result.result.data.id)) {[m
[31m -        throw "TXT record for $RecordName ws not added!"[m
[31m -    }[m
[31m -[m
[31m -   <#[m
[31m -    .SYNOPSIS[m
[31m -        Add a DNS TXT record to One.com.[m
[31m -    .DESCRIPTION[m
[31m -        Use One.com api to add a TXT record to a One.com DNS zone.[m
[31m -    .PARAMETER Identifier[m
[31m -        DNS name to be added a TXT record. [m
[31m -    .PARAMETER RecordName[m
[31m -        The fully qualified name of the TXT record.[m
[31m -    .PARAMETER TxtValue[m
[31m -        The value of the TXT record.[m
[31m -    .EXAMPLE[m
[31m -        Add-DnsRecord 'example.com' '_acme-challenge.site1' 'asdfqwer12345678' '$SessionID'[m
[31m -        Adds a TXT record for the specified site with the specified value.[m
[31m -    #>[m
[31m -}[m
[31m -[m
[31m -function Remove-DnsRecord {[m
[31m -    [CmdletBinding()][m
[31m -    param([m
[31m -        [Parameter(Mandatory,Position=0)][m
[31m -        [string]$Identifier,[m
[31m -        [Parameter(Mandatory,Position=1)][m
[31m -        [string]$RecordName,[m
[31m -        [Parameter(Mandatory,Position=2)][m
[31m -        [string]$TxtValue,[m
[31m -        [Parameter(Mandatory,Position=3)][m
[31m -        [object]$LoginSession[m
[31m -    )[m
[31m -    [m
[31m -    # check for an existing record[m
[31m -    $topdomain = getTopDomain $Identifier[m
[31m -    $RecordName = $RecordName.Substring(0,$RecordName.Length-$topdomain.Length-1)[m
[31m -    $RecId = Find-RecordId $topdomain $RecordName $TxtValue $LoginSession[m
[31m -    if ([String]::IsNullOrWhiteSpace($RecId)) {[m
[31m -        throw "Unable to find record id for $RecordName"[m
[31m -    }[m
[31m -[m
[31m -    # remove the txt record if it exists[m
[31m -    Write-Verbose "Removing $RecordName with value $TxtValue from $Identifier"[m
[31m -    $url = "$apiRoot/api/domains/$topdomain/dns/custom_records/$RecId"[m
[31m -    Write-Debug $url[m
[31m -    try {    [m
[31m -        $webrequest = Invoke-WebRequest -Uri $url -WebSession $LoginSession -Method DELETE -UseBasicParsing -ContentType "application/json" -ErrorAction Stop[m
[31m -    }[m
[31m -    catch [System.Net.WebException] { [m
[31m -        Write-Verbose "An exception was caught: $($_.Exception.Message)"[m
[31m -        $_.Exception.Response[m
[31m -    }[m
[31m -[m
[31m -    # Check if removal was a success[m
[31m -    if (!($webrequest.content -eq '{"result":null,"metadata":null}')) {[m
[31m -        throw "Unable to delete record $RecordName!"[m
[31m -    }[m
[31m -[m
[31m -    <#[m
[31m -    .SYNOPSIS[m
[31m -        Remove a DNS TXT record from One.com.[m
[31m -    .DESCRIPTION[m
[31m -        Use One.com api to remove a TXT record to a One.com DNS zone.[m
[31m -    .PARAMETER Identifier[m
[31m -        DNS name to have TXT record deleted.[m
[31m -    .PARAMETER RecordName[m
[31m -        The fully qualified name of the TXT record.[m
[31m -    .PARAMETER TxtValue[m
[31m -        The value of the TXT record.[m
[31m -    .EXAMPLE[m
[31m -        Remove-DnsRecord Example 'example.com' '_acme-challenge.site1' 'asdfqwer12345678' '$SessionID'[m
[31m -        Removes a TXT record for the specified site with the specified value.[m
[31m -    #>[m
[31m -[m
[31m -}[m
[31m -[m
[31m -function EncryptCred {[m
[31m -    [m
[31m -    #Ask for credentials[m
[31m -    $Credential = Get-Credential -Message "Login and password for One.com"[m
[31m -[m
[31m -    #Save credentials[m
[31m -    $Credential | Export-CliXml -Path "${env:\userprofile}\One.com.dat"[m
[31m -[m
[31m -    <#[m
[31m -    .SYNOPSIS[m
[31m -        Saves One.com credentials to file.[m
[31m -    .DESCRIPTION[m
[31m -        Encrypt credentials to use on One.com login. Credentials is only readable by the creating user.[m
[31m -    #>[m
[31m -[m
[31m -}[m
[31m -[m
[31m -[m
[31m -############################[m
[31m -# Helper Functions[m
[31m -############################[m
[31m -[m
[31m -function getTopDomain {[m
[31m -    [CmdletBinding()][m
[31m -    param([m
[31m -        [Parameter(Mandatory,Position=0)][m
[31m -        [string]$Identifier[m
[31m -    )[m
[31m -    [m
[31m -    $pieces = $Identifier.Split(".")[m
[31m -    for ($i=1; $i -lt ($pieces.Count-1); $i++) {[m
[31m -        $topdomain = "$( $pieces[$i..($pieces.Count-1)] -join '.' )"[m
[31m -    }[m
[31m -    if (([String]::IsNullOrWhiteSpace($topdomain))) {[m
[31m -        $topdomain = $Identifier[m
[31m -    }[m
[31m -[m
[31m -    return $topdomain[m
[31m -}[m
[31m -function getCustomRecords {[m
[31m -    [CmdletBinding()][m
[31m -    param([m
[31m -        [Parameter(Mandatory,Position=0)][m
[31m -        [string]$Identifier,[m
[31m -        [Parameter(Mandatory,Position=1)][m
[31m -        [object]$LoginSess[m
[31m -    )[m
[31m -    [m
[31m -    $url = "$apiroot/api/domains/$topdomain/dns/custom_records"[m
[31m -    Write-Debug $url[m
[31m -    try {        [m
[31m -        $webrequest = Invoke-WebRequest -Uri $url -Method Default -WebSession $LoginSess -UseBasicParsing -ErrorAction Stop[m
[31m -    }[m
[31m -    catch [System.Net.WebException] { [m
[31m -        Write-Verbose "An exception was caught: $($_.Exception.Message)"[m
[31m -        $_.Exception.Response[m
[31m -    } [m
[31m -    $jsonObj = ConvertFrom-Json $webrequest.content[m
[31m -    return $jsonObj.result.data[m
[31m -}[m
[31m -[m
[31m -function Find-RecordId {[m
[31m -    [CmdletBinding()][m
[31m -    param([m
[31m -        [Parameter(Mandatory,Position=0)][m
[31m -        [string]$Identifier,[m
[31m -        [Parameter(Mandatory,Position=1)][m
[31m -        [string]$RecordName,[m
[31m -        [Parameter(Mandatory,Position=2)][m
[31m -        [object]$TxtValue,[m
[31m -        [Parameter(Mandatory,Position=3)][m
[31m -        [object]$LoginSess[m
[31m -    )[m
[31m -[m
[31m -    $RecObj = getCustomRecords $Identifier $LoginSess  [m
[31m -        [m
[31m -    ForEach($rec in $RecObj) {[m
[31m -        if ($rec.attributes.prefix -eq $RecordName -and $rec.attributes.content -eq $TxtValue -and $rec.attributes.type -eq "TXT") {[m
[31m -            $RecId = $rec.id[m
[31m -        }[m
[31m -         [m
[31m -    }[m
[31m -    Write-Debug "ID (Empty if not found): $RecId"[m
[31m -    return $RecId[m
[31m -}[m
[31m -[m
[31m -function DecryptCred {[m
[31m -[m
[31m -    if (!(Test-Path "${env:\userprofile}\One.com.dat"))  {[m
[31m -        throw "Login and password not set (run with option setcred to set them."[m
[31m -    }[m
[31m -[m
[31m -    $Credential = Import-CliXml -Path "${env:\userprofile}\One.com.dat"[m
[31m -[m
[31m -[m
[31m -    return $Credential[m
[31m -}[m
[31m -[m
[31m -function onedotcom_login {[m
[31m -[m
[31m -    $SearchString = '<form id="kc-form-login" class="Login-form login autofill" onsubmit="login.disabled = true; return true;" action="'[m
[31m -[m
[31m -    $odcCred = DecryptCred[m
[31m -[m
[31m -    $usr = $odcCred.UserName[m
[31m -    $pwd = $odcCred.GetNetworkCredential().Password[m
[31m -    [m
[31m -    if (([String]::IsNullOrWhiteSpace($usr)) -or ([String]::IsNullOrWhiteSpace($pwd)))  {[m
[31m -        throw "Login and/or password are not set correctly. Reissue with option setcred"[m
[31m -    }[m
[31m -[m
[31m -    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12[m
[31m -   [m
[31m -    try {[m
[31m -        $webrequest = Invoke-WebRequest -Uri $apiRoot -Method Default -SessionVariable websession -UseBasicParsing -ErrorAction Stop[m
[31m -        $pos = $webrequest.content.LastIndexOf($SearchString) + $SearchString.Length [m
[31m -        $resulttxt = $webrequest.content.Substring($pos)[m
[31m -    }[m
[31m -    catch [System.Net.WebException] { [m
[31m -        Write-Verbose "An exception was caught: $($_.Exception.Message)"[m
[31m -        $_.Exception.Response[m
[31m -    }[m
[31m -[m
[31m -    try { [m
[31m -        $pos = $resulttxt.IndexOf('"')[m
[31m -        $LoginUrl = $resulttxt.Substring(0, $pos)[m
[31m -        $LoginUrl = $LoginUrl.replace('&amp;','&')[m
[31m -        $formFields = @{username=$usr;password=$pwd;credentialId=''}[m
[31m -[m
[31m -        $webrequest = Invoke-WebRequest -Uri $LoginUrl -Body $formFields -WebSession $websession -Method POST -UseBasicParsing -ErrorAction Stop[m
[31m -    }[m
[31m -    catch [System.Net.WebException] { [m
[31m -        Write-Verbose "An exception was caught: $($_.Exception.Message)"[m
[31m -        $_.Exception.Response[m
[31m -    }[m
[31m -    Remove-Variable usr, pwd[m
[31m -[m
[31m -    return $websession[m
[31m -}[m
[31m -[m
[31m -############################[m
[31m -# Main program[m
[31m -############################[m
[31m -[m
[31m -$ProgressPreference = 'SilentlyContinue'[m
[31m -switch ($action) {[m
[31m -    "create" {[m
[31m -        if (!([String]::IsNullOrWhiteSpace($Identifier)) -and !([String]::IsNullOrWhiteSpace($RecordName)) -and !([String]::IsNullOrWhiteSpace($Token))) {[m
[31m -                $sess = onedotcom_login[m
[31m -                Add-DnsRecord $Identifier $RecordName $Token $Sess[m
[31m -        }[m
[31m -        else {[m
[31m -            Write-Error "Argument(s) Identifier, RecordName and/or Token were not applied!"[m
[31m -        }  [m
[31m -    }[m
[31m -    "delete" {[m
[31m -        if (!([String]::IsNullOrWhiteSpace($Identifier)) -and !([String]::IsNullOrWhiteSpace($RecordName)) -and !([String]::IsNullOrWhiteSpace($Token))) {[m
[31m -            $sess = onedotcom_login[m
[31m -            Remove-DnsRecord $Identifier $RecordName $Token $Sess[m
[31m -        }[m
[31m -        else {[m
[31m -            Write-Error "Argument(s) Identifier, RecordName and/or Token were not applied!"[m
[31m -        }    [m
[31m -    }[m
[31m -    "setcred" {[m
[31m -        EncryptCred[m
[31m -    }[m
[31m -    Default {[m
[31m -        Write-Error "No or wrong arguments were passed. Valid arguments are create, delete and setcred.`n[m
[31m -        Syntax:`n[m
[31m -        onedotcom.ps1 create <Identifier> <RecordName> <Token>`n[m
[31m -        onedotcom.ps1 delete <Identifier> <RecordName> <Token>`n[m
[31m -        onedotcom.ps1 setcred (Set the credentials for one.com)"[m
[31m -    }[m
[31m -    [m
[31m -}[m
[32m++<<<<<<< HEAD[m
[32m +<#[m
[32m +.SYNOPSIS[m
[32m +    Adds and deletes TXT record to your one.com domain with win-wacs.[m
[32m +.DESCRIPTION[m
[32m +    Works with win-wacs to add and delete TXT records for use with Let's encrypt certificates.[m
[32m +.NOTES[m
[32m +    File Name   : onedotcom.ps1[m
[32m +    Version     : 1.0 (Initial version)[m
[32m +    Author      : Morten Hansen[m
[32m +.LINK[m
[32m +    https://github.com/morhans/win-acme_dns_one.com[m
[32m +.EXAMPLE[m
[32m +    onedotcom.ps1 create <Identifier> <RecordName> <Token>[m
[32m +.EXAMPLE[m
[32m +    onedotcom.ps1 delete <Identifier> <RecordName> <Token>[m
[32m +.EXAMPLE[m
[32m +    onedotcom.ps1 setcred[m
[32m +#>[m
[32m +[m
[32m +[CmdletBinding()][m
[32m +    param([m
[32m +        [Parameter(Position=0)][m
[32m +        [string]$action,[m
[32m +        [Parameter(Position=1)][m
[32m +        [string]$Identifier,[m
[32m +        [Parameter(Position=2)][m
[32m +        [string]$RecordName,[m
[32m +        [Parameter(Position=3)][m
[32m +        [string]$Token[m
[32m +    )[m
[32m +[m
[32m +$global:apiRoot = 'https://www.one.com/admin'[m
[32m +[m
[32m +function Add-DnsRecord {[m
[32m +    [CmdletBinding()][m
[32m +    param([m
[32m +        [Parameter(Mandatory,Position=0)][m
[32m +        [string]$Identifier,[m
[32m +        [Parameter(Mandatory,Position=1)][m
[32m +        [string]$RecordName,[m
[32m +        [Parameter(Mandatory,Position=2)][m
[32m +        [string]$TxtValue,[m
[32m +        [Parameter(Mandatory,Position=3)][m
[32m +        [object]$LoginSession[m
[32m +    )[m
[32m +[m
[32m +    # add the new TXT record[m
[32m +    $topdomain = getTopDomain $Identifier[m
[32m +    $RecordName = $RecordName.Substring(0,$RecordName.Length-$topdomain.Length-1)[m
[32m +    $PostData = @{type="dns_custom_records";attributes=@{priority=0;ttl=600;type="TXT";prefix=$RecordName;content=$TxtValue}}|ConvertTo-Json[m
[32m +    $url = "$apiRoot/api/domains/$topdomain/dns/custom_records"[m
[32m +    Write-Debug $url[m
[32m +    Write-Verbose "Adding $RecordName with value $TxtValue to $Identifier"[m
[32m +    try {    [m
[32m +        $webrequest = Invoke-WebRequest -Uri $url -Body $PostData -WebSession $LoginSession -Method POST -UseBasicParsing -ContentType "application/json" -ErrorAction Stop[m
[32m +    }[m
[32m +    catch [System.Net.WebException] { [m
[32m +        Write-Verbose "An exception was caught: $($_.Exception.Message)"[m
[32m +        $_.Exception.Response[m
[32m +    }[m
[32m +    [m
[32m +    #Check if adding was a success[m
[32m +    $Result = ConvertFrom-Json $webrequest.content[m
[32m +    if ([String]::IsNullOrWhiteSpace($Result.result.data.id)) {[m
[32m +        throw "TXT record for $RecordName ws not added!"[m
[32m +    }[m
[32m +[m
[32m +   <#[m
[32m +    .SYNOPSIS[m
[32m +        Add a DNS TXT record to One.com.[m
[32m +    .DESCRIPTION[m
[32m +        Use One.com api to add a TXT record to a One.com DNS zone.[m
[32m +    .PARAMETER Identifier[m
[32m +        DNS name to be added a TXT record. [m
[32m +    .PARAMETER RecordName[m
[32m +        The fully qualified name of the TXT record.[m
[32m +    .PARAMETER TxtValue[m
[32m +        The value of the TXT record.[m
[32m +    .EXAMPLE[m
[32m +        Add-DnsRecord 'example.com' '_acme-challenge.site1' 'asdfqwer12345678' '$SessionID'[m
[32m +        Adds a TXT record for the specified site with the specified value.[m
[32m +    #>[m
[32m +}[m
[32m +[m
[32m +function Remove-DnsRecord {[m
[32m +    [CmdletBinding()][m
[32m +    param([m
[32m +        [Parameter(Mandatory,Position=0)][m
[32m +        [string]$Identifier,[m
[32m +        [Parameter(Mandatory,Position=1)][m
[32m +        [string]$RecordName,[m
[32m +        [Parameter(Mandatory,Position=2)][m
[32m +        [string]$TxtValue,[m
[32m +        [Parameter(Mandatory,Position=3)][m
[32m +        [object]$LoginSession[m
[32m +    )[m
[32m +    [m
[32m +    # check for an existing record[m
[32m +    $topdomain = getTopDomain $Identifier[m
[32m +    $RecordName = $RecordName.Substring(0,$RecordName.Length-$topdomain.Length-1)[m
[32m +    $RecId = Find-RecordId $topdomain $RecordName $TxtValue $LoginSession[m
[32m +    if ([String]::IsNullOrWhiteSpace($RecId)) {[m
[32m +        throw "Unable to find record id for $RecordName"[m
[32m +    }[m
[32m +[m
[32m +    # remove the txt record if it exists[m
[32m +    Write-Verbose "Removing $RecordName with value $TxtValue from $Identifier"[m
[32m +    $url = "$apiRoot/api/domains/$topdomain/dns/custom_records/$RecId"[m
[32m +    Write-Debug $url[m
[32m +    try {    [m
[32m +        $webrequest = Invoke-WebRequest -Uri $url -WebSession $LoginSession -Method DELETE -UseBasicParsing -ContentType "application/json" -ErrorAction Stop[m
[32m +    }[m
[32m +    catch [System.Net.WebException] { [m
[32m +        Write-Verbose "An exception was caught: $($_.Exception.Message)"[m
[32m +        $_.Exception.Response[m
[32m +    }[m
[32m +[m
[32m +    # Check if removal was a success[m
[32m +    if (!($webrequest.content -eq '{"result":null,"metadata":null}')) {[m
[32m +        throw "Unable to delete record $RecordName!"[m
[32m +    }[m
[32m +[m
[32m +    <#[m
[32m +    .SYNOPSIS[m
[32m +        Remove a DNS TXT record from One.com.[m
[32m +    .DESCRIPTION[m
[32m +        Use One.com api to remove a TXT record to a One.com DNS zone.[m
[32m +    .PARAMETER Identifier[m
[32m +        DNS name to have TXT record deleted.[m
[32m +    .PARAMETER RecordName[m
[32m +        The fully qualified name of the TXT record.[m
[32m +    .PARAMETER TxtValue[m
[32m +        The value of the TXT record.[m
[32m +    .EXAMPLE[m
[32m +        Remove-DnsRecord Example 'example.com' '_acme-challenge.site1' 'asdfqwer12345678' '$SessionID'[m
[32m +        Removes a TXT record for the specified site with the specified value.[m
[32m +    #>[m
[32m +[m
[32m +}[m
[32m +[m
[32m +function EncryptCred {[m
[32m +    [m
[32m +    #Ask for credentials[m
[32m +    $Credential = Get-Credential -Message "Login and password for One.com"[m
[32m +[m
[32m +    #Save credentials[m
[32m +    $Credential | Export-CliXml -Path "${env:\userprofile}\One.com.dat"[m
[32m +[m
[32m +    <#[m
[32m +    .SYNOPSIS[m
[32m +        Saves One.com credentials to file.[m
[32m +    .DESCRIPTION[m
[32m +        Encrypt credentials to use on One.com login. Credentials is only readable by the creating user.[m
[32m +    #>[m
[32m +[m
[32m +}[m
[32m +[m
[32m +[m
[32m +############################[m
[32m +# Helper Functions[m
[32m +############################[m
[32m +[m
[32m +function getTopDomain {[m
[32m +    [CmdletBinding()][m
[32m +    param([m
[32m +        [Parameter(Mandatory,Position=0)][m
[32m +        [string]$Identifier[m
[32m +    )[m
[32m +    [m
[32m +    $pieces = $Identifier.Split(".")[m
[32m +    for ($i=1; $i -lt ($pieces.Count-1); $i++) {[m
[32m +        $topdomain = "$( $pieces[$i..($pieces.Count-1)] -join '.' )"[m
[32m +    }[m
[32m +    if (([String]::IsNullOrWhiteSpace($topdomain))) {[m
[32m +        $topdomain = $Identifier[m
[32m +    }[m
[32m +[m
[32m +    return $topdomain[m
[32m +}[m
[32m +function getCustomRecords {[m
[32m +    [CmdletBinding()][m
[32m +    param([m
[32m +        [Parameter(Mandatory,Position=0)][m
[32m +        [string]$Identifier,[m
[32m +        [Parameter(Mandatory,Position=1)][m
[32m +        [object]$LoginSess[m
[32m +    )[m
[32m +    [m
[32m +    $url = "$apiroot/api/domains/$topdomain/dns/custom_records"[m
[32m +    Write-Debug $url[m
[32m +    try {        [m
[32m +        $webrequest = Invoke-WebRequest -Uri $url -Method Default -WebSession $LoginSess -UseBasicParsing -ErrorAction Stop[m
[32m +    }[m
[32m +    catch [System.Net.WebException] { [m
[32m +        Write-Verbose "An exception was caught: $($_.Exception.Message)"[m
[32m +        $_.Exception.Response[m
[32m +    } [m
[32m +    $jsonObj = ConvertFrom-Json $webrequest.content[m
[32m +    return $jsonObj.result.data[m
[32m +}[m
[32m +[m
[32m +function Find-RecordId {[m
[32m +    [CmdletBinding()][m
[32m +    param([m
[32m +        [Parameter(Mandatory,Position=0)][m
[32m +        [string]$Identifier,[m
[32m +        [Parameter(Mandatory,Position=1)][m
[32m +        [string]$RecordName,[m
[32m +        [Parameter(Mandatory,Position=2)][m
[32m +        [object]$TxtValue,[m
[32m +        [Parameter(Mandatory,Position=3)][m
[32m +        [object]$LoginSess[m
[32m +    )[m
[32m +[m
[32m +    $RecObj = getCustomRecords $Identifier $LoginSess  [m
[32m +        [m
[32m +    ForEach($rec in $RecObj) {[m
[32m +        if ($rec.attributes.prefix -eq $RecordName -and $rec.attributes.content -eq $TxtValue -and $rec.attributes.type -eq "TXT") {[m
[32m +            $RecId = $rec.id[m
[32m +        }[m
[32m +         [m
[32m +    }[m
[32m +    Write-Debug "ID (Empty if not found): $RecId"[m
[32m +    return $RecId[m
[32m +}[m
[32m +[m
[32m +function DecryptCred {[m
[32m +[m
[32m +    if (!(Test-Path "${env:\userprofile}\One.com.dat"))  {[m
[32m +        throw "Login and password not set (run with option setcred to set them."[m
[32m +    }[m
[32m +[m
[32m +    $Credential = Import-CliXml -Path "${env:\userprofile}\One.com.dat"[m
[32m +[m
[32m +[m
[32m +    return $Credential[m
[32m +}[m
[32m +[m
[32m +function onedotcom_login {[m
[32m +[m
[32m +    $SearchString = '<form id="kc-form-login" class="Login-form login autofill" onsubmit="login.disabled = true; return true;" action="'[m
[32m +[m
[32m +    $odcCred = DecryptCred[m
[32m +[m
[32m +    $usr = $odcCred.UserName[m
[32m +    $pwd = $odcCred.GetNetworkCredential().Password[m
[32m +    [m
[32m +    if (([String]::IsNullOrWhiteSpace($usr)) -or ([String]::IsNullOrWhiteSpace($pwd)))  {[m
[32m +        throw "Login and/or password are not set correctly. Reissue with option setcred"[m
[32m +    }[m
[32m +[m
[32m +    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12[m
[32m +   [m
[32m +    try {[m
[32m +        $webrequest = Invoke-WebRequest -Uri $apiRoot -Method Default -SessionVariable websession -UseBasicParsing -ErrorAction Stop[m
[32m +        $pos = $webrequest.content.LastIndexOf($SearchString) + $SearchString.Length [m
[32m +        $resulttxt = $webrequest.content.Substring($pos)[m
[32m +    }[m
[32m +    catch [System.Net.WebException] { [m
[32m +        Write-Verbose "An exception was caught: $($_.Exception.Message)"[m
[32m +        $_.Exception.Response[m
[32m +    }[m
[32m +[m
[32m +    try { [m
[32m +        $pos = $resulttxt.IndexOf('"')[m
[32m +        $LoginUrl = $resulttxt.Substring(0, $pos)[m
[32m +        $LoginUrl = $LoginUrl.replace('&amp;','&')[m
[32m +        $formFields = @{username=$usr;password=$pwd;credentialId=''}[m
[32m +[m
[32m +        $webrequest = Invoke-WebRequest -Uri $LoginUrl -Body $formFields -WebSession $websession -Method POST -UseBasicParsing -ErrorAction Stop[m
[32m +    }[m
[32m +    catch [System.Net.WebException] { [m
[32m +        Write-Verbose "An exception was caught: $($_.Exception.Message)"[m
[32m +        $_.Exception.Response[m
[32m +    }[m
[32m +    Remove-Variable usr, pwd[m
[32m +[m
[32m +    return $websession[m
[32m +}[m
[32m +[m
[32m +############################[m
[32m +# Main program[m
[32m +############################[m
[32m +[m
[32m +$ProgressPreference = 'SilentlyContinue'[m
[32m +switch ($action) {[m
[32m +    "create" {[m
[32m +        if (!([String]::IsNullOrWhiteSpace($Identifier)) -and !([String]::IsNullOrWhiteSpace($RecordName)) -and !([String]::IsNullOrWhiteSpace($Token))) {[m
[32m +                $sess = onedotcom_login[m
[32m +                Add-DnsRecord $Identifier $RecordName $Token $Sess[m
[32m +        }[m
[32m +        else {[m
[32m +            Write-Error "Argument(s) Identifier, RecordName and/or Token were not applied!"[m
[32m +        }  [m
[32m +    }[m
[32m +    "delete" {[m
[32m +        if (!([String]::IsNullOrWhiteSpace($Identifier)) -and !([String]::IsNullOrWhiteSpace($RecordName)) -and !([String]::IsNullOrWhiteSpace($Token))) {[m
[32m +            $sess = onedotcom_login[m
[32m +            Remove-DnsRecord $Identifier $RecordName $Token $Sess[m
[32m +        }[m
[32m +        else {[m
[32m +            Write-Error "Argument(s) Identifier, RecordName and/or Token were not applied!"[m
[32m +        }    [m
[32m +    }[m
[32m +    "setcred" {[m
[32m +        EncryptCred[m
[32m +    }[m
[32m +    Default {[m
[32m +        Write-Error "No or wrong arguments were passed. Valid arguments are create, delete and setcred.`n[m
[32m +        Syntax:`n[m
[32m +        onedotcom.ps1 create <Identifier> <RecordName> <Token>`n[m
[32m +        onedotcom.ps1 delete <Identifier> <RecordName> <Token>`n[m
[32m +        onedotcom.ps1 setcred (Set the credentials for one.com)"[m
[32m +    }[m
[32m +    [m
[31m- }[m
[32m++}[m
[32m++=======[m
[32m++<#[m
[32m++.SYNOPSIS[m
[32m++    Adds and deletes TXT record to your one.com domain with win-wacs.[m
[32m++.DESCRIPTION[m
[32m++    Works with win-wacs to add and delete TXT records for use with Let's encrypt certificates.[m
[32m++.NOTES[m
[32m++    File Name   : onedotcom.ps1[m
[32m++    Version     : 1.0 (Initial version)[m
[32m++    Author      : Morten Hansen[m
[32m++.LINK[m
[32m++    https://github.com/morhans/win-acme_dns_one.com[m
[32m++.EXAMPLE[m
[32m++    onedotcom.ps1 create <Identifier> <RecordName> <Token>[m
[32m++.EXAMPLE[m
[32m++    onedotcom.ps1 delete <Identifier> <RecordName> <Token>[m
[32m++.EXAMPLE[m
[32m++    onedotcom.ps1 setcred[m
[32m++#>[m
[32m++[m
[32m++[CmdletBinding()][m
[32m++    param([m
[32m++        [Parameter(Position=0)][m
[32m++        [string]$action,[m
[32m++        [Parameter(Position=1)][m
[32m++        [string]$Identifier,[m
[32m++        [Parameter(Position=2)][m
[32m++        [string]$RecordName,[m
[32m++        [Parameter(Position=3)][m
[32m++        [string]$Token[m
[32m++    )[m
[32m++[m
[32m++$global:apiRoot = 'https://www.one.com/admin'[m
[32m++[m
[32m++function Add-DnsRecord {[m
[32m++    [CmdletBinding()][m
[32m++    param([m
[32m++        [Parameter(Mandatory,Position=0)][m
[32m++        [string]$Identifier,[m
[32m++        [Parameter(Mandatory,Position=1)][m
[32m++        [string]$RecordName,[m
[32m++        [Parameter(Mandatory,Position=2)][m
[32m++        [string]$TxtValue,[m
[32m++        [Parameter(Mandatory,Position=3)][m
[32m++        [object]$LoginSession[m
[32m++    )[m
[32m++[m
[32m++    # add the new TXT record[m
[32m++    $topdomain = getTopDomain $Identifier[m
[32m++    $RecordName = $RecordName.Substring(0,$RecordName.Length-$topdomain.Length-1)[m
[32m++    $PostData = @{type="dns_custom_records";attributes=@{priority=0;ttl=600;type="TXT";prefix=$RecordName;content=$TxtValue}}|ConvertTo-Json[m
[32m++    $url = "$apiRoot/api/domains/$topdomain/dns/custom_records"[m
[32m++    Write-Debug $url[m
[32m++    Write-Verbose "Adding $RecordName with value $TxtValue to $Identifier"[m
[32m++    try {    [m
[32m++        $webrequest = Invoke-WebRequest -Uri $url -Body $PostData -WebSession $LoginSession -Method POST -UseBasicParsing -ContentType "application/json" -ErrorAction Stop[m
[32m++    }[m
[32m++    catch [System.Net.WebException] { [m
[32m++        Write-Verbose "An exception was caught: $($_.Exception.Message)"[m
[32m++        $_.Exception.Response[m
[32m++    }[m
[32m++    [m
[32m++    #Check if adding was a success[m
[32m++    $Result = ConvertFrom-Json $webrequest.content[m
[32m++    if ([String]::IsNullOrWhiteSpace($Result.result.data.id)) {[m
[32m++        throw "TXT record for $RecordName ws not added!"[m
[32m++    }[m
[32m++[m
[32m++   <#[m
[32m++    .SYNOPSIS[m
[32m++        Add a DNS TXT record to One.com.[m
[32m++    .DESCRIPTION[m
[32m++        Use One.com api to add a TXT record to a One.com DNS zone.[m
[32m++    .PARAMETER Identifier[m
[32m++        DNS name to be added a TXT record. [m
[32m++    .PARAMETER RecordName[m
[32m++        The fully qualified name of the TXT record.[m
[32m++    .PARAMETER TxtValue[m
[32m++        The value of the TXT record.[m
[32m++    .EXAMPLE[m
[32m++        Add-DnsRecord 'example.com' '_acme-challenge.site1' 'asdfqwer12345678' '$SessionID'[m
[32m++        Adds a TXT record for the specified site with the specified value.[m
[32m++    #>[m
[32m++}[m
[32m++[m
[32m++function Remove-DnsRecord {[m
[32m++    [CmdletBinding()][m
[32m++    param([m
[32m++        [Parameter(Mandatory,Position=0)][m
[32m++        [string]$Identifier,[m
[32m++        [Parameter(Mandatory,Position=1)][m
[32m++        [string]$RecordName,[m
[32m++        [Parameter(Mandatory,Position=2)][m
[32m++        [string]$TxtValue,[m
[32m++        [Parameter(Mandatory,Position=3)][m
[32m++        [object]$LoginSession[m
[32m++    )[m
[32m++    [m
[32m++    # check for an existing record[m
[32m++    $topdomain = getTopDomain $Identifier[m
[32m++    $RecordName = $RecordName.Substring(0,$RecordName.Length-$topdomain.Length-1)[m
[32m++    $RecId = Find-RecordId $topdomain $RecordName $TxtValue $LoginSession[m
[32m++    if ([String]::IsNullOrWhiteSpace($RecId)) {[m
[32m++        throw "Unable to find record id for $RecordName"[m
[32m++    }[m
[32m++[m
[32m++    # remove the txt record if it exists[m
[32m++    Write-Verbose "Removing $RecordName with value $TxtValue from $Identifier"[m
[32m++    $url = "$apiRoot/api/domains/$topdomain/dns/custom_records/$RecId"[m
[32m++    Write-Debug $url[m
[32m++    try {    [m
[32m++        $webrequest = Invoke-WebRequest -Uri $url -WebSession $LoginSession -Method DELETE -UseBasicParsing -ContentType "application/json" -ErrorAction Stop[m
[32m++    }[m
[32m++    catch [System.Net.WebException] { [m
[32m++        Write-Verbose "An exception was caught: $($_.Exception.Message)"[m
[32m++        $_.Exception.Response[m
[32m++    }[m
[32m++[m
[32m++    # Check if removal was a success[m
[32m++    if (!($webrequest.content -eq '{"result":null,"metadata":null}')) {[m
[32m++        throw "Unable to delete record $RecordName!"[m
[32m++    }[m
[32m++[m
[32m++    <#[m
[32m++    .SYNOPSIS[m
[32m++        Remove a DNS TXT record from One.com.[m
[32m++    .DESCRIPTION[m
[32m++        Use One.com api to remove a TXT record to a One.com DNS zone.[m
[32m++    .PARAMETER Identifier[m
[32m++        DNS name to have TXT record deleted.[m
[32m++    .PARAMETER RecordName[m
[32m++        The fully qualified name of the TXT record.[m
[32m++    .PARAMETER TxtValue[m
[32m++        The value of the TXT record.[m
[32m++    .EXAMPLE[m
[32m++        Remove-DnsRecord Example 'example.com' '_acme-challenge.site1' 'asdfqwer12345678' '$SessionID'[m
[32m++        Removes a TXT record for the specified site with the specified value.[m
[32m++    #>[m
[32m++[m
[32m++}[m
[32m++[m
[32m++function EncryptCred {[m
[32m++    [m
[32m++    #Ask for credentials[m
[32m++    $Credential = Get-Credential -Message "Login and password for One.com"[m
[32m++[m
[32m++    #Save credentials[m
[32m++    $Credential | Export-CliXml -Path "${env:\userprofile}\One.com.dat"[m
[32m++[m
[32m++    <#[m
[32m++    .SYNOPSIS[m
[32m++        Saves One.com credentials to file.[m
[32m++    .DESCRIPTION[m
[32m++        Encrypt credentials to use on One.com login. Credentials is only readable by the creating user.[m
[32m++    #>[m
[32m++[m
[32m++}[m
[32m++[m
[32m++[m
[32m++############################[m
[32m++# Helper Functions[m
[32m++############################[m
[32m++[m
[32m++function getTopDomain {[m
[32m++    [CmdletBinding()][m
[32m++    param([m
[32m++        [Parameter(Mandatory,Position=0)][m
[32m++        [string]$Identifier[m
[32m++    )[m
[32m++    [m
[32m++    $pieces = $Identifier.Split(".")[m
[32m++    for ($i=1; $i -lt ($pieces.Count-1); $i++) {[m
[32m++        $topdomain = "$( $pieces[$i..($pieces.Count-1)] -join '.' )"[m
[32m++    }[m
[32m++    if (([String]::IsNullOrWhiteSpace($topdomain))) {[m
[32m++        $topdomain = $Identifier[m
[32m++    }[m
[32m++[m
[32m++    return $topdomain[m
[32m++}[m
[32m++function getCustomRecords {[m
[32m++    [CmdletBinding()][m
[32m++    param([m
[32m++        [Parameter(Mandatory,Position=0)][m
[32m++        [string]$Identifier,[m
[32m++        [Parameter(Mandatory,Position=1)][m
[32m++        [object]$LoginSess[m
[32m++    )[m
[32m++    [m
[32m++    $url = "$apiroot/api/domains/$topdomain/dns/custom_records"[m
[32m++    Write-Debug $url[m
[32m++    try {        [m
[32m++        $webrequest = Invoke-WebRequest -Uri $url -Method Default -WebSession $LoginSess -UseBasicParsing -ErrorAction Stop[m
[32m++    }[m
[32m++    catch [System.Net.WebException] { [m
[32m++        Write-Verbose "An exception was caught: $($_.Exception.Message)"[m
[32m++        $_.Exception.Response[m
[32m++    } [m
[32m++    $jsonObj = ConvertFrom-Json $webrequest.content[m
[32m++    return $jsonObj.result.data[m
[32m++}[m
[32m++[m
[32m++function Find-RecordId {[m
[32m++    [CmdletBinding()][m
[32m++    param([m
[32m++        [Parameter(Mandatory,Position=0)][m
[32m++        [string]$Identifier,[m
[32m++        [Parameter(Mandatory,Position=1)][m
[32m++        [string]$RecordName,[m
[32m++        [Parameter(Mandatory,Position=2)][m
[32m++        [object]$TxtValue,[m
[32m++        [Parameter(Mandatory,Position=3)][m
[32m++        [object]$LoginSess[m
[32m++    )[m
[32m++[m
[32m++    $RecObj = getCustomRecords $Identifier $LoginSess  [m
[32m++        [m
[32m++    ForEach($rec in $RecObj) {[m
[32m++        if ($rec.attributes.prefix -eq $RecordName -and $rec.attributes.content -eq $TxtValue -and $rec.attributes.type -eq "TXT") {[m
[32m++            $RecId = $rec.id[m
[32m++        }[m
[32m++         [m
[32m++    }[m
[32m++    Write-Debug "ID (Empty if not found): $RecId"[m
[32m++    return $RecId[m
[32m++}[m
[32m++[m
[32m++function DecryptCred {[m
[32m++[m
[32m++    if (!(Test-Path "${env:\userprofile}\One.com.dat"))  {[m
[32m++        throw "Login and password not set (run with option setcred to set them."[m
[32m++    }[m
[32m++[m
[32m++    $Credential = Import-CliXml -Path "${env:\userprofile}\One.com.dat"[m
[32m++[m
[32m++[m
[32m++    return $Credential[m
[32m++}[m
[32m++[m
[32m++function onedotcom_login {[m
[32m++[m
[32m++    $SearchString = '<form id="kc-form-login" class="Login-form login autofill" onsubmit="login.disabled = true; return true;" action="'[m
[32m++[m
[32m++    $odcCred = DecryptCred[m
[32m++[m
[32m++    $usr = $odcCred.UserName[m
[32m++    $pwd = $odcCred.GetNetworkCredential().Password[m
[32m++    [m
[32m++    if (([String]::IsNullOrWhiteSpace($usr)) -or ([String]::IsNullOrWhiteSpace($pwd)))  {[m
[32m++        throw "Login and/or password are not set correctly. Reissue with option setcred"[m
[32m++    }[m
[32m++[m
[32m++    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12[m
[32m++   [m
[32m++    try {[m
[32m++        $webrequest = Invoke-WebRequest -Uri $apiRoot -Method Default -SessionVariable websession -UseBasicParsing -ErrorAction Stop[m
[32m++        $pos = $webrequest.content.LastIndexOf($SearchString) + $SearchString.Length [m
[32m++        $resulttxt = $webrequest.content.Substring($pos)[m
[32m++    }[m
[32m++    catch [System.Net.WebException] { [m
[32m++        Write-Verbose "An exception was caught: $($_.Exception.Message)"[m
[32m++        $_.Exception.Response[m
[32m++    }[m
[32m++[m
[32m++    try { [m
[32m++        $pos = $resulttxt.IndexOf('"')[m
[32m++        $LoginUrl = $resulttxt.Substring(0, $pos)[m
[32m++        $LoginUrl = $LoginUrl.replace('&amp;','&')[m
[32m++        $formFields = @{username=$usr;password=$pwd;credentialId=''}[m
[32m++[m
[32m++        $webrequest = Invoke-WebRequest -Uri $LoginUrl -Body $formFields -WebSession $websession -Method POST -UseBasicParsing -ErrorAction Stop[m
[32m++    }[m
[32m++    catch [System.Net.WebException] { [m
[32m++        Write-Verbose "An exception was caught: $($_.Exception.Message)"[m
[32m++        $_.Exception.Response[m
[32m++    }[m
[32m++    Remove-Variable usr, pwd[m
[32m++[m
[32m++    return $websession[m
[32m++}[m
[32m++[m
[32m++############################[m
[32m++# Main program[m
[32m++############################[m
[32m++[m
[32m++$ProgressPreference = 'SilentlyContinue'[m
[32m++switch ($action) {[m
[32m++    "create" {[m
[32m++        if (!([String]::IsNullOrWhiteSpace($Identifier)) -and !([String]::IsNullOrWhiteSpace($RecordName)) -and !([String]::IsNullOrWhiteSpace($Token))) {[m
[32m++                $sess = onedotcom_login[m
[32m++                Add-DnsRecord $Identifier $RecordName $Token $Sess[m
[32m++        }[m
[32m++        else {[m
[32m++            Write-Error "Argument(s) Identifier, RecordName and/or Token were not applied!"[m
[32m++        }  [m
[32m++    }[m
[32m++    "delete" {[m
[32m++        if (!([String]::IsNullOrWhiteSpace($Identifier)) -and !([String]::IsNullOrWhiteSpace($RecordName)) -and !([String]::IsNullOrWhiteSpace($Token))) {[m
[32m++            $sess = onedotcom_login[m
[32m++            Remove-DnsRecord $Identifier $RecordName $Token $Sess[m
[32m++        }[m
[32m++        else {[m
[32m++            Write-Error "Argument(s) Identifier, RecordName and/or Token were not applied!"[m
[32m++        }    [m
[32m++    }[m
[32m++    "setcred" {[m
[32m++        EncryptCred[m
[32m++    }[m
[32m++    Default {[m
[32m++        Write-Error "No or wrong arguments were passed. Valid arguments are create, delete and setcred.`n[m
[32m++        Syntax:`n[m
[32m++        onedotcom.ps1 create <Identifier> <RecordName> <Token>`n[m
[32m++        onedotcom.ps1 delete <Identifier> <RecordName> <Token>`n[m
[32m++        onedotcom.ps1 setcred (Set the credentials for one.com)"[m
[32m++    }[m
[32m++    [m
[32m++}[m
[32m++>>>>>>> 11e45d70f6c9c1f662d5972a384561ad25c02407[m
