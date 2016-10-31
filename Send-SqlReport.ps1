﻿<#
.Synopsis
    Execute a SQL statement and email the results.

.Parameter Subject
    The email subject.

.Parameter To
    The email address(es) to send the results to.

.Parameter Sql
    The SQL statement to execute.

.Parameter ServerInstance
    The name of a server (and optional instance) to connect and use for the query.

.Parameter Database
    The the database to connect to on the server.

.Parameter ConnectionString
    Specifies a connection string to connect to the server.

.Parameter ConnectionName
    The connection string name from the ConfigurationManager to use when executing the query.

.Parameter From
    The from address to use for the email.
    The default is to use $PSEmailServer.
    If that is missing, it will be populated by the value from the 
    configuration value:

    <system.net>
      <mailSettings>
        <smtp from="source@example.org" deliveryMethod="network">
          <network host="mail.example.org" enableSsl="true" />
        </smtp>
      </mailSettings>
    </system.net>

    (If enableSsl is set to true, SSL will be used to send the report.)

.Parameter Timeout
    The timeout to use for the query, in seconds. The default is 90.

.Parameter PreContent
    HTML content to insert into the email before the query results.

.Parameter PostContent
    HTML content to insert into the email after the query results.

.Parameter Cc
    The email address(es) to CC the results to.

.Parameter Bcc
    The email address(es) to BCC the results to.

.Parameter Priority
    The priority of the email, one of: High, Low, Normal

.Parameter UseSsl
    Indicates that SSL should be used when sending the message.

    (See the From parameter for an alternate SSL flag.)

.Link
    Send-MailMessage
#>

#Requires -Version 3
#Requires -Module SqlServer
[CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact='None')] Param(
[Parameter(Position=0,Mandatory=$true)][string]$Subject,
[Parameter(Position=1,Mandatory=$true)][string[]]$To,
[Parameter(Position=2,Mandatory=$true)][string]$Sql,
[Parameter(ParameterSetName='ByConnectionParameters',Position=3,Mandatory=$true)][string]$ServerInstance,
[Parameter(ParameterSetName='ByConnectionParameters',Position=4,Mandatory=$true)][string]$Database,
[Parameter(ParameterSetName='ByConnectionString',Position=3,Mandatory=$true)][string]$ConnectionString,
[Parameter(ParameterSetName='ByConnectionName',Position=3,Mandatory=$true)][string]$ConnectionName,
[string]$From,
[int]$Timeout= 90,
[string]$PreContent= ' ',
[string]$PostContent= ' ',
[string[]]$Cc,
[string[]]$Bcc,
[Net.Mail.MailPriority]$Priority,
[switch]$UseSsl,
[uri]$SeqUrl = 'https://seqlog/'
)

Use-SeqServer.ps1 $SeqUrl
Use-NetMailConfig.ps1

# use the default From host for emails without a host
$mailhost = ([Net.Mail.MailAddress]$PSDefaultParameterValues['Send-MailMessage:From']).Host |Out-String
if($mailhost)
{
    $To = $To |% { if($_ -like '*@*'){$_}else{"$_@$mailhost"} } # allow username-only emails
    $Cc = $Cc |% { if($_ -like '*@*'){$_}elseif($_){"$_@$mailhost"} } # allow username-only emails
    if($Bcc) { $Bcc = $Bcc |% { if($_ -like '*@*'){$_}else{"$_@$mailhost"} } } # allow username-only emails
}

try
{
    $query = @{ Query = $Sql }
    switch($PSCmdlet.ParameterSetName)
    {
        ByConnectionParameters {$query += @{ServerInstance=$ServerInstance;Database=$Database}}
        ByConnectionString     {$query += @{ConnectionString=$ConnectionString}}
        ByConnectionName
        {
            try{[void][Configuration.ConfigurationManager]}catch{Add-Type -as System.Configuration} # get access to the config connection strings
            $query += @{ConnectionString=[Configuration.ConfigurationManager]::ConnectionStrings[$ConnectionName].ConnectionString}
        }
    }
    if($Timeout) {$query += @{QueryTimeout=$Timeout}}
    [Data.DataRow[]]$data = Invoke-Sqlcmd @query
    $data |Format-Table |Out-String |Write-Verbose
    if($data.Count -eq 0) # no rows
    {
        Write-Verbose "No rows returned."
        Write-EventLog -LogName Application -Source Reporting -EventId 100 -Message "No rows returned for $Subject"
    }
    else
    { # convert the table into HTML (select away the add'l properties the DataTable adds), add some Outlook 2007-compat CSS, email it
        $odd = $false
        $body = ($data |
            select ($data[0].Table.Columns |% ColumnName) |
            ConvertTo-Html -PreContent $PreContent -PostContent $PostContent -Head '<style type="text/css">th,td {padding:2px 1ex 0 2px}</style>' |
            % {if($odd=!$odd){$_ -replace '^<tr>','<tr style="background:#EEE">'}else{$_}} |
            % {$_ -replace '<td>(\d+(\.\d+)?)</td>','<td align="right">$1</td>'} |
            Out-String) -replace '<table>','<table cellpadding="2" cellspacing="0" style="font:x-small ''Lucida Console'',monospace">'
        $Msg = @{
            To         = $To
            Subject    = $Subject
            BodyAsHtml = $true
            SmtpServer = $PSEmailServer
            Body       = $body
        }
        if($From)     { $Msg.From= $From }
        if($Cc)       { $Msg.Cc= $Cc }
        if($Bcc)      { $Msg.Bcc= $Bcc }
        if($Priority) { $Msg.Priority= $Priority }
        if($UseSsl)   { $Msg.UseSsl = $true }
        if($PSCmdlet.ShouldProcess("Message:`n$(New-Object PSObject -Property $Msg|Format-List|Out-String)`n",'Send message'))
        { Send-MailMessage @Msg } # splat the arguments hashtable
    }
}
catch # report problems
{
    Write-Warning $_
    Write-EventLog -LogName Application -Source Reporting -EventId 99 -EntryType Error -Message $_
    if($SeqUrl) { Send-SeqScriptEvent.ps1 'Reporting' $_ Error -InvocationScope 2 }
    # consciously omitting Cc & Bcc
    $Msg = @{
        To         = $To
        Subject    = "$Subject [Error]"
        BodyAsHtml = $false
        SmtpServer = $PSEmailServer
        Body       = $_
    }
    if($From) { $Msg.From= $From }
    if($Priority) { $Msg.Priority= $Priority }
    if($PSCmdlet.ShouldProcess("Message:`n$(New-Object PSObject -Property $Msg|Format-List|Out-String)`n",'Send message'))
    { Send-MailMessage @Msg }
}
