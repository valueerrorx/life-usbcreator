#! /usr/bin/env python
# -*- coding: utf-8 -*-
import sys, os, string, ipaddress
from PyQt5 import QtCore, uic, QtWidgets
from PyQt5.QtGui import *
from subprocess import Popen, PIPE, STDOUT
import subprocess, sip, time




class MeinDialog(QtWidgets.QDialog):
    def __init__(self):
        QtWidgets.QDialog.__init__(self)
        self.ui = uic.loadUi("usbcreator.ui")        # load UI
        self.ui.setWindowIcon(QIcon("pixmaps/drive.png"))
        self.ui.search.clicked.connect(self.searchUSB)     
        self.ui.exit.clicked.connect(self.onAbbrechen)        # setup Slots
        self.ui.copy.clicked.connect(self.startCopy)
        self.proposed = ["sda","sdb","sdc","sdd","sde","sdf","sdg","sdh","sdi","sdj","sdk","sdl","sdm","sdn","sdo","sdp","sdq","sdr","sds","sdt","sdu","sdv","sdw","sdx","sdy","sdz"]
        
        self.extraThread = QtCore.QThread()
        self.worker = Worker(self)
        self.worker.moveToThread(self.extraThread)
        self.extraThread.started.connect(self.worker.doCopy)
        
        
    def searchUSB(self):
        self.devices = []
        
        #build devices list
        for dev in self.proposed:
            self.checkDevice(dev)
        
        if len(self.devices) > 0:
            self.ui.copy.setEnabled(True)
        else: 
            self.ui.copy.setEnabled(False)
        
        
        #delete all widgets
        items = self.get_list_widget_items()
        for item in items:
            sip.delete(item)
        
        
        
        #build size information for every device
        for deviceentry in self.devices:
            usbdev = deviceentry[0]
            device_info = deviceentry[1]
            devicemodel = deviceentry[2]
            devicesize = deviceentry[3]
            usbbytesize = deviceentry[4]
            self.createWidget(usbdev, device_info, devicemodel, usbbytesize)
        
        
        # do not allow copy if any of the flashdrives is too small
        items = self.get_list_widget_items()  
        for item in items:
            if item.sharesize is 0:
                self.ui.copy.setEnabled(False)
       
            
        
    def createWidget(self,usbdev, device_info, devicemodel, usbbytesize):
        #add device widgets to UI
        items = self.get_list_widget_items()
        if items:
            existing = False
            for item in items:
                if usbdev == item.id:
                    existing = True
                    print "found existing widget for usb device"
            
            if existing is False:
                self.addNewListItem(usbdev, device_info, devicemodel, usbbytesize)
                return
        else:
            self.addNewListItem(usbdev, device_info, devicemodel, usbbytesize)
            return
   
   
   
           
        
    def addNewListItem(self, usbdev, device_info, devicemodel, usbbytesize):
        item = QtWidgets.QListWidgetItem()
        item.setSizeHint(QtCore.QSize(370, 120));
        #store important information on the widget
        item.id = usbdev 
        item.size = usbbytesize
        item.sharesize = 2000

        pixmap = QPixmap('pixmaps/drive.png')
        pixmap = pixmap.scaled(QtCore.QSize(64,64))
        item.picture = QtWidgets.QLabel()
        item.picture.setPixmap(pixmap)
        item.picture.setAlignment(QtCore.Qt.AlignVCenter|QtCore.Qt.AlignLeft)
       
        usbbytesize = float(usbbytesize)/1000/1000/1000
       
        item.info = QtWidgets.QLabel('      %s %s ( %s ) %.2fGB'  % (device_info, devicemodel, item.id, usbbytesize ))
        item.info.setAlignment(QtCore.Qt.AlignRight)
        
        item.warn = QtWidgets.QLabel('')
        item.warn.setAlignment(QtCore.Qt.AlignVCenter|QtCore.Qt.AlignRight)
        
        item.placeholder = QtWidgets.QLabel('      ')
        
        item.comboBox = QtWidgets.QComboBox()
        item.comboBox.addItem("0.5 GB")
        item.comboBox.addItem("1 GB")
        item.comboBox.addItem("2 GB")
        item.comboBox.addItem("4 GB")
        item.comboBox.addItem("8 GB")
        item.comboBox.addItem("16 GB")
        item.comboBox.setFixedWidth(180)
        item.comboBox.setCurrentIndex(2)
        item.comboBox.currentIndexChanged.connect(lambda: self.checkSize(item))
        
        item.progressbar= QtWidgets.QProgressBar(self)
        item.progressbar.setInvertedAppearance(True)
        
        grid = QtWidgets.QGridLayout()
        grid.setSpacing(0)
        grid.setRowStretch (1, 4)
        grid.addWidget(item.info, 0, 2)
        grid.addWidget(item.warn, 2, 2)
        grid.addWidget(item.picture, 1, 0)
        grid.addWidget(item.comboBox, 1, 2)
        grid.addWidget(item.progressbar, 2, 0)
        #grid.addWidget(item.placeholder, 3, 1)
        grid.addWidget(item.placeholder, 3, 3)

        widget = QtWidgets.QWidget()
        widget.setLayout(grid)
        
        #widget.setContextMenuPolicy(QtCore.Qt.CustomContextMenu)
        #widget.customContextMenuRequested.connect(lambda: self._on_context_menu(item.pID, item.disabled))
        
        self.ui.listWidget.addItem(item)  # add the listitem to the listwidget
        self.ui.listWidget.setItemWidget(item, widget)  # set the widget as the listitem's widget
       
        self.checkSize(item)
        
        

    def get_list_widget_items(self):
        items = []
        for index in xrange(self.ui.listWidget.count()):
            items.append(self.ui.listWidget.item(index))
        return items  
        
        
   
   
   
   
   
   
   
   
   
   
      
    def checkDevice(self, dev):
        """this function builds a list 
        of all found and confirmed usb devices 
        """
        answer = Popen(["./getflashdrive.sh","check", dev ], stdout=PIPE)
        answer = str(answer.communicate()[0])  # das shellscript antwortet immer mit dem namen der datei die die informationen beinhaltet
        answerlist= answer.split(';')    #  "0 $USB; 1 $DEVICEVENDOR; 2 $DEVICEMODEL; 3 $DEVICESIZE; 4 $USBBYTESIZE"
        print answerlist
        
        usbdev = answerlist[0]    #erster teil ist usb gerät
        device_info = answerlist[1]
        try:
            devicemodel = answerlist[2]
            devicesize = answerlist[3]
            usbbytesize = answerlist[4]
        except: IndexError
            
        if device_info == "NOUSB" or device_info == "SYSUSB" or device_info == "NOLIVE" or device_info == "LOCKED":
            # be more verbose if there is no usb found at all or if the only drive found is the sysusb  - we could iterate over a separate list of all devices later
            return  # we do not use those devices
        else:
            devlist = []   #rebuild list of found devices and check if a device is already in it
            for devname in self.devices:
                devlist.append(devname[0])
                                   
            if usbdev in devlist:
                print "already in list"
            else:
                # erstelle eine umfassende liste mit geräteinformationen
                self.devices.append([usbdev, device_info, devicemodel, devicesize, usbbytesize])
                
        return 
 
    
    
    
    
    
    
    def checkSize(self, item):
   
        devicesize = int(item.size)/1024/1024
        sharesize = self.getShareSize(item)
        
        if devicesize-6000-sharesize > 0:   #4GB for the system 2GB  casper-rw + SHARE
            print "device size ok"
            pixmap = QPixmap('pixmaps/driveyes.png')
            pixmap = pixmap.scaled(QtCore.QSize(64,64))
            item.picture.setPixmap(pixmap)
            item.sharesize = sharesize
            item.warn.setText("<b>Alles Ok</b>")
            self.ui.copy.setEnabled(True)
            return True
        else:
            print "device to small %s" % item.id
            
            item.warn.setText("<b>Zu wenig Speicherplatz</b>")
            pixmap = QPixmap('pixmaps/driveno.png')
            pixmap = pixmap.scaled(QtCore.QSize(64,64))
            item.picture.setPixmap(pixmap)
            item.sharesize = 0
            self.ui.copy.setEnabled(False)
           
            return False
        

 
  
        
    def getShareSize(self, item):
        sharesize=str(item.comboBox.currentText())
        if sharesize == "0.5 GB":
            sharesize = 500
        elif sharesize == "1 GB":
            sharesize = 1000
        elif sharesize == "2 GB":
            sharesize = 2000
        elif sharesize == "4 GB":
            sharesize = 4000
        elif sharesize == "8 GB":
            sharesize = 8000
        elif sharesize == "16 GB":
            sharesize = 16000
        return sharesize
            
            
            
            
            
            
            
    def startCopy(self):
        items = self.get_list_widget_items()
        if items:
            self.extraThread.start()
        else:
            return
                
     
     


    def onAbbrechen(self):    # Exit button - remove ALL lockfiles
        for i in self.proposed:
            try:
                os.remove("%s.lock" % i) 
            except:
                pass
        self.ui.close()



class  Worker(QtCore.QObject):
    def __init__(self, meindialog):
        super(Worker, self).__init__()
        self.meindialog = meindialog
    #processed = QtCore.Signal(int)
    #finished = QtCore.Signal()
    
    def doCopy(self):
        if self.meindialog.ui.copydata.checkState():
            copydata = True
        else:
            copydata = False
        
        if self.meindialog.ui.update.checkState():
            update = True
        else:
            update = False
        
        
        
        items = self.meindialog.get_list_widget_items()
        for item in items:
            self.meindialog.ui.listWidget.scrollToItem(item,QtWidgets.QAbstractItemView.PositionAtTop)
            #get rid of spaces an special chars in order to pass it as parameter - i know there is a better way ;-)
            iteminfo = item.info.text().replace("(","").replace(")","").replace("  "," ").replace("   ","").replace(" ","-")
            method = "copy"
            #progressbar= Qtwidgets.QProgressBar(self)
            #progressbar.setGeometry(200,80,250,20)
            self.meindialog.ui.copy.setEnabled(False)
            self.meindialog.ui.exit.setEnabled(False)
            time.sleep(1)
            
            completed = float(0)
            if update is True:   #less steps
                increment = float(2.5)
            else:
                increment = float(1.0)
        
            p=Popen(['./getflashdrive.sh',str(method),str(item.sharesize), str(copydata), str(item.id), str(iteminfo), str(update)],stdout=PIPE, stderr=STDOUT, bufsize=1)
            with p.stdout:
                for line in iter(p.stdout.readline, b''):
                    line = line.strip('\n')
                    item.warn.setText(line)
                    print line
                    
                    if "0%" not in line:    # rsync delivers 200 entries with 0% sometimes - do not increment
                        completed += increment
                    
                    item.progressbar.setValue(completed)
                    
                    if "FILENUMBER" in line:   #keyword FILENUMBER liefert anzahl an files für rsync
                        number=line.split(",")
                        number=float(number[1])
                        increment = float(84/number)
                        item.progressbar.setValue(item.progressbar.value()+1) #aus irgendeinem grund wird setText nur dann durchgeführt wenn progressbar updated
                        
                    elif "CASPER" in line:   #keyword CASPER liefert anzahl an files für rsync
                        number=line.split(",")
                        number=float(number[1])
                        item.progressbar.setValue(18)
                        increment = float(80/number)
                        item.progressbar.setValue(item.progressbar.value()+1)
                    
                    if "size" in line:  #rsync is finished - advance 1 step
                        increment = float(1)   # progressbar geht nur weiter beim überschreiten ganzer zahlen - setze wieder auf 1 sonst werden letze einträge nicht visualisiert
                        item.progressbar.setValue(item.progressbar.value()+1)
                    if "FAILED" in line:
                        item.progressbar.setValue(100)
                        item.warn.setText("Kopiervorgang fehlgeschlagen")
                    elif "END" in line:
                        item.progressbar.setValue(100)
                        item.warn.setText("Kopiervorgang abgeschlossen")
            p.wait()
            
        #self.finished.emit()   
        self.meindialog.ui.copy.setEnabled(True)
        self.meindialog.ui.exit.setEnabled(True)
    
    


app = QtWidgets.QApplication(sys.argv)
dialog = MeinDialog()
dialog.ui.show()
sys.exit(app.exec_())
