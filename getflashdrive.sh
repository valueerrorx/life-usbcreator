#!/bin/bash
# last update: 15.02.2017
# by: thomas michael weissel
# you may use and alter this script - please report fixes and enchancements to valueerror@gmail.com 
# or to the google+ community "Free Open Source Software in Schools"


DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"   #directory of this script
USER=$(logname)   #logname seems to always deliver the current xsession user - no matter if you are using SUDO

#---------------------------------------------------------#"
#      get size of usb device                             #"
#---------------------------------------------------------#"  
getsizeInGB(){  ## get and display size of flashdrive to give the user more information about the found device
    USBBYTESIZE=$(lsblk -d -o SIZE  -n -r -b /dev/${USB}) 
    USBSIZE=$( expr ${USBBYTESIZE} / 1024 / 1024)
}
#---------------------------------------------------------#"
#      check for lockfiles - delete if not use            #"
#---------------------------------------------------------#"  
check(){  #tests for lock files and process threads - removes unnesessary lockfiles 
    if test -f ${DIR}/${USB}.lock;
    then 
        # test if there is a reason for the other lockfile
        PROCESS=$( pidof -x $0)   #test if there is a reason for lock files (another clone process) PIPING this throug "wc -w" would start another proces of this script for an instant
        PROCESS=$( wc -w <<< "$PROCESS")   # therefore we make it a two step process... no pipe..  don't know why this is neccesary but it works
        
        DEV=$( ls /dev/${USB} 2> /dev/null| wc -l )
        
        
        if [[( $PROCESS = "1" || $DEV != "1" )]]   ##no other process of this script is running and locked device not found in /dev
        then
        # echo "DELETE LOCK FILE"
            sudo rm *.lock > /dev/null 2>&1
            sudo umount -f mnt* > /dev/null 2>&1
            sudo rmdir mnt* > /dev/null 2>&1
        fi
    fi
}







#---------------------------------------------------------#"
#      SEARCH FOR DEVICE      START                       #"
#---------------------------------------------------------#"  
if  [[( $1 = "check" ) ]]
then
    #---------------------------------------------------------#"
    #   set the usb device a target for the clone process     #"
    #---------------------------------------------------------#"  
    settargetdevice(){
        # diese funktion überprüft zuerst ob das laufende system ein live system ist
        # danach wird geprüft ob es sich bei dem gefundenen usb stick vielleicht um den system datenträger handelt
        # ist alles ok kann die geräte information in die device lock.file geschrieben werden - diese info wird vom python programm ausgelesen
        ISCOW=$(df -h |grep cow |wc -l)
        ISAUFS=$(df -h |grep aufs |wc -l)
        if [[( $ISCOW = "0" ) && ( $ISAUFS = "0" ) ]];
        then
            touch ${DIR}/${USB}.lock 
            printf "$USB;NOLIVE"  #dies ist kein live system.. usbkopie von installierten systemen nicht möglich
            exit 0
        fi
        SYSMOUNT1=$(findmnt -nr -o target -S /dev/${USB}1)          #on the masterflashdrive (created from life.iso) this would be the systempartition
        SYSMOUNT2=$(findmnt -nr -o target -S /dev/${USB}2)          #on the final life flashdrive (created from this script) this would be the systempartition
        if [[( $SYSMOUNT1 = '/cdrom' ) ||( $SYSMOUNT2 = '/cdrom' ) ]]                  ## check if this is the system device - check mountpoint!!
        then
            touch ${DIR}/${USB}.lock 
            printf "$USB;SYSUSB"    # der gefundene stick ist das systemdevice
            exit 0
        fi
        touch ${DIR}/${USB}.lock     #set target device
        SDX="/dev/$USB" 
        printf "$USB;$DEVICEVENDOR;$DEVICEMODEL;$DEVICESIZE;$USBBYTESIZE"
    }
    #---------------------------------------------------------#"
    #                 DETECTING USB DEVICE                    #"
    #---------------------------------------------------------#"
    #N=1
    #CHECKAGAIN=0
    USB=$2     ## Popen(["./getflashdrive.sh","check", dev ]   $1 = check $2 = dev (sda)
    
    findusb(){
        #  check if proposed usb device is actually a usb device
        DEVICETYPE=$(lsblk -n -o TRAN /dev/$USB |grep usb|awk '{print $1;}')
        if [[ ( $DEVICETYPE = "usb" ) ]];   #check lsblk if this is really a usb device
        then
            DEVICEVENDOR=$(lsblk -n -o TRAN,VENDOR /dev/$USB |grep usb|awk '{print $2;}')
            DEVICEMODEL=$(lsblk -n -o TRAN,MODEL /dev/$USB |grep usb|awk '{print $2;}')
            DEVICESIZE=$(lsblk -n -o TRAN,SIZE /dev/$USB |grep usb|awk '{print $2;}')
            USBBYTESIZE=$(lsblk -d -o SIZE  -n -r -b /dev/${USB}) 
            settargetdevice
        else
            printf "$USB;NOUSB"   #kein usb stick gefunden bzw. alle bereits in arbeit
        fi
    }
    
    DEV=$( ls /dev/${USB} 2> /dev/null | wc -l )
    if [[( $DEV = "1" )]]   ##  device  found in /dev
    then
        findusb
    else
        printf "$USB;NOUSB"    #kein usb stick gefunden
    fi

fi
#---------------------------------------------------------#"
#      SEARCH FOR DEVICE      END                         #"
#---------------------------------------------------------#" 












#---------------------------------------------------------#"
#      PREPARE DEVICE      START                          #"
#---------------------------------------------------------#" 
if  [[( $1 = "copy" ) ]]
then
    LIFESIZE="4000"    #darf nicht grösser sein. fat32 beschränkung für squashfs datei
    SHARESIZE=$2
    COPYCASPER=$3
    USB=$4
    TITLE=$5
    
    SDX="/dev/$USB" 

    echo $LIFESIZE
    echo $SHARESIZE
    echo $COPYCASPER
    echo $SDX
    
    #---------------------------------------------------------#"
    #     Open Progressbar for paritioning and syncing        #"
    #---------------------------------------------------------#"  


    ## start progress with a lot of spaces (defines the width of the window - using geometry will move the window out of the center)
    progress=$(kdialog --caption "${TITLE}"  --title "${TITLE}" --progressbar "USB Stick wird vorbereitet....                                                               ");
    qdbus $progress Set "" maximum 22
    sleep 0.5
        
    
    
    
    #---------------------------------------------------------#"
    #     start partitioning usb device                       #"
    #---------------------------------------------------------#"  
    partitiondevice(){

        LIFESIZEEND=$(( $SHARESIZE + $LIFESIZE ))
        
        # Ensuring that the device is not mounted #
        sudo umount ${SDX}1 > /dev/null 2>&1  #hide output
        sudo umount ${SDX}2 > /dev/null 2>&1  #hide output
        sudo umount ${SDX}3 > /dev/null 2>&1  #hide output

 
        qdbus $progress Set "" value 1
        qdbus $progress setLabelText "Partitionierungstabelle wird erstellt.... "
        sleep 0.5
        
        sudo partprobe $SDX
        sudo parted -s $SDX mklabel MSDOS
        
        
        
        
        qdbus $progress Set "" value 2
        qdbus $progress setLabelText "Partitionen werden erstellt.... "
        sleep 0.5

        sudo partprobe $SDX
        sudo parted -s $SDX mkpart primary 0% $SHARESIZE
        sudo parted -s $SDX mkpart primary $SHARESIZE $LIFESIZEEND
        sudo parted -s $SDX mkpart primary $LIFESIZEEND 100%
 
        # Setting boot flag to second partition   #
        sudo parted -s $SDX set 2 boot on
        sudo parted -s $SDX print
        

        qdbus $progress Set "" value 3
        qdbus $progress setLabelText "Warte bis Änderungen geschrieben wurden...."
        sleep 2

        sudo partprobe $SDX

        
        
        qdbus $progress Set "" value 4
        qdbus $progress setLabelText "Dateisysteme werden erstellt...."
        
        #         sudo mlabel -i ${SDX}1 ::SHARE
        #         sudo mlabel -i ${SDX}2 ::LIFESYSTEM
        #         sudo mlabel -i ${SDX}3 ::casper-rw
        
        sudo mkfs.vfat -F 32 -n SHARE ${SDX}1
        sleep 0.5
        sudo mkfs.vfat -F 32 -n LIFECLIENT ${SDX}2
        sleep 0.5
        echo "mkfs.ext2"   #trying ext2 because a journalling fs on a flashdrive is probably to heavy
        sudo mkfs.ext2 -L casper-rw ${SDX}3 > /dev/null 2>&1  #hide output
        sleep 1
        #sudo mkfs.ext2 -b 4096 -L home-rw ${SDX}3
        sudo partprobe

        #  teste ob paritionierung erfolgreich war
        
        ISLIVE=$(ls -l /dev/disk/by-label/ |grep ${USB} |grep LIFE|awk '{print $9;}') 

        if [[ ( "$ISLIVE" = "LIFECLIENT" ) ]];   #check if string not empty or null  (if life usb is found this ISLIVE returns a line
        then
            # do nothing for now
            echo "partitioning was a succcess"
        else
            check
            qdbus $progress Set "" value 22
            qdbus $progress setLabelText "USB Kopie abgebrochen" 
            sleep 0.5
            qdbus $progress close 
            kdialog  --caption "LIFE"  --title "LIFE" --msgbox "USB Gerät: $DEVICEVENDOR $DEVICEMODEL $DEVICESIZE \n\nUSB Stick Kopie fehlgeschlagen!\n\n"  > /dev/null 2>&1 
            echo "no valid life partitions found - paritioning failed"
            exit 0
        fi
        
    }

    
    
    
    ## IF update -  no partitioning  - check partitions and sync system 
    
    ISLIVE=$(ls -l /dev/disk/by-label/ |grep ${USB} |grep LIFE|awk '{print $9;}') 
    
    if [[  ( "$ISLIVE" = "LIFECLIENT" ) ]];   #check if string not empty or null  (if life usb is found this ISLIVE returns a line
    then
    
        kdialog  --caption "LIFE"  --title "LIFE" --yesno "Wollen sie das bestehende System updaten?\n\nAustauschpartition und /home bleiben erhalten."  > /dev/null 2>&1 
        if [ "$?" = 1 ]; then
            echo "creating partitions"
            partitiondevice
        else
            echo "keeping current partitions"
            ONLYUPDATE="true"
            # clean tmp files and other stuff or delete files on casper-rw except /home/ to avoid conficts FIXME
        fi;
     
    else
        echo "not a life usb device"
        partitiondevice
    fi
    
    
    
    mountsystempartition(){   ## this function tests if the mount directory already exists and creates a mount directory with a unique name
        qdbus $progress Set "" value 5
        qdbus $progress setLabelText "Erstelle Mountpoint...."
        sleep 0.5
        
        MOUNTPOINT="mnt"
        count=0
        while [ -d $MOUNTPOINT ]   #we are doing this because another clone process could be active and already captured mnt
        do
        # MOUNTPOINT="mnt${count}"
            echo "$MOUNTPOINT directory already exists!"
            (( count++ ))
            MOUNTPOINT="mnt${count}"
            echo "testing $MOUNTPOINT ..."
        done
        echo ""
        echo "#--------------------------------#"
        echo "# Creating directory $MOUNTPOINT !      #"
        echo "#--------------------------------#"
        echo ""
        sudo mkdir $MOUNTPOINT
            
        qdbus $progress Set "" value 6
        qdbus $progress setLabelText "USB Stick wird eingebunden...."
        sleep 0.5


        sudo mount ${SDX}2  $MOUNTPOINT
    }
    mountsystempartition  
    
    if [[ ( ${ONLYUPDATE}="true" ) ]];
    then
        sudo rm -r $MOUNTPOINT/boot/*
        sudo rm -r $MOUNTPOINT/casper/*
        sudo rm -r $MOUNTPOINT/EFI/*
        sudo rm -r $MOUNTPOINT/syslinux/*
    fi
    
    
    qdbus $progress Set "" value 7
    qdbus $progress setLabelText "Systemdateien werden übertragen.... (Bitte warten!)"

    rsyncsystem(){
        # send rsync to background and buffer the output to make it readable.. store output in lockfile for later use
        nohup rsync -a -h --info=progress2,stats /cdrom/ $MOUNTPOINT | stdbuf -oL tr '\r' '\n' | stdbuf -oL tr -s " " | stdbuf -oL cut -d " " -f 2-4 > ${DIR}/${USB}.lock &
        PROGESSBARVALUE=7  # see last qdbus progress set value
        STEPS=10
        COUNTER=0
        while [[(  $RSYNCPROCESS != "finished" )]]; do   
            sleep 0.5  # half second pause between progress checks
            NOHUPPROGRESSSIZE=$(tac ${DIR}/${USB}.lock |egrep -m 1 .| cut -d " " -f1)
            NOHUPPROGRESSPERCENT=$(tac ${DIR}/${USB}.lock |egrep -m 1 .| cut -d " " -f2)   # get the second word in the file which ist the percentage of the ongoing rsync process 
            NOHUPPROGRESSSPEED=$(tac ${DIR}/${USB}.lock |egrep -m 1 .| cut -d " " -f3)
            if [[ ( $NOHUPPROGRESSSIZE = "size" ) ]];  #  finished !!!  this is the last line if rsync is finished  [ size is 3.51G ]
            then
                RSYNCPROCESS="finished"
                qdbus $progress setLabelText "Übertragung beendet"
                qdbus $progress Set "" value 18
                sleep 2
            else
                qdbus $progress setLabelText "Systemdateien werden übertragen....       $NOHUPPROGRESSSIZE at $NOHUPPROGRESSSPEED"
                NOHUPPROGRESSPERCENT=${NOHUPPROGRESSPERCENT%?}    #cut of the percent sign %
                PERCENT=$( expr ${COUNTER}*${STEPS} )
                if [[ ( $NOHUPPROGRESSPERCENT -ge  $PERCENT ) ]];
                then
                    ((PROGESSBARVALUE++))   ## increment 
                    ((COUNTER++))
                    qdbus $progress Set "" value ${PROGESSBARVALUE}
                fi
            fi
        done
    }
    rsyncsystem
    
    
    
    
    
    qdbus $progress Set "" value 19
    qdbus $progress setLabelText "Bootloader Konfiguration wird übertragen...."
    sleep 0.5

    #just in case the script is run off a live dvd or virtualbox
    if [ -d ${MOUNTPOINT}/isolinux/ ];
    then
        sudo mv ${MOUNTPOINT}/isolinux/ ${MOUNTPOINT}/syslinux/
    fi
    sudo cp ${DIR}/syslinux/* ${MOUNTPOINT}/syslinux/
    sudo cp ${DIR}/grub/* ${MOUNTPOINT}/boot/grub/


    qdbus $progress Set "" value 20
    qdbus $progress setLabelText "Synchronisiere Gerät....        (Bitte warten!)"
    sleep 1
    sudo sync    # dauert ewig..  notwendig ?????????  JEIN! wird sonst vor "install bootloader automatisch nachgeholt und verwirrt

    qdbus $progress Set "" value 21
    qdbus $progress setLabelText "Installiere Bootloader...."
    
    sudo syslinux -if -d /syslinux ${SDX}2
    sleep 3
    sudo install-mbr ${SDX}
    

    qdbus $progress Set "" value 22
    qdbus $progress setLabelText "USB Kopie erstellt!" 
    sleep 0.5
    qdbus $progress close 
    
    
    
    #---------------------------------------------------------#"
    #      also copy casper-rw partition                      #"
    #---------------------------------------------------------#" 
    if [[( $COPYCASPER = "True"  )]]
    then
    
        copycasper(){  
            ## start progress with a lot of spaces (defines the width of the window - using geometry will move the window out of the center)
            progress=$(kdialog --caption "LIFE"  --title "LIFE" --progressbar "Kopiere Datenpartition....                                                               ");
            qdbus $progress Set "" maximum 17
            sleep 0.5

            qdbus $progress Set "" value 1
            qdbus $progress setLabelText "Zielpartition wird eingehängt.... "
            sleep 0.5
            
            sudo sync
            sudo umount $MOUNTPOINT > /dev/null 2>&1 
            sudo umount -l $MOUNTPOINT > /dev/null 2>&1 
            sudo umount -f $MOUNTPOINT > /dev/null 2>&1    #we make sure this sucker is umounted 
            sudo mount ${SDX}3  $MOUNTPOINT  #mount third partition casper-rw
            
            qdbus $progress Set "" value 2
            qdbus $progress setLabelText "Datenpartition wird eingehängt.... "
            sleep 0.5
            
            MOUNTPOINTCASPER="casper-rw"
            count=0
            while [ -d $MOUNTPOINTCASPER ]   #just in case another clone process is also using this mountpoint
            do
                MOUNTPOINTCASPER="casper-rw${count}"
                echo "$MOUNTPOINTCASPER directory already exists!"
                (( count++ ))
                MOUNTPOINTCASPER="casper-rw${count}"
                echo "testing $MOUNTPOINTCASPER ..."
            done
            sudo mkdir $MOUNTPOINTCASPER
            
            #  Detecting and mounting cow device - current systemdevice #
            COW=$(cat /proc/mounts | grep /cdrom | /bin/sed -e 's/^\/dev\/*//' |cut -c 1-3)   #find cow device
            COWDEV="/dev/${COW}3"   #the current casper partition
            
            sudo mount $COWDEV $MOUNTPOINTCASPER
            
            qdbus $progress Set "" value 3
            qdbus $progress setLabelText "Backup Dateien werden geschrieben.... "
            sleep 0.5

            #decided that this is not important
            
            qdbus $progress Set "" value 4
            qdbus $progress setLabelText "Temporäre Dateien werden gelöscht.... "
            sleep 0.5
            
            #get rid of files you dont need to transfer
            sudo apt-get clean
            sudo apt-get autoclean
            sudo rm /home/${USER}/.kde/share/apps/RecentDocuments/* > /dev/null 2>&1 
            sudo rm -r /var/tmp/kdecache-${USER}/* > /dev/null 2>&1 
            sudo rm -r /home/${USER}/.cache > /dev/null 2>&1 
            history -w
            history -c
            
            qdbus $progress Set "" value 5
            qdbus $progress setLabelText "Benutzerdaten werden übertragen.... "
            sleep 0.5
            #  Copying persistent partition  #
            nohup rsync -a -h --info=progress2,stats ${MOUNTPOINTCASPER}/ $MOUNTPOINT | stdbuf -oL tr '\r' '\n' | stdbuf -oL tr -s " " | stdbuf -oL cut -d " " -f 2-4 > ${DIR}/${USB}.lock &
            
            RSYNCPROCESS=""
            PROGESSBARVALUE=5  # see last qdbus progress set value
            STEPS=10
            COUNTER=0

            while [[(  $RSYNCPROCESS != "finished" )]]; do   
                sleep 0.5  #pause between progress checks
                NOHUPPROGRESSSIZE=$(tac ${DIR}/${USB}.lock |egrep -m 1 .| cut -d " " -f1)
                NOHUPPROGRESSPERCENT=$(tac ${DIR}/${USB}.lock |egrep -m 1 .| cut -d " " -f2)   # get the second word in the file which ist the percentage of the ongoing rsync process 
                NOHUPPROGRESSSPEED=$(tac ${DIR}/${USB}.lock |egrep -m 1 .| cut -d " " -f3)
                if [[ ( $NOHUPPROGRESSSIZE = "size" ) ]];  #  finished !!!  this is the last line if rsync is finished  [ size is 3.51G ]
                then
                    RSYNCPROCESS="finished"
                    qdbus $progress setLabelText "Übertragung beendet"
                    qdbus $progress Set "" value 16
                    sleep 2
                else
                    qdbus $progress setLabelText "Benutzerdaten werden übertragen....       $NOHUPPROGRESSSIZE at $NOHUPPROGRESSSPEED"
                    NOHUPPROGRESSPERCENT=${NOHUPPROGRESSPERCENT%?}    #cut of the percent sign %
                    PERCENT=$( expr ${COUNTER}*${STEPS} )
                    if [[ ( $NOHUPPROGRESSPERCENT -ge  $PERCENT ) ]];
                    then
                        ((PROGESSBARVALUE++))   ## increment 
                        ((COUNTER++))
                        qdbus $progress Set "" value ${PROGESSBARVALUE}
                    fi
                fi
            done
            
            # remove casper mountpoint
            sudo umount $MOUNTPOINTCASPER > /dev/null 2>&1
            sudo umount -l $MOUNTPOINTCASPER > /dev/null 2>&1  #hide errors
            sudo rmdir $MOUNTPOINTCASPER > /dev/null 2>&1
            
            qdbus $progress Set "" value 17
            qdbus $progress setLabelText "Vollständige USB Kopie (inklusive Benutzerdaten) erstellt!" 
            sleep 2
            qdbus $progress close 
        }

    
    fi
    
    check   #remove lock files and mount points
    kdialog  --caption "LIFE"  --title "LIFE" --msgbox "USB Gerät: $DEVICEVENDOR $DEVICEMODEL $DEVICESIZE \n\nUSB Stick Kopie erfolgreich!\n\nSie können das Gerät nun entfernen."  > /dev/null 2>&1 

fi
#---------------------------------------------------------#"
#      PREPARE DEVICE      END                            #"
#---------------------------------------------------------#" 

































