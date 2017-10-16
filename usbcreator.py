#! /usr/bin/env python
# -*- coding: utf-8 -*-
import sys, os, string, ipaddress
from PyQt5 import QtCore, uic, QtWidgets
from PyQt5.QtGui import *
from subprocess import Popen, PIPE
import subprocess, sip




class MeinDialog(QtWidgets.QDialog):
    def __init__(self):
        QtWidgets.QDialog.__init__(self)
        self.ui = uic.loadUi("usbcreator.ui")        # load UI
        self.ui.setWindowIcon(QIcon("pixmaps/drive.png"))
        self.ui.search.clicked.connect(self.searchUSB)     
        self.ui.exit.clicked.connect(self.onAbbrechen)        # setup Slots
        self.ui.copy.clicked.connect(self.startCopy)
    
        self.proposed = ["sda","sdb","sdc","sdd","sde","sdf","sdg","sdh","sdi","sdj","sdk","sdl","sdm","sdn","sdo","sdp","sdq","sdr","sds","sdt","sdu","sdv","sdw","sdx","sdy","sdz"]
       
        
        
    
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
        for widget in items:
            sip.delete(widget)
        
        
        #build size information for every device
        for deviceentry in self.devices:
            usbdev = deviceentry[0]
            device_info = deviceentry[1]
            devicemodel = deviceentry[2]
            devicesize = deviceentry[3]
            usbbytesize = deviceentry[4]
            self.createWidget(usbdev, device_info, devicemodel, usbbytesize)
           
       
            
        
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
        item.setSizeHint(QtCore.QSize(60, 90));
        #store important information on the widget
        item.id = usbdev 
        item.size = usbbytesize
        item.sharesize = 2000

        pixmap = QPixmap('pixmaps/drive.png')
        pixmap = pixmap.scaled(QtCore.QSize(64,64))
        item.picture = QtWidgets.QLabel()
        item.picture.setPixmap(pixmap)
        item.picture.setAlignment(QtCore.Qt.AlignLeft)
       
        usbbytesize = float(usbbytesize)/1000/1000/1000
       
        item.info = QtWidgets.QLabel('      %s %s ( %s ) %.2fGB'  % (device_info, devicemodel, item.id, usbbytesize ))
        item.info.setAlignment(QtCore.Qt.AlignRight)
        
        item.warn = QtWidgets.QLabel('')
        item.warn.setAlignment(QtCore.Qt.AlignRight)
        
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
        
        grid = QtWidgets.QGridLayout()
        grid.setSpacing(0)
        grid.setRowStretch (1, 4)
        grid.addWidget(item.info, 0, 1)
        grid.addWidget(item.warn, 2, 1)
        grid.addWidget(item.picture, 1, 0)
        grid.addWidget(item.comboBox, 1, 1)

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
            print "device to small"
            pixmap = QPixmap('pixmaps/driveyes.png')
            pixmap = pixmap.scaled(QtCore.QSize(64,64))
            item.picture.setPixmap(pixmap)
            #item.picture.setAlignment(QtCore.Qt.AlignRight)
            item.sharesize = sharesize
            item.warn.setText("<b>Alles Ok</b>")
            return True
        else:
            print "device to small"
            item.warn.setText("<b>Zu wenig Speicherplatz</b>")
            pixmap = QPixmap('pixmaps/driveno.png')
            pixmap = pixmap.scaled(QtCore.QSize(64,64))
            item.picture.setPixmap(pixmap)
            item.sharesize = 0
            #item.picture.setAlignment(QtCore.Qt.AlignRight)
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
        if self.ui.copydata.checkState():
            copydata = True
        else:
            copydata = False
        
        items = self.get_list_widget_items()
        if items:
            for item in items:
                print item.sharesize
                print item.id
                print item.size
                print copydata
                print "-------"
        
                command = "./getflashdrive.sh copy %s %s %s" %(item.sharesize, copydata, item.id )
        
                self.ui.close()
                # os.system(command)
        
        else:
            return
                
                
                        
                        
                        
            
            
            
            
        
   
    



    def onAbbrechen(self):    # Exit button - remove ALL lockfiles
        for i in self.proposed:
            try:
                os.remove("%s.lock" % i) 
            except:
                pass
        self.ui.close()




app = QtWidgets.QApplication(sys.argv)
dialog = MeinDialog()
dialog.ui.show()
sys.exit(app.exec_())
