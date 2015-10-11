<#
Created by Tomas Ledecky [TIMI]
Initial release v 1.0
#>

##########You can easily edit some settings here (start of settings area)

#if listOnlyMultiHostDS is set to 'y' Datastores that are visible only from one Host will be excluded from folder selection view
$listOnlyMultiHostDS = 'y'

#address of Vcenter server:
$Lserver = 'server.name.com'

#If you comment both $Luser and $lpass your windows session credentials will be used
$Luser = 'domain\username'
$Lpass = 'password'


##########Stop edit at this point (end of settings area)

Import-Module VMware.VimAutomation.Core
$connection = Connect-VIServer -Server $Lserver -User $Luser -Password $Lpass

if ($connection.IsConnected -eq 'True'){$connection} 
else {
	echo "Exitting - connection to the server does NOT exist"
	exit
}


echo ""
Echo '*** WELCOME TO LINKED CLONE MANAGING SCRIPT ***'
echo ""
echo "Select action"
echo "1 = Create Linked Clones"
echo "2 = Delete Linked Clones by specifying their parent"
$mainSelect = (Read-Host "Specify action [number]")

switch ($mainSelect){
	1 {

		echo ""
		echo "***CLONE VMs SCRIPT***"
		echo "New VMs will be named by scema prefix+number+suffix"
		$prefix = (Read-Host "Please enter a prefix")

		echo ""
		echo "***NUMBERS***"
		echo "Please provide a sequence for numbering (you can add multiple structures together sequences+items)"
		while($Nmode -ne 'q'){

			echo "Choose input type s= sequence (x-y); i= items(x,y,z); q= stop inputing numbers"

			$Nmode = (Read-Host)
			if ($Nmode -eq 's') {
				$ArrayBorders =(Read-Host "Enter range (separate with -)").split('-') | % {$_.trim()}
				$numArray += ($ArrayBorders[0]..$ArrayBorders[1])
				} 
		else {
			if($Nmode -eq 'i'){
				$numArray +=(Read-Host "Enter numbers (separate with comma)").split(',') | % {$_.trim()}
				}
			}
		}

		$suffix = (Read-Host "Please enter a suffix")

		$newVMNames = @()
		foreach ($element in $numArray) {
			$newVMNames += $prefix + $element + $suffix
		}
		echo ""
		echo "The new VM names are:"
		echo $newVMNames

		echo ""
		$n = 0
		foreach ($element in $newVMNames) {
			$ErrorActionPreference = "SilentlyContinue"
			$current = Get-VM -name $element
			$ErrorActionPreference = ""
			if($current){
				$n++
				Write-Host "The $element will be deleted "
			}
		}
		if($n -gt 0){
			$delAns = (Read-Host "There are VMs that will be deleted (and replaced) before cloning ARE YOU SURE? (y/n) [default = n]")
			if (($delAns -ne 'y') -and ($delAns -ne 'Y') -and ($delAns -ne 'yes')){
				echo "*** Exiting without changes ***"
				exit
			}
		}

		echo ""
		while ($true){
			$oldVMName = Read-host "Enter the name of the old VM you wish to clone from"
			$ErrorActionPreference = "SilentlyContinue"
			$oldVM = Get-VM -name $oldVMName
			$ErrorActionPreference = ""
			if($oldVM) {
				break
			}
			else {
				echo "Specified VM does NOT exist"
			}
	
		}


		$ErrorActionPreference = "SilentlyContinue"
		$oldTag = Get-Tag -Name "Childs-$oldVM"
		$ErrorActionPreference = ""

		
		if($oldTag){
			Echo "It looks like this VM already is a parent, new clones will be added to it, ...you are welcome"
		}
		
		
		echo ""
		echo "*** Finding HOSTS ***"
		$myHosts = Get-VMHost

		$n = 0
		foreach($element in $myHosts){
			$n++
			echo "$n = $element"
		}
		echo "a = Automatic selection (by free RAM)"
		$HOSTselect = Read-Host "Enter the number of the host you wish to create the VM on [number] or [a]"

		if (($HOSTselect -eq 'a') -or ($HOSTselect -eq '')){
			$MAXfreeRAM = 0
					
			foreach ($element in $myHosts){
				$freeRAM = $element.MemoryTotalMB - $element.MemoryUsageMB
				if($freeRAM -gt $MAXfreeRAM){
					$MAXfreeRAM = $freeRAM
					$HOSTName = $element
				}
			}
			Echo "Clones will be created on $HOSTName"
		} else {
		$HOSTName = $myHosts[$HOSTselect - 1]
		}

		echo ""
		echo "*** Finding DATASTORES***"

		$allDSs = Get-Datastore

		if($listOnlyMultiHostDS -eq 'y' ){
			$myDSs = @()
			foreach ($element in $allDSs){
				if ((Get-Datastore -Name $element.Name | Get-VMHost).Count -gt 1){
					$myDSs += $element
				}
			}
		} else {
			$myDSs = $allDSs 
		}

		$n = 0
		foreach($element in $myDSs){
			$n++
			echo "$n = $element"
		}

		$DSselect = Read-Host "Enter the number of the datastore you wish to create the VM on [number] [default = 1]"
		if($DSselect -eq ''){$DSselect = 1}

		$Datastore = $myDSs[$DSselect - 1]

		echo ""
		echo "*** Finding FOLDERS***"

		$folders = Get-Folder

		$n = 0
		$myFolders = @()
		foreach($element in $folders){
			if(($element.Type -eq 'VM')){
			$n++
			$myFolders += $element
			echo "$n = $element"
			}
		}

		$folderSelect = Read-Host "Select folder where the new VM will be created, enter the number (vm = root) [default = 1]"
		if($folderSelect -eq ''){
			$folderSelect = 1
		}

		$folder = $myfolders[$folderSelect - 1]
		
		echo ""
		echo "*** Finding OS customisations***"

		$OSspecs = Get-OSCustomizationSpec

		$n = 0
		foreach($element in $OSspecs){
			$n++
			echo "$n = $element"
		}
		echo "n = none - Don't apply OS specification"
		
		$OSspecSelect = Read-Host "Select OS customization that will be used or n for none [default = n]"
		if($OSspecSelect -eq ''){
			$OSspecSelect = 'n'
		}
		
		if($OSspecSelect -ne 'n'){
			$OSspec = $OSspecs[$OSspecSelect - 1]
		}

		echo ""
		$powerONAns = Read-Host "Do you want to Power on the VMs after creation ? (y/n) [defaut = y]"
		if(($powerONAns -eq '') -or ($powerONAns -eq 'y') -or ($powerONAns -eq 'Y') -or ($powerONAns -eq 'yes')){
			$powerONAnsNice = 'yes'
		} else {
			$powerONAnsNice = 'no'
		}

		Write-Host ""
		Write-Host '**************** SUMMARY **************'
		Write-Host '*                                    *'
		Write-Host '**************************************'
		Write-Host "* VM names         * ${prefix}(n)${suffix}"
		Write-Host "**************************************"
		Write-Host "* Host             * $HOSTName"
		Write-Host "**************************************"
		Write-Host "* Datastore        * $Datastore"
		Write-Host "**************************************"
		Write-Host "* Folder           * $folder"
		Write-Host "**************************************"
		Write-Host "* OScustomization  * $OSspec"
		Write-Host "**************************************"
		Write-Host "* Power on VMs     * $powerONAnsNice"
		Write-Host "**************************************"
		
		Write-Host ""
		
		$sumAns = (Read-Host "Is everything OK? (y/n) [default = y]")
		
		if (($sumAns -ne 'y') -and ($sumAns -ne 'Y') -and ($sumAns -ne 'yes') -and ($sumAns -ne '')){
			echo "*** Exiting without changes ***"
			exit
		}
		
		$ErrorActionPreference = "SilentlyContinue"
		$tagCat = Get-TagCategory -Name Linked_Clones
		$ErrorActionPreference = ""
		
		if (!$tagCat){$tagCat = New-TagCategory -Name Linked_Clones}
		
		
		$OFS = ';'
		if($oldTag){
			$oldDescription = $oldTag.Description
			$newDescription = $oldDescription + ';' + $newVMNames
			$tmpArray = $newDescription -split ";" | select -Unique
			[string]$newDescription = $tmpArray
			$tag = Set-Tag -Tag $oldTag -Description "$newDescription" 
		} else {
			$tag = New-Tag -Name "Childs-$oldVM" -Category $tagCat -Description "$newVMNames"
		}
		rv OFS
		$silent = New-TagAssignment -Tag $tag -Entity $oldVM
		
		
		$oldVMsnap = New-Snapshot -VM $oldVM -Name linked_clone -Confirm:$false -Description "This snapshot is actively used by Linked clones. !!!DO NOT DELETE!!!"


		foreach ($element in $newVMNames){

			$ErrorActionPreference = "SilentlyContinue"
			$actualRem = Get-VM -Name $element
			$ErrorActionPreference = ""
	
			if($actualRem){
				if($actualRem.PowerState -eq 'PoweredOn'){
					Stop-VM -VM $actualRem -Confirm:$false | Format-Table
				}
			Remove-VM -VM $actualRem -Confirm:$false -DeletePermanently:$true
			}
	
			$actualVM = New-VM -VM $oldVM -Name $element -VMHost $HOSTName -Location $folder.Name -Datastore $Datastore -LinkedClone:$true -ReferenceSnapshot $oldVMsnap  -OSCustomizationSpec $OSspec
			if ($powerONAnsNice -eq 'yes'){
				Start-VM -VM $actualVM | Format-Table
			}
		}

		Echo "***FINNISHED***"

	} #End of Cloning module

	#Start of Deleting module
	2 {
		echo ""
		echo "***DELETE VMs SCRIPT***"
		echo "This script deletes all Linked Clones of a provided parent"

		$ParentVMname = (Read-Host "Please enter a VM Parent name")
		$ParentVM = Get-VM -name $ParentVMname

		$tags = Get-TagAssignment -Entity $ParentVM
		
		foreach($element in $tags){
			if ($element.tag.Name -eq "Childs-$ParentVMname"){
				$tag = $element
			}
		
		}
		

		$separator = ';'

		$VMnames = @($tag.Tag.Description.Split($separator))

		$ParentAns = (Read-Host "Do you want to delete The Parent also? (y/n) [Default = Y]")
		if (($ParentAns -eq '') -or ($ParentAns -eq 'Y') -or ($ParentAns -eq 'yes') ){
			$VMnames += $ParentVMname
		} else {
			$SnapshotRem = 'true'
		}

		echo "This machines will be removed:"
		echo $VMnames
		$ParentAns = (Read-Host "ARE YOU SURE? (y/n) [Default = n]")
		if (($ParentAns -eq 'y') -or ($ParentAns -eq 'yes') -or ($ParentAns -eq 'Y') ) {

			foreach ($element in $VMnames){

				$ErrorActionPreference = "SilentlyContinue"
				$actualRem = Get-VM -Name $element
				$ErrorActionPreference = ""
	
				if($actualRem){
					if($actualRem.PowerState -eq 'PoweredOn'){
						$silent = Stop-VM -VM $actualRem -Confirm:$false | Format-Table
					}
					Remove-VM -VM $actualRem -Confirm:$false -DeletePermanently:$true
					echo "$element removed"
				}
			}

			Remove-Tag -Tag "Childs-$ParentVMname" -Confirm:$false

			if($SnapshotRem){
				$actualSnap = Get-Snapshot -VM $ParentVM -Name linked_clone
				Remove-Snapshot -Snapshot $actualSnap -Confirm:$false
			}
	
			echo "***FINISHED***"
	
		} else {
			echo "***Exiting without deleting***"
		}

	} #End of  deleting module

} #End of switch

exit