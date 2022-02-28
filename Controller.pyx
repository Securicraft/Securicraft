#!/usr/bin/python3.9
# -*- coding: utf-8 -*-
'''
First two lines MUST add on top in python script that run on RaspberryOS/raspbian
1st. line, tell system where is python interpreter
2nd. line, tell system use utf-8 unicode
==================================================================================
CHANGE LOG:
1. Update configuration file (add LocalServer)
2. Cancel method Prevent card reuse. 02/11/2021
3. Change method get timestamp from server. 02/11/2021
4. Change method read RFID from decimal(10digits) to hexadecimal(8digits). 02/11/2021
5. Change method insert cursor into blist on DownloadData(). 05/11/2021

BUG FIXED
1. Fixed system crash when network fail on CheckStateData(). 02/11/2021
'''
def PrintException(args):
    '''Correct all error to text file'''
    import linecache;
    exc_type, exc_obj, tb = sys.exc_info();
    frame       = tb.tb_frame;
    lineno      = tb.tb_lineno;
    filename    = frame.f_code.co_filename;
    linecache.checkcache(filename);
    fileline    = linecache.getline(filename, lineno, frame.f_globals);
    logfilename = time.strftime("%Y%m%d")+'.errlog';
    logfileopen = open(logfilename,'a');
    if args is None:        #debug script with argrument None is tracing error line in script
        logfileopen.write('Exception in ({}, Line {} "{}"): {}'.format(filename, lineno, fileline.strip(), exc_obj)+"\n"+time.strftime("%Y-%m-%d <> %H:%M")+"\n");        
    else:
        logfileopen.write(str(args)+ " : " +datetime.datetime.now().strftime("%d-%b-%Y (%H:%M:%S.%f)"+"\n"));
        logfileopen.write('Exception in ({}, Line {} "{}"): {}'.format(filename, lineno, fileline.strip(), exc_obj)+"\n"+time.strftime("%Y-%m-%d <> %H:%M")+"\n");                
    logfileopen.close();
    del linecache, frame, fileline, lineno, filename, logfilename, logfileopen;
    return;

def CreateList():
    file = open("ip.c", "w");
    file.write("//From https://man7.org/linux/man-pages/man3/getifaddrs.3.html\n");
    file.write("#define _GNU_SOURCE \n");
    file.write("#include <arpa/inet.h>\n");
    file.write("#include <sys/socket.h>\n");
    file.write("#include <netdb.h>\n");
    file.write("#include <ifaddrs.h>\n");
    file.write("#include <stdio.h>\n");
    file.write("#include <stdlib.h>\n");
    file.write("#include <unistd.h>\n");
    file.write("#include <string.h>\n");
    file.write("#define LSIZ 128 \n");
    file.write("#define RSIZ 10 \n");
    file.write("int main(int argc, char *argv[])\n");
    file.write("{\n");
    file.write("struct ifaddrs *ifaddr;\n");
    file.write("int family, s;\n");
    file.write("char host[NI_MAXHOST];\n");
    file.write("FILE *fptr;\n");
    file.write('fptr = fopen("ip.txt", "w");\n');
    file.write("if (getifaddrs(&ifaddr) == -1)\n");
    file.write("{\n");           
    file.write("perror('getifaddrs');\n");
    file.write("exit(EXIT_FAILURE);\n");
    file.write("}\n");
    file.write("for (struct ifaddrs *ifa = ifaddr; ifa != NULL;\n");
    file.write("ifa = ifa->ifa_next)\n");
    file.write("{\n");
    file.write("if (ifa->ifa_addr == NULL)\n");
    file.write("continue;\n");
    file.write("family = ifa->ifa_addr->sa_family;\n");
    file.write("if (family == AF_INET || family == AF_INET6) {\n");
    file.write("s = getnameinfo(ifa->ifa_addr,(family == AF_INET) ? sizeof(struct sockaddr_in) : sizeof(struct sockaddr_in6), host, NI_MAXHOST, NULL, 0, NI_NUMERICHOST);\n");
    file.write("if (s != 0) {\n");
    file.write('printf("getnameinfo() failed: %s ", gai_strerror(s));\n');
    file.write("exit(EXIT_FAILURE);\n");
    file.write("}\n");
    word = R'fprintf(fptr, "%s\n", host);'
    file.write(word+"\n");   #save result to file
    file.write("}\n");        
    file.write("else if (family == AF_PACKET && ifa->ifa_data != NULL) {\n");
    file.write("struct rtnl_link_stats *stats = ifa->ifa_data;\n");
    file.write("}\n");
    file.write("}\n");
    file.write("fclose(fptr);\n");
    file.write("freeifaddrs(ifaddr);\n");
    
    file.write("char line[RSIZ][LSIZ];\n");
    file.write('FILE *fp = fopen("ip.txt", "r");\n');
    file.write("int i = 0;\n");
    file.write("while(fgets(line[i], LSIZ, fp))\n");
    file.write("{\n");    
    file.write("line[i][strlen(line[i]) - 1] = '\0';\n");
    file.write("i++;\n");
    file.write("}\n");
    file.write("return (line[1], line[4]);\n");
    file.write("}\n");
    file.close();
    return;
def IpAndMac():
    CreateList();
    p = subprocess.run(["gcc","-w", "ip.c"], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if p.returncode != 0:
        print(p.stderr);
        raise SystemExit;
    subprocess.call(["sudo", "./a.out"])
    subprocess.call(["sudo", "rm", "a.out"])
    subprocess.call(["sudo", "rm", "ip.c"])
    file = open("ip.txt", "r", encoding='UTF-8');
    lines = file.readlines();
    file.close();
    subprocess.call(["sudo", "rm", "ip.txt"])
    if len(lines) >= 5:                         #eth0 With wlan0
        x = re.search("%", lines[4].strip());
        mac = lines[4][0:x.span()[0]];             #Cut "%eth0"
        return (lines[1].strip(), mac);
    elif len(lines) >= 3:                       #eth0 or wlan0
        x = re.search("%", lines[3].strip());
        mac = lines[3][0:x.span()[0]]           #Cut "%eth0 or %wlan0"
        return (lines[1].strip(), mac);
    else:
        print("NOT detect ethernet network!\n  Consult your admin\n  Application will sutdown");
        raise SystemExit;

'''Main script start here'''
DB = "";
try:
    import time, sys, subprocess;
    print("Load Standard Library :os, sys, time, datetime, platform, re, csv");
    import os, sys, time, datetime, platform, re, csv;
    import datetime as datetime;
    from time import gmtime, strftime;
    import os.path;
    print("Load Library :subprocess, socket");
    import subprocess;
    import socket;
    print("Load Library :configparser, collections");
    import configparser, collections;
    print("Load Library :requests");
    print("Load Library :threading");
    import threading;
    from threading import Thread;
    '''
    try:
        print("Load MS SQL Server connector :pymssql");    
        import pymssql as DB;
    except:
        print("Must install dependencied library before use by:");
        print("sudo pip3 install python-dev-tools");
        print("sudo apt install freetds-dev -y");
        print("sudo pip3 install pymssql");
        print("Then, run this script again...");
        print("If MS SQL Server NOT load, Then systen will replace with \nMySQL Server connector :MySQL.connector");
    '''
    try:
        import mysql.connector as DB;
    except Exception as err:
        PrintException(err);
        print("Must install dependencied library before use by:");
        print("sudo pip3 install mysql-connector-python");
        print("system will use userinfo.txt, If it exist please wait...");
        from os import path
        if path.isfile("userinfo.txt"):
            pass;
        else:
            print("Sorry! not has user information");
            print("System will exit");
            raise SystemExit;
    print("Load Library :serial, RPi.GPIO");
    import serial;
    import RPi.GPIO as IO;

    try:
        print("Load Library :RFID");
        from pyrc522 import RFID;
    except:
        print("Must install dependencied library before use by:");        
        print("sudo pip3 install pyrc522");
        raise SystemExit;    
    try:
        print("Load Library :generic input event interface");
        from evdev import InputDevice, categorize, ecodes;
        import evdev;
    except:
        print("Must install dependencied library before use by:");        
        print("sudo pip3 install evdev");
        raise SystemExit;
    
    try:
        print("Load Library :I2C");
        import i2clcd;
    except:
        print("Must install dependencied library before use by:");        
        print("sudo pip3 install i2clcd");
        raise SystemExit;

    print("Load Library complete");
except Exception as err:
    PrintException(None);
    print(err);
    raise SystemExit;

MyDir = os.getcwd();
print("Now working at directory : "+MyDir);

import glob;
filelist = glob.glob('*.csv');
filelist.sort();
if len(filelist) > 0:
    for file in filelist:
        if file == time.strftime("%Y%m%d")+'.csv':
            break;
        else:
            if platform.system() == 'Linux':
                subprocess.call(['sudo', 'rm', '-v', file], );
            else:
                os.remove(file);
del glob;
print("Load necessary variables")

#Default value
ConfigFile  = 'reader.conf';
EventFile   = 'event.txt';
UserInfo    = "userinfo.txt";
DOORTYPE    = 0;                    #Type of access, 0=ENTER and 1=EXIT, default = 0
DOORDELAY   = 5;                    ###Delay times(sec.) for door open
DOWNLOADTIME= 5;                    ###iNTERVAL TIME FOR CHECK USER INFORM.(Min.)

SQLHOST     = '127.0.0.1';          ###MySQL or MSSQL LocalServer
SQLUSER     = 'admin';
SQLPASS     = 'admin';
DATABASE    = 'userinfo';

LOCALHOST     = '127.0.0.1';        ###LocalServer
LOCALUSER     = 'admin';             ###User name on target server
LOCALPASS     = 'admin';         ###Password
LOCALPORT     = 3306;               ###Default port

IO.setmode(IO.BOARD);
IO.setwarnings(False);
'''
Raspi assign 16 pins for INPUT/OUTPUT:
 7, 11, 13, 15
16, 18, 22, 29
31, 32, 33, 35
36, 37, 38, 40
Other pins for SEND/RECIEVE signal(SPI, I2C, OneWire, Rx/Tx etc.)
'''
SPIN    = 36;                           ###Pin number on GPIO that use for activated DOOR signal

ReturnCode = [];
blist = [];                             ###manisfest list name 'blist' that will store userinfo.txt along this script
DirList     = os.listdir(os.getcwd());  ###file name list in current directory

print("Load necessary variables complete")
print("Load configuration ...");

for line in DirList:
    if(re.match(EventFile, line)):
        EventFile = (line.rstrip()).lstrip();

    config   = configparser.ConfigParser();
    if ConfigFile in DirList:                   ###reader.conf is exist
        config.read(ConfigFile);
        
        SQLHOST  = config['SQLServer']['sqlhost'];
        SQLUSER  = config['SQLServer']['sqluser'];
        SQLPASS  = config['SQLServer']['sqlpass'];
        DATABASE = config['SQLServer']['database'];
        
        LOCALHOST  = config['LOCALServer']['LOCALhost'];
        LOCALUSER  = config['LOCALServer']['LOCALuser'];
        LOCALPASS  = config['LOCALServer']['LOCALpass'];
        LOCALPORT  = int(config['LOCALServer']['LOCALport']);
        
        EventFile = config['DEFAULT']['EventFile'];
        DOORTYPE  = config['DEFAULT']['DOORTYPE'];
        DOORDELAY = int(config['DEFAULT']['DOORDELAY']);
        DOWNLOADTIME = int(config['DEFAULT']['DOWNLOADTIME']);
        
        IPAddr    = config['NETWORK']['ipaddress'];
        HostName  = config['NETWORK']['hostname'];
        NodeID    = config['NETWORK']['nodeid'];
        
    else:                                       ###reader.conf is not exist
        i = IpAndMac();
        from subprocess import check_output
        print('Configuration file does not exist, System will create default');

        config['DEFAULT'] ={'EventFile': EventFile,
                            'UserInfo': UserInfo,
                            'DOORTYPE' : DOORTYPE,
                            '#DOORTYPE': "Type of access, 0=ENTER and 1=EXIT, default = 0",
                            'DOORDELAY' : DOORDELAY,
                            '#DOORRELAY': "Delay times(sec.) for door open then, close it., default = 5",
                            'DOWNLOADTIME': DOWNLOADTIME
                             };        
    
        config['SQLServer'] = {'SQLHOST':SQLHOST,
                         'SQLUSER':SQLUSER,
                         'SQLPASS':SQLPASS,
                         'DATABASE':DATABASE
                         };
        config['LOCALServer'] = {'LOCALHOST':LOCALHOST,
                 'LOCALUSER': LOCALUSER,
                 'LOCALPASS': LOCALPASS,
                 'LOCALPORT': LOCALPORT
                 };
        config['NETWORK'] ={
            'ipaddress': i[0],
            '#IPAddress': "IP Address of this device.",
            'HostName': check_output(['hostname']).decode("utf-8").rstrip(),
            '#HostName': "Name of this device.",
            'NodeID' : i[1],
            '#NodeID': "UUID of this device.",
            };
        del check_output;
        with open('reader.conf', 'w') as configfile:
            config.write(configfile);
            configfile.close();
        config.read(ConfigFile);
        SQLHOST  = config['SQLServer']['sqlhost'];
        SQLUSER  = config['SQLServer']['sqluser'];
        SQLPASS  = config['SQLServer']['sqlpass'];
        DATABASE = config['SQLServer']['database'];
        LOCALHOST  = config['LOCALServer']['LOCALhost'];
        LOCALUSER  = config['LOCALServer']['LOCALuser'];
        LOCALPASS  = config['LOCALServer']['LOCALpass'];
        LOCALPORT  = int(config['LOCALServer']['LOCALport']);
        EventFile = config['DEFAULT']['EventFile'];
        DOORDELAY = int(config['DEFAULT']['DOORDELAY']);
        DOWNLOADTIME = int(config['DEFAULT']['DOWNLOADTIME']);
        IPAddr    = config['NETWORK']['ipaddress'];
        HostName  = config['NETWORK']['hostname'];
        NodeID    = config['NETWORK']['nodeid'];
        break;
print("Load configuration complete");

class bcolors:
    '''The above ANSI escape code will set the text colourหs. The format is;
        \033[1;1;40m is normal bright text.       
            \033[ = Escape code, this is always the same
            1     = Style, 1 for normal.
            32    = Text colour, 32 for bright green.
            40m   = Background colour, 40 is for black.
    from https://ozzmaker.com/add-colour-to-text-in-python/
    '''
    
    ERROR   = '\033[1;31;40m'
    MESSAGE = '\033[1;32;40m'
    WARNING = '\033[1;33;40m'    
    OKBLUE  = '\033[1;34;40m'
    OKCYAN  = '\033[1;36;40m'
    COMMON  = '\033[1;37;40m'

class CreateData:
    def __init__(self):
        global ReturnCode, OldRecTime, EventString;
        OldRecTime = float();
        print("Requesting user information from database server...");
        self.FileExist = os.path.isfile(os.getcwd()+'/'+EventFile);
        self.CheckStateData();
        OldRecTime = NewRecTime;
        self.DownloadData();

    def DownloadData(self):
        'Code below for download user data from MS SQL Server'
        global blist
        
        try:
            if 'mysql'.lower() in str(DB):
                print(bcolors.MESSAGE+"Download user information Please wait...");
                try:
                    self.cnx = DB.connect( user = LOCALUSER,
                                        password= LOCALPASS,
                                        host    = LOCALHOST,
                                        database= DATABASE)
                    
                    self.curs    = self.cnx.cursor();
                    self.SQLList = ["SELECT * FROM userinfo"];
                    start = float(datetime.datetime.utcnow().timestamp());
                    self.curs.execute(self.SQLList[0]);
                    end = float(datetime.datetime.utcnow().timestamp());                    
                    print("time in SQL SELECT = ", "{:.2f}".format(end - start), " seconds.");
                    start = float(datetime.datetime.utcnow().timestamp());
                    if self.curs:
                        blist = [];
                        blist = [x for x in self.curs];
                    
                    print(bcolors.MESSAGE+"Download UserInfromation from LocalServer complete");
                    end = float(datetime.datetime.utcnow().timestamp());
                    print("time in insert data to list = ", "{:.2f}".format(end - start), " seconds.");
                    print("With elements of list = ", "{:,.0f}".format(len(blist)), " element(s).");
                    self.curs.close();
                    self.cnx.close();
                except Exception as err:
                    PrintException("{}".format(err));
                    print(bcolors.ERROR+"Database server has fail with: {}".format(err));
                    print(bcolors.MESSAGE+"Consult your admin immediately!");
                    
                    print(bcolors.WARNING+'system will use "userinfo.txt"(if exist)');
                    print(bcolors.COMMON);
                    blist = [];
                    try:
                        with open(UserInfo,mode='r', encoding="utf-8") as f:
                            contents = f.readlines();
                            for line in contents:
                                blist.append(line);          ###store detail of userinfo.txt to blist line to line
                    except:
                        print(bcolors.ERROR+"userinfo.txt NOT exist!");
                        raise SystemExit;
            else:
                #----------------------------------------------
                print(bcolors.WARNING+'system will use "userinfo.txt"');
                print(bcolors.COMMON);
                blist = [];
                with open(UserInfo,mode='r', encoding="utf-8") as f:       
                    contents = f.readlines();
                    for line in contents:
                        blist.append(line);          ###store detail of userinfo.txt to blist line to line
                #----------------------------------------------
        except Exception as err:
            print(bcolors.ERROR+"Local Server has fail with: {}\n Consult your admin immediately!".format(err));
            PrintException(err);
            raise SystemExit;
        
    def SearchFromCode(self, args):
        for self.tup in blist:
            if args in self.tup:return self.tup;
            
    def UploadData(self):
        'Code below for upload data to MS SQL Server'
        if 'mysql'.lower() in str(DB):
            try:                                            #case connect to server success 
                self.x          = re.search("SSN", EventString);
                self.y          = re.search(",", EventString);
                self.ssncode    = EventString[self.x.span()[1]+1:self.y.span()[0]].strip();
                self.device     = HostName;
                self.x          = re.search("VerifyCode=", EventString);
                self.z          = re.search("CheckType=", EventString);
                self.status     = str(EventString[self.x.span()[1]:self.x.span()[1]+1]);    #change integer to string
                self.checktype  = EventString[self.z.span()[1]:self.z.span()[1]+5];
                self.pattern = r'[^A-Z]+';
                self.checktype  = re.sub(self.pattern, '', self.checktype);
                self.cnx = DB.connect(  user    = LOCALUSER,
                                        password= LOCALPASS,
                                        host    = LOCALHOST,
                                        database= DATABASE)            
                self.curs    = self.cnx.cursor();
                self.SQLList = "INSERT INTO log(id, ssn, devices, status, checktype, date_update) VALUES (%s, %s, %s, %s, %s, %s)";
                self.curs.execute(self.SQLList, (0, self.ssncode, self.device, self.status, self.checktype, datetime.datetime.now().strftime("%Y-%m-%d %H:%M")));
                self.cnx.commit();
                self.curs.close();
                self.cnx.close();
            
            except Exception as err:
                print(bcolors.ERROR+"log table has fail\n Consult your admin immediately!");
                print(bcolors.COMMON);
                PrintException(err);                
        else:
            if self.FileExist:
                self.write2file(EventString);
            else:
                self.createfile(EventString); 
        self.CheckStateData();    
        return


    def CheckStateData(self):
        # Return update time in last row of userinfo
        global NewRecTime;
        PORT = int();
        if 'mysql'.lower() in str(DB):
            PORT = 3306;
            try:
                import socket;
                s = socket.create_connection((SQLHOST, PORT), DOWNLOADTIME);
                s.close();
                del socket;
                self.cnx  = DB.connect( user     = LOCALUSER,
                                        password= LOCALPASS,
                                        host    = LOCALHOST,
                                        database= DATABASE)            
                self.curs = self.cnx.cursor();
                self.SQL  = "SELECT UPDATE_TIME FROM information_schema.tables WHERE  TABLE_SCHEMA = 'userinfo' AND TABLE_NAME = 'userinfo'";
                self.x = self.curs.execute(self.SQL);
                self.x = self.curs.fetchone()[0];
                
                if self.x != None:
                    NewRecTime =  datetime.datetime.timestamp(self.x);
                else:
                    NewRecTime = float();
                self.curs.close();
                self.cnx.close();
                return (NewRecTime, True);
            except Exception as err:
                print(str(err));
                PrintException(err);
                NewRecTime =  datetime.datetime.timestamp(datetime.datetime.now());
                return (NewRecTime, False);
        else:
            print(bcolors.ERROR+"Database server has fail!");
            print(bcolors.COMMON);
            if (OldRecTime):
                pass;
            else:
                NewRecTime =  datetime.datetime.timestamp(datetime.datetime.now());
            return (NewRecTime, False);

    def write2file(self, argv):                         ###adding event to text file when user access at this time after open the door
        self.FilePath = os.getcwd()+'/'+EventFile;
        self.file = open(self.FilePath,'a');
        self.file.writelines("log table has fail\n"+argv +'\n');
        self.file.close();
        
    def createfile(self,argv):                          ###write event to text file when found server get it and delete it after save to transaction database
        self.FilePath = os.getcwd()+'/'+EventFile;
        self.file=open(self.FilePath, 'w');
        self.file.write("log table has fail\n"+argv+'\n');
        self.file.close();
        self.FileExist = os.path.isfile(os.getcwd()+'/'+EventFile);
        
class BReader(Thread):                                  #Extend threading class
    def __init__(self):                                 #Initiate object class
        self.NOBARCODE = False;                         #define var. for check Barcode reader is present?
        Thread.__init__(self);                          #overriding __init__ method (__init__ is built-in method), neccessary for python OOP
        #scancodes is ascii table
        self.scancodes = {
            0: None, 1: u'ESC', 2: u'1', 3: u'2', 4: u'3', 5: u'4', 6: u'5', 7: u'6', 8: u'7', 9: u'8',
            10: u'9', 11: u'0', 12: u'-', 13: u'=', 14: u'BKSP', 15: u'\t', 16: u'Q', 17: u'W', 18: u'E', 19: u'R',
            20: u'T', 21: u'Y', 22: u'U', 23: u'I', 24: u'O', 25: u'P', 26: u'[', 27: u']', 28: u'\n', 29: "",
            30: u'A', 31: u'S', 32: u'D', 33: u'F', 34: u'G', 35: u'H', 36: u'J', 37: u'K', 38: u'L', 39: u';',
            40: u'"', 41: u'`', 42: "", 43: u'\\', 44: u'Z', 45: u'X', 46: u'C', 47: u'V', 48: u'B', 49: u'N',
            50: u'M', 51: u',', 52: u'.', 53: u'/', 54: "", 56: "", 100: ""
        };
        self._stopevent = threading.Event();
        thread = threading.Thread(target=self.run, args=());
        thread.daemon = True;                            # Daemonize thread
        thread.start();                                  # Start the execution
        

    def find_device(self):
        self.devices = [evdev.InputDevice(path) for path in evdev.list_devices()];
        if self.NOBARCODE:
            return;
        if len(evdev.list_devices()) == 0:
            self.NOBARCODE = True;
            print(bcolors.ERROR+"Not found barcode scanner!\n");
            print(bcolors.ERROR+"System just read RFID card/tag input.");            
            self._stopevent.set();
            return;
        for self.device in self.devices:
            if("barcode" in self.device.name.lower()):
                return self.device

    def reader(self):
        self.device = self.find_device();
        if self.NOBARCODE:
            return;
        try:
            self.buffer = '';
            for self.event in self.device.read_loop():
                if self.event.type == ecodes.EV_KEY:
                    self.eventData = categorize(self.event)
                    if self.eventData.keystate == 1:
                        self.key_lookup = self.scancodes.get(self.eventData.scancode)
                        self.buffer = str(self.buffer) + str(self.key_lookup)
                        if(self.eventData.scancode == 28):
                            file = open("barcode", "w");
                            file.write(str(self.buffer[:-1]).strip());
                            file.close();                        
                            return;
        except:
            PrintException(str(sys.exc_info()[0]));
            print( bcolors.ERROR+"Unexpected error:", sys.exc_info());
            pass;

    def run(self):                              #overridng run method (run is built-in method)
        while True:
            self.reader();
            time.sleep(0.5);

def RightCheck():
    if Right == "1":
        IO.setmode(IO.BOARD);
        IO.setup(SPIN,IO.OUT);
        IO.output(SPIN, IO.HIGH);  
        time.sleep(DOORDELAY);
        IO.cleanup();
    else:
        if NOLCD:
            return;
        else:
            lcd.set_backlight(0);
            time.sleep(0.25);
            lcd.set_backlight(1);
            time.sleep(0.25);
            lcd.set_backlight(0);
            time.sleep(0.25);
            lcd.set_backlight(1);
            time.sleep(0.25);
    return;

#=======================================#
#=========programme start here==========#
#=======================================#
#Create data connection and user information
blist = [];
try:
    #print(bcolors.WARNING+nodeID)
    Data = CreateData();
except Exception as err:
    PrintException(err);
    print(bcolors.ERROR+str(err));
    raise SystemExit;

#Create variable for save reader
devices = [evdev.InputDevice(path) for path in evdev.list_devices()];
i=j = list();
for dev in devices:
    if len(dev.name) > 5:
        i.append(dev.path+", "+dev.name);
i.sort();
for j in i:
    if "RFID" in j:
        print("Now we connected to Reader(RFID)   : "+ j);
        #Create RFID Reader threads
        RFIDReader  = RFID();
    elif "BARCODE" in j:
        print("Now we connected to Reader(Barcode): "+ j);
        #Create BarCode Reader threads
        BR =  BReader();
if len(i)==0:
    print("None of reader!\nSystem will shutdown NOW!")
    raise SystemExit
else:
    del i, j;

Rbefore     = "Rbefore";
Rafter      = "Rafter";
Control     = True;                     ###Main loop control
VerifyCode  = ["0", "1"];               #0 = Deny, 1 = Grant
if int(DOORTYPE) == 0:
    CheckType   = "ENTER";
else:
    CheckType   = "EXIT";
Right       = VerifyCode[0];            #DENY is default
RFret       = "";                       #RFID code return from reader ([000,000,000,000,000,xxx,xxx])

#Start send output to lcd
try:
    NOLCD = False;
    lcd = i2clcd.i2clcd(i2c_bus=1, i2c_addr=0x27, lcd_width=16);
    lcd.init();
    lcd.clear();
    lcd.print_line("Welcome.........", line=0, align='LEFT');
    lcd.print_line(strftime("%Y-%m-%d %H:%M:%S"), line=1, align='LEFT');
except IOError:
    NOLCD = True;
    print(bcolors.ERROR+"Not found LCD output!");
    print(bcolors.ERROR+"System will inform just terminal output");

print(bcolors.OKCYAN+"Everything is ready, please wait...");    
time.sleep(2);
print(bcolors.MESSAGE+"Program started");
while Control:
    try:
        if os.path.isfile('barcode'):                               #Read from Barcode
            file = open("barcode", "r")
            Bafter = file.readline();
            file.close();
            os.remove("barcode");                                    
            if Bafter: # != Bbefore:                                   #Barcode is True AND new card present
                ReturnCode  = Data.SearchFromCode(Bafter);
                if not ReturnCode:                                  #Unsuccess to search ssn code
                    ssn         = "B"+str(Bafter);
                    Right       = VerifyCode[0];
                    RFret       = "BarCodeOnly";
                else:                                               #Success search 
                    Bbefore     = Bafter;
                    ssn         = "B"+Bafter;
                    Right       = VerifyCode[1];
                    RFret       = Bafter;
                
                DateAndTime = time.strftime("%Y-%m-%d %H:%M:%S");
                EventString = "SSN="+ssn+", CheckTime="+DateAndTime+", CheckType="+CheckType+", VerifyCode="+ Right+", SensorID="+str(NodeID);
                if Right=='0': line1 = "Access Deny";
                else: line1 = "Success";
                if NOLCD:
                    print(bcolors.OKCYAN+line1, "ID :", RFret);
                else:
                    lcd.print_line(line1, line=0, align='LEFT');
                    lcd.print_line("ID"+RFret, line=1, align='LEFT');
                RightCheck();
                Data.UploadData();
                EventString = "";
                if NOLCD:
                    print(bcolors.OKCYAN+"ID :", RFret);
                else:
                    lcd.print_line("Welcome.........", line=0, align='LEFT');
                    lcd.print_line(strftime("%Y-%m-%d %H:%M:%S"), line=1, align='LEFT');

            #elif Bafter == Bbefore:                                 #Barcode is True AND privious user entry present
            #    pass;                
        elif "RFIDReader" in locals():                               #Read from RFID card
            (error, tagtype) = RFIDReader.request();
            if not error:
                RFret   = "";
                a       = [];
                z       = "";
                (error, RFuid) = RFIDReader.anticoll();
                if len(RFuid) < 5:
                    break;
                RFret   = (str(RFuid[0])+str(RFuid[1])+str(RFuid[2])+str(RFuid[3])+str(RFuid[4]));
                '''
                # Read RFID in Hexadecimal format Then, bitwise it===========================================================
                for i in range(len(RFuid)-1, 0, -1):
                    if len(hex(RFuid[i])[2:]) == 1:
                        z = "0"+str(hex(RFuid[i])[2:]);
                        a.append(z);
                    else:
                        a.append(hex(RFuid[i])[2:]);
                if len(hex(RFuid[0])[2:]) == 1:
                    z = "0"+str(hex(RFuid[0])[2:]);
                    a.append(z);
                else:
                    a.append(hex(RFuid[0])[2:]);
                a.pop(0);                                           #Cut element in list at position 0
                RFret = a[0]+a[1]+a[2]+a[3];
                #===========================================================================================================
                '''
                Rafter  = RFret;                
                #if Rafter == Rbefore:                              #RFID card is True AND privious user entry present
                #    pass;
                #else:                                              #RFID card is True AND new card present
                if Rafter:
                    Rbefore = Rafter;                               #Protect use privious card
                    ReturnCode  = Data.SearchFromCode(RFret);
                    #print("ReturnCode is : ", ReturnCode); 
                    ssn         = "R"+RFret;
                    if not ReturnCode:                              #Unsuccess to search ssn code
                        Right       = VerifyCode[0];
                    else:                                           #Success search 
                        Right    = VerifyCode[1];
                    DateAndTime = time.strftime("%Y-%m-%d %H:%M:%S");
                    EventString = "SSN="+ssn+", CheckTime="+DateAndTime+", CheckType="+CheckType+", VerifyCode="+ Right+", SensorID="+str(NodeID);
                    if Right=='0': line1 = "Access Deny";
                    else: line1 = "Success";
                    if NOLCD:
                        print(bcolors.OKCYAN+line1, "\n", "ID :", RFret);
                    else:
                        lcd.clear();
                        lcd.print_line(line1, line=0, align='LEFT');
                        lcd.print_line("ID"+RFret, line=1, align='LEFT');
                    RightCheck();
                    Data.UploadData();
                    EventString = "";
                    if NOLCD:
                        print(bcolors.OKCYAN+"ID :", RFret);
                    else:
                        lcd.print_line("Welcome.........", line=0, align='LEFT');
                        lcd.print_line(strftime("%Y-%m-%d %H:%M:%S"), line=1, align='LEFT');                
    except UnicodeEncodeError as err:
        PrintException(str(sys.exc_info()[0]));
        print( bcolors.ERROR+"Unexpected error:", sys.exc_info())
        IO.cleanup();
        
    if OldRecTime != NewRecTime:                                    #User table in database has change
        if NOLCD:
            print("Database has change\n Update data please wait...")
        else:
            lcd.clear();
            lcd.print_line("Update Database", line=0, align='LEFT');
            lcd.print_line("try again...", line=1, align='LEFT');                
        Data.DownloadData();
        OldRecTime = NewRecTime;                                    #Change new timestamp for monitor user table next time
        if NOLCD:
            print(bcolors.OKCYAN+"ID :", RFret);
        else:
            lcd.print_line("Welcome.........", line=0, align='LEFT');
            lcd.print_line(strftime("%Y-%m-%d %H:%M:%S"), line=1, align='LEFT');                   
    else:
        pass;

#=======================================#
#========= programme end here ==========#
#=======================================#
