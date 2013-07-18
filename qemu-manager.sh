#!/bin/bash

#Variables
CONFDIR="$HOME/.config/qemu-manager"
CONFFILE="qemu-manager.conf"
HDDDIR="$HOME/qemu-images"

#make sure all files and directories exist, if not, create them
init()
{
    if [ ! -d $CONFDIR ]; then
	mkdir $CONFDIR
    fi

    if [ ! -d $HDDDIR ]; then
	mkdir $HDDDIR
    fi

    if [ ! -f $CONFDIR/$CONFFILE ]; then
	touch $CONFDIR/$CONFFILE
    fi
}


#Menus
#main menu
mainmenu()
{
    cat<<MAINEOF
	1.  Run VM
	2.  Create VM
	3.  Delete VM

MAINEOF

    echo -n "Select an option: "
    read i
    case $i in 
	1|1.)	runmenu;;
	2|2.)	createmenu;;
	3|3.)	delmenu;;
	*)	exit 1;;
    esac

}

#menu for running vms
runmenu()
{
    listvms
    echo -n "Select a VM: "
    read j
    if [ "$j" == "" ] || [ "$j" -gt "${#vmname[@]}" ]; then
	errout "Invalid VM choice"
    fi

    echo -n "Would you like to boot from a CD? [y/N] " 
    read k

    #if not yes, than always no
    if [ $k != "y" ]; then
	k='n'
    fi

    #load configuration entries into memory
    confline=`cat $CONFDIR/$CONFFILE | grep "${vmname[$j]}"`
    mem=`echo $confline | awk 'BEGIN {FS=","}; {print $2}'`
    arch=`echo $confline | awk 'BEGIN {FS=","}; {print $3}'`
    cpu=`echo $confline | awk 'BEGIN {FS=","}; {print $4}'`
    cores=`echo $confline | awk 'BEGIN {FS=","}; {print $5}'`

    case $k in
	y)
	    #run with cdrom
	    echo -n "Please enter the full path to the CD image: "
	    read cdpath
	    if [ ! -f $cdpath ]; then
		errout "CD image not found"
	    fi
	    qemu-system-$arch -enable-kvm -boot c -cdrom "$cdpath" -hda "$HDDDIR/${vmname[$j]}.qcow2" -m $mem -cpu $cpu -smp "cores=$cores"
	    ;;
	n)
	    #run with no cdrom
	    qemu-system-$arch -enable-kvm -hda "$HDDDIR/${vmname[$j]}.qcow2" -m $mem -cpu $cpu -smp "cores=$cores"
	    ;;
	*)
	    exit 1;
    esac
}

#menu for creation of vms
createmenu()
{
    echo -n "Image Name: "
    read name
    dupe=`grep -c "^$name," "$CONFDIR/$CONFFILE"`
    if [ $dupe != 0 ]; then
	errout "Name already exists"
    fi

    echo -n "Disk size (eg. 4G 512M): "
    read disksize

    echo -n "Ram (MB): "
    read ram

    echo "Available archetectures: "
    arches=`compgen -c | grep qemu-system- | awk 'BEGIN {FS="-"};{print "   "$3}' | sort`
    echo $arches
    echo -n "Architecture: "
    read arch
    avail=`echo $arches | grep -c $arch`
    if [ $avail == 0 ]; then
	errout "Architecture not available"
    fi

    cpu="host"

    echo -n "Number of cores (1-4): "
    read cores
    if [ $cores -gt 4 ] ||  [ $cores -lt 1 ]; then
	errout "Invalid number of cores"
    fi
    
    #create disk image and add entry into config file
    echo "${name},${ram},${arch},${cpu},${cores}" >> "$CONFDIR/$CONFFILE"
    qemu-img create -f qcow2 "$HDDDIR/${name}.qcow2" $disksize
}

#menu for deletion of vms
delmenu()
{
    listvms
    echo -n "Select a VM to delete: "
    read m
    if [ "$m" == "" ] || [ "$m" -gt ${#vmname[@]} ]; then
	errout "Invalid VM choice"
    fi
    
    echo -n "Are you SURE you want to delete the VM called \"${vmname[$m]}\"? (yes/NO) "
    read sure
    if [ "$sure" != "yes" ]; then
	errout "Aborting"
    fi

    #delete vm from config file and image from disk
    sed "/^${vmname[$m]},/d" "$CONFDIR/$CONFFILE" > "$CONFDIR/${CONFFILE}.bak"
    mv "$CONFDIR/${CONFFILE}.bak" "$CONFDIR/$CONFFILE"
    rm -f "$HDDDIR/${vmname[$m]}.qcow2"
}


#Other functions
#function to load and printout vm list
listvms()
{
    declare -i index
    index=0
    while read line; do
	#put the names of the VMs into an array
	vmname[$index]=`echo $line | awk 'BEGIN {FS=","}; {print $1}'`
	echo -e "$index.\t${vmname[$index]}"
	index=$index+1
    done < <(cat $CONFDIR/$CONFFILE | grep -v "#" | grep -v "^$")
}

#generic error function
errout() { echo "error: $*" >&2; exit 1; }

init
echo -e "Welcome to QEMU manager\n\n"
mainmenu













