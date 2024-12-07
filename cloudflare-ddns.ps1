#import logging function
. ./logging.ps1
$DATE = Get-Date -UFormat "%Y/%m/%d %H:%M:%S"

$api_base_url = "https://api.cloudflare.com/client/v4/zones/{0}"
$cloudflare_headers = @{"Authorization" = "Bearer {0}"; "Content-Type" = "application/json" }
Write-Log "----$DATE----" 
Write-Log "Starting Cloudflare DNS record updates"
Write-Log "****************************************************************"

## Cloudflare's Zone ID
$zone_id = "REPLACE BEFORE RUNNING"
## Cloudflare Zone API Token
$zone_api_token = "REPLACE BEFORE RUNNING"

$base_url = $api_base_url -f $zone_id
$headers = $cloudflare_headers.Clone()
$headers.Authorization = $headers.Authorization -f $zone_api_token
## REPLACE ALL THE subdomain.domain.tld FIELDS TO WHATEVER YOU ARE USING

## pulling cloudflare records for Type A ipv4 address
$list_records_request = @{
        Uri     = "$base_url/dns_records?name=$("subdomain.domain.tld")&type=A"
        Headers = $headers
    }
$response = Invoke-RestMethod @list_records_request
$cloudflareip = $response.result.content
Write-Log "Cloudflare IP: $cloudflareip"
$record_id = $response.result[0].id
$vpnip = & "C:\Program Files\Private Internet Access\piactl.exe" get vpnip
Write-Log "VPN IP: $vpnip"
if ($cloudflareip -ne $vpnip){
	$body = @{
        "type"    = "A"
        "name"    = "subdomain.domain.tld"
        "content" = $vpnip
      }
	$cloudflare_request_uri = "$base_url/dns_records"
	$cloudflare_request_uri += "/$record_id"
	$cloudflare_request_method = 'PATCH'
    $cloudflare_request = @{
        Uri     = $cloudflare_request_uri
        Method  = $cloudflare_request_method
        Headers = $headers
		Body    = $body | ConvertTo-Json
    }
    $update_response = Invoke-RestMethod @cloudflare_request
	if ($update_response.success){
		Write-Log "IP Updated to $vpnip"
	}
} else {
	Write-Log "IP Not Updated"
}

Write-Log "****************************************************************"

## pulling cloudflare records for Type SRV port
$list_records_request = @{
        Uri     = "$base_url/dns_records?name=$("_minecraft._tcp.subdomain.domain.tld")&type=SRV"
        Headers = $headers
    }
$response2 = Invoke-RestMethod @list_records_request
$cloudflareport = $response2.result.data.port
Write-Log "Cloudflare Port: $cloudflareport"
$record_id2 = $response2.result[0].id
$vpnport = & "C:\Program Files\Private Internet Access\piactl.exe" get portforward
Write-Log "VPN Port: $vpnport" 
if ($cloudflareport -ne $vpnport) {
	$body = @{
        "type" = "SRV"
        "name" = "_minecraft._tcp.subdomain.domain.tld"
        "data" = @{port = $vpnport}
      }
	$cloudflare_request_uri = "$base_url/dns_records"
	$cloudflare_request_uri += "/$record_id2"
	$cloudflare_request_method = 'PATCH'
    $cloudflare_request = @{
        Uri     = $cloudflare_request_uri
        Method  = $cloudflare_request_method
        Headers = $headers
		Body    = $body | ConvertTo-Json
    }
    $update_response2 = Invoke-RestMethod @cloudflare_request
	if ($update_response2.success){
		Write-Log "Port Updated to $vpnport"
		## assuming you're using wireguard if not then you need to figure out what the network adapter would be named
	        $localipv4 = (-split (netsh interface ip show config name="wgpia" | findstr "IP Address"))[2]
	 	## this is setting up local port redirects which wont actually work unless you have windows network firewall allows
		netsh interface portproxy delete v4tov4 listenport=$cloudflareport listenaddress=$localipv4
		netsh interface portproxy add v4tov4 listenport=$vpnport listenaddress=$localipv4 connectport=25565 connectaddress=localhost
	}
} else {
	Write-Log "Port Not Updated"
}
