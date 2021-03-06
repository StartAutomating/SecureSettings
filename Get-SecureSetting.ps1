function Get-SecureSetting
{
    <#
    .Synopsis
        Gets encrypted settings stored in the registry
    .Description
        Gets secured user settings stored in the registry
    .Example
        Get-SecureSetting
    .Example
        Get-SecureSetting MySetting
    .Example
        Get-SecureSetting MySetting -Decrypt
    .Example
        Get-SecureSetting MySetting -ValueOnly
    .Link
        Add-SecureSetting
    .Link
        Remove-SecureSetting
    .Link
        ConvertTo-SecureString
    .Link
        ConvertFrom-SecureString
    #>    
    [OutputType('SecureSetting')]
    param(
    # The name of the secure setting
    [Parameter(Position=0,ValueFromPipelineByPropertyName=$true)]
    [String]
    $Name,
    
    # The type of the secure setting
    [Parameter(Position=1,ValueFromPipelineByPropertyName=$true)]
    [Type]
    $Type,
    
    # If set, will decrypt the setting value
    [Parameter(ValueFromPipelineByPropertyName=$true)]
    [Switch]
    $Decrypted,
    
    # If set, will decrypt the setting value and return the data
    [switch]
    $ValueOnly    
    )
    
    begin {
        $getSecureSetting = {
            $Obj = $_
            $typeName = $_.pschildName
            foreach ($propName in ($obj.psobject.properties | Select-Object -ExpandProperty Name)) {
                if ('PSPath', 'PSParentPath', 'PSChildName', 'PSProvider' -contains $propName) {
                    $obj.psobject.properties.Remove($propname)
                }
            }
            $Obj.psobject.properties | 
                ForEach-Object {
                    $secureSetting = New-Object PSObject 
                    $null = $secureSetting.pstypenames.add('SecureSetting')
                    $secureSetting | 
                        Add-Member NoteProperty Name $_.Name -PassThru |
                        Add-Member NoteProperty Type ($typename -as [Type]) -PassThru |
                        Add-Member NoteProperty EncryptedData $_.Value -PassThru 

                }
        }
    }
   
    process {
        # If Request and Response are present, Get-SecureSetting acts like Get-WebConfigurationSetting
        if ($Request -and $Response -and -not $inPSNode) {
            
            if ($Request -and $request.Params -and $request.Params['Path_Info']) {        
                $path  ="$((Split-Path $request['Path_Info']))"    
                            
                $webConfigStore = [Web.Configuration.WebConfigurationManager]::OpenWebConfiguration($path)                                                                                  
            } else {
                # Otherwise, use the global one
                $webConfigStore = [Web.Configuration.WebConfigurationManager]::OpenWebConfiguration($null)                                                                                              
            }    
            #endregion Load Config Store
            
            if ($name) {

                # Get the custom setting
                $customSetting = $webConfigStore.AppSettings.Settings["$name"];
                
                # If there is a value, return it.
                if ($CustomSetting) {
                    $CustomSetting.Value
                }
            }
            return
        } 
    
    
    
        #region Create Registry Location If It Doesn't Exist 
        $regSubKey = if ($myInvocation.MyCommand.ScriptBlock.Module.Name) {
            $myInvocation.MyCommand.ScriptBlock.Module.Name
        } else {
            "Pipeworks"
        }

        $registryPath = "HKCU:\Software\Start-Automating\$($myInvocation.MyCommand.ScriptBlock.Module.Name)"
        $fullRegistryPath = "$registryPath\$($psCmdlet.ParameterSetName)"
        if (-not (Test-Path $fullRegistryPath)) {
            $null = New-Item $fullRegistryPath  -Force
        }   
        #endregion Create Registry Location If It Doesn't Exist
        
        Get-ChildItem $registryPath | 
            Get-ItemProperty | 
            ForEach-Object $getSecureSetting |
            Where-Object {
                if ($psBoundParameters.Name -and $_.Name -notlike "$name*") { return } 
                if ($psBoundParameters.Type -and $_.Type -ne $Type) { return } 
                $true
            } |
            ForEach-Object -Begin {
                $TempCredTable = @{}
            } -Process {
                if (-not ($decrypted -or $ValueOnly)) { return $_ }
                
                #region Decrypt and Convert Output
                $inputObject = $_
                if ([Hashtable], [string] -contains $_.Type) {
                    # Create a credential to unpack it
                    $convertedAgain  = 
                        New-Object Management.Automation.PSCredential ' ', ($_.EncryptedData | ConvertTo-SecureString)
                        
                    $decryptedValue= $convertedAgain.GetNetworkCredential().Password  
                    
                    if ($_.Type -eq [Hashtable]) {
                        $decryptedValue = . ([ScriptBlock]::Create($decryptedValue))
                    }
                } elseif ($_.Type -eq [Security.SecureString]) {
                    $decryptedValue= ($_.EncryptedData | ConvertTo-SecureString)
                } elseif ($_.Type -eq [Management.Automation.PSCredential]) {
                    # Create a credential to unpack the username, then create a credential with the unpacked password
                    $baseName = $_.Name -ireplace "_UserName", ""
                    if ($_.Name -like "*_UserName") {
                        $convertedAgain  = 
                            New-Object Management.Automation.PSCredential ' ', ($_.EncryptedData | ConvertTo-SecureString)
                            
                        $decryptedValue= $convertedAgain.GetNetworkCredential().Password  
                                
                        $tempCredTable["UserName"] = $decryptedValue
                    } elseif ($_.Name -like "*_Password") {                        
                                
                        $tempCredTable["Password"] = ($_.EncryptedData | ConvertTo-SecureString)
                    }
                }
                $null = $inputObject.psobject.properties.Remove('EncryptedData')
                if ($inputObject.Name -notlike "*_UserName") {
                    if ($inputObject.Name -like "*_Password" -and $tempCredTable.UserName) {
                        $inputObject | 
                            Add-Member NoteProperty Name $baseName -Force
                        $decryptedValue  =New-Object Management.Automation.PSCredential $tempCredTable["UserName"], $tempCredTable["PassWord"]
                    } 
                    $inputObject | 
                        Add-Member NoteProperty DecryptedData $decryptedValue -PassThru |
                        ForEach-Object {
                            if ($ValueOnly) {
                                $_.DecryptedData
                            } else {
                                $_
                            }
                        }               
                }
                #endregion Decrypt and Convert Output
            }
                    
    }

} 
 
