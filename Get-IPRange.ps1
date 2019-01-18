function Get-IPrange {
    <#
    .SYNOPSIS
    Get the IP addresses in a range
    .EXAMPLE
    Get-IPrange 192.168.1.0/24
    .EXAMPLE
    Get-IPrange 192.168.1.0/24 -ListAll
    .EXAMPLE
    Get-IPrange -IP 192.168.1.0 -Mask 255.255.255.0
    .EXAMPLE
    Get-IPrange -IP 192.168.1.0 -CDIR 24
    #>

    param (
        [Parameter(ParameterSetName="IP and CDIR",Mandatory=$true,Position=1,ValueFromPipeline=$True)]
        [ValidateScript({
            $Parts = $_.Split("/")
            if ($Parts.Count -ne 2) {
                throw New-Object FormatException("Invalid Format.")
            } else {
                if (Test-IPAddressString ($Parts[0])) {
                    if ([int32]::TryParse($Parts[1], [ref]$Parts[1])) {
                        if ($Parts[1] -ge 1 -and $Parts[1] -le 32) {
                            return $true
                        } else {
                            throw New-Object FormatException("Invalid Format.")
                        }
                    } else {
                        throw New-Object FormatException("Invalid Format.")
                    }
                } else {
                    throw New-Object FormatException("Invalid Format.")
                }
            }})]
        [string]$IPAndCDIR,

        [Parameter(ParameterSetName="Net Mask",Mandatory=$true,ValueFromPipeline=$false)]
        [Parameter(ParameterSetName="CIDR",Mandatory=$true,ValueFromPipeline=$false)]
        [ValidateScript({ return Test-IPAddressString $_ })]
        [string]$IP,

        [Parameter(ParameterSetName="Net Mask",Mandatory=$true,ValueFromPipeline=$false)]
        [ValidateScript({
            $SubnetValues = "(0)|(128)|(192)|(224)|(240)|(248)|(252)|(254)"
            if ($_ -match "(^($SubnetValues).0.0.0$)|(^255.($SubnetValues).0.0$)|(^255.255.($SubnetValues).0$)|(^255.255.255.($SubnetValues|(255))$)") {
                return $true
            } else {
                throw New-Object FormatException("Invalid Subnet Mask Format.")
            }
        })]
        [string]$Mask,

        [Parameter(ParameterSetName="CIDR",Mandatory=$true,ValueFromPipeline=$false)]
        [ValidateRange(1, 32)]
        [int]$CDIR,
        
        [Parameter(ParameterSetName="IP and CDIR",Mandatory=$false,Position=2,ValueFromPipeline=$false)]
        [Parameter(ParameterSetName="Net Mask",Mandatory=$false,ValueFromPipeline=$false)]
        [Parameter(ParameterSetName="CIDR",Mandatory=$false,ValueFromPipeline=$false)]
        [switch]$ListAll
    )

    function Convert-IPAddressStringToInt64 {
        param ([string]$IP)
        
        $Parts = $IP.split(".")
        return [Int64]([Int64]$Parts[0] * 16777216 + [Int64]$Parts[1] * 65536 + [Int64]$Parts[2] * 256 + [Int64]$Parts[3])
    }
    
    function Convert-Int64ToIPAddressString {
        param ([Int64]$IntValue)
        
        return (([Math]::Truncate($IntValue / 16777216)).ToString() + "." + ([Math]::Truncate(($IntValue % 16777216) / 65536)).ToString() + "." + ([Math]::Truncate(($IntValue % 65536) / 256)).ToString() + "." + ([Math]::Truncate($IntValue % 256)).ToString())
    }
    
    if ($IPAndCDIR) {
        $IP = $IPAndCDIR.Split("/")[0]
        $CDIR = [int]::Parse($IPAndCDIR.Split("/")[1])
    }

    if ($CDIR) {
        $MaskAddr = [Net.IPAddress]::Parse((Convert-Int64ToIPAddressString -IntValue ([Convert]::ToInt64(("1" * $CDIR + "0" * (32 - $CDIR)) ,2))))
    }

    if ($Mask) {
        $MaskAddr = [Net.IPAddress]::Parse($Mask)
    }

    $NetworkAddr = New-Object Net.IPAddress ($MaskAddr.Address -band [Net.IPAddress]::Parse($IP).Address)
    $BroadcastAddr = New-Object Net.IPAddress (([System.Net.IPAddress]::Parse("255.255.255.255").Address -bxor $MaskAddr.Address -bor $NetworkAddr.Address))
    $StartAddr = $NetworkAddr.IPAddressToString
    $EndAddr = $BroadcastAddr.IPAddressToString

    if ($ListAll) {
        for ($i = (Convert-IPAddressStringToInt64 -IP $StartAddr); $i -le (Convert-IPAddressStringToInt64 -IP $EndAddr); $i++) {
            Convert-Int64ToIPAddressString -IntValue $i
        }
    } else {
        return [PSCustomObject]@{StartIPAddress = $StartAddr; EndIPAddress = $EndAddr }
    }
}

function Test-IPAddressString {
    param (
        [Parameter(Mandatory=$true,Position=1,ValueFromPipeline=$True)]
        [string]$IPAddressString
    )

    $temp = $null
    if ([Net.IPAddress]::TryParse($IPAddressString, [ref]$temp)) {
        return $true
    } else {
        throw New-Object FormatException("Invalid IP Address Format.")
    }
}