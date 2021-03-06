. $psScriptRoot\Add-SecureSetting.ps1 
. $psScriptRoot\Get-SecureSetting.ps1
. $psScriptRoot\Remove-SecureSetting.ps1

. $psScriptRoot\Write-PowerShellHashtable.ps1

#region Common Secure Setting Code

$registryPath = "HKCU:\Software\Start-Automating\SecureSettings"


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
#endregion Common Secure Setting Code