function Remove-SecureSetting
{
    <#
    .Synopsis
        Removes an encrypted setting from the registry
    .Description
        Removes a stored secured user settings in the registry
    .Example
        Remove-SecureSetting
    .Example
        Remove-SecureSetting AStringSetting 
    .Link
        Add-SecureSetting
    .Link
        Get-SecureSetting
    .Link
        ConvertTo-SecureString
    .Link
        ConvertFrom-SecureString
    #>    
    [CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact='High')]
    [OutputType([Nullable])]
    param(
    # The name of the secure setting
    [Parameter(Position=0,ValueFromPipelineByPropertyName=$true)]
    [String]
    $Name,
    
    # The type of the secured setting
    [Parameter(Position=1,ValueFromPipelineByPropertyName=$true)]
    [Type]
    $Type
    )
    
    begin {
        #region Create Registry Location If It Doesn't Exist 
        $registryPath = "HKCU:\Software\Start-Automating\$($myInvocation.MyCommand.ScriptBlock.Module.Name)"
        $fullRegistryPath = "$registryPath\$($psCmdlet.ParameterSetName)"
        if (-not (Test-Path $fullRegistryPath)) {
            $null = New-Item $fullRegistryPath  -Force
        }   
        #endregion Create Registry Location If It Doesn't Exist
        
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
        
        #region Cache Secure Settings
        $secureSettings= 
            Get-ChildItem $registryPath | 
                Get-ItemProperty | 
                ForEach-Object $getSecureSetting 
        #endregion Cache Secure Settings
    }
    
    process {
        
        #region Filter and Remove Appropriate Settings
        $secureSettings | 
            Where-Object {
                if ($psBoundParameters.Name -and $_.Name -notlike "$name*") { return } 
                if ($psBoundParameters.Type -and $_.Type -ne $Type) { return } 
                $true
            } | 
            ForEach-Object {
                if ($psCmdlet.ShouldProcess($_.Name)) {                                   
                    Remove-ItemProperty -Path "$registryPath\$($_.Type.Fullname)" -Name $_.Name
                }                
            }                       
        #endregion Filter and Remove Appropriate Settings
    }

} 
 
