Connect-AzAccount

Get-AzContext

foreach($sub in $subs)
{
Set-AzContext -SubscriptionId $sub.Id


$plocations=(Get-AzLocation  | where Providers -eq "Microsoft.RecoveryServices").Location 
Write-Output "estas son las regiones donde podrías poner tu vault"
Write-Output $plocations
$location = read-host "¿donde ponemos tu vault?"

#Para evitar errores vamos a ver si tu subscripcion tiene ese resoure provider habilitado

$rps=Get-AzResourceProvider -ProviderNamespace "Microsoft.RecoveryServices" -Location $location
foreach($rp in $rps)
{
    if($rp.RegistrationState -ne "Registered")
    {
    Register-AzResourceProvider -ProviderNamespace $rp.ProviderNamespace
    }
}


#Por cada subscripcion crear vault y grupo de recursos
$nombrerg= $sub.Name + "-Backup-Rg2"
$nombre= $sub.Name + "-Backup2"
New-AzResourceGroup -Name $nombrerg -Location $location
New-AzRecoveryServicesVault -Name $nombre -ResourceGroupName $nombrerg -Location $location


#hacer set al contexto con ese vault
#Get-AzRecoveryServicesVault -Name $nombrerg -ResourceGroupName $nombre | Set-AzRecoveryServicesVaultContext
$finalVault = Get-AzRecoveryServicesVault -ResourceGroupName $nombrerg -Name $nombre 
$vaultid=$finalVault.ID

#crear política 
$LowPol = read-host "¿Que nombre le quieres poner a tu política?"
$SchPol = Get-AzRecoveryServicesBackupSchedulePolicyObject -WorkloadType "AzureVM" 
$SchPol.ScheduleRunTimes.Clear()
Write-Output "cuando empezamos tu respaldo?"
$d  = read-host "dia"
$m= read-host "mes (1-12)"
$a= read-host "año"
$h= read-host "hora (0-23)"
$Dt = New-Object DateTime $a, $m, $d, $h, 0, 0, ([DateTimeKind]::Utc)
$SchPol.ScheduleRunTimes.Add($Dt.ToUniversalTime())
$RetPol = Get-AzRecoveryServicesBackupRetentionPolicyObject -WorkloadType "AzureVM" 
$dia = read-host "Tu respado DEBE tener un tiempo de retención de Dias ¿Cual es la retención de tus respaldos en dias?"
$RetPol.DailySchedule.DurationCountInDays = $dia
$semana = read-host "Tu respado DEBE tener un tiempo de retención de Dias ¿Cual es la retención de tus respaldos en semanas?"
$RetPol.WeeklySchedule.DurationCountInWeeks = $semana
$RetPol.IsMonthlyScheduleEnabled= $null
$RetPol.IsYearlyScheduleEnabled= $null
New-AzRecoveryServicesBackupProtectionPolicy -Name $LowPol -WorkloadType AzureVM -RetentionPolicy $RetPol -SchedulePolicy $SchPol -VaultId $vaultid



Write-Output "Empecemos a respaldar TODAS tus máquinas que no están respaldadas" 

$pol = Get-AzRecoveryServicesBackupProtectionPolicy -Name $LowPol -VaultId $vaultid
    $crear=   foreach($rg in $rgs)
    {
    $vms = Get-AzVm
            foreach($vm in $vms)
        {
            Enable-AzRecoveryServicesBackupProtection -Policy $pol -Name $vm.Name -ResourceGroupName $rg.ResourceGroupName

        }
    }
}