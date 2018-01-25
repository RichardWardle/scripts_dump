#!/bin/python
#you need to ensure you have installed the azure, yaml, pytz with pip
from azure.storage.blob import BlockBlobService, PageBlobService, AppendBlobService, BlockListType, ContentSettings
import azure
import string
import os
import datetime
import logging
import platform
import time
import sys
import yaml
import pytz
import errno

#Configure logging parameters for logging - the below should eventually be moved into the
#settings files rather than being hard coded here
today = str(datetime.date.today())
log_location = "/log_location/"+today+".log" #FILL ME IN
logging.basicConfig(format='%(asctime)s %(name)-20s %(levelname)-5s %(message)s', level=logging.INFO, filename=log_location)
logger = logging.getLogger(__name__)

#this is simple log message to file and then exit passed on parameters. I want to extend this to include
#the ability to POST to sensu the results or email or something
def handleExit(message,code,method,email):
    logMessage("handleExit FATAL: "+message)
    sys.exit(code)

#takes the directory, the delay of files we want to look for and if we are in test or live MODE
#gets all the files older than file_delay and removes them if in live mode. If in test it just
#logs but takes no action
def handleLocalFiles(dir,file_delay, run):
    for root, dirs, files in os.walk(dir):
        for name in files:
            st=os.stat(os.path.join(root, name))
            age=(time.time()-st.st_mtime)
            if age >= file_delay and run == "live":
                removeLocalFile(str(os.path.join(root, name)))
            elif age >= file_delay and run == "test":
                logMessage("handleLocalFiles INFO[not deleted]: TEST MODE File:"+str(os.path.join(root, name))+" has been modified: "+str(age)+" seconds ago which is less than: "+str(file_delay)+" if we were in live mode we would have deleted this")
            else:
                logMessage("handleLocalFiles INFO[not deleted]: Mode:"+run+" File:"+str(os.path.join(root, name))+" has been modified: "+str(age)+" seconds ago which is less than: "+str(file_delay)+" we will not touch this file until after its been modified")

#Removes a file from the OS or raises the appropriate error
def removeLocalFile(func_source_file):
    global file_errors
    try:
        print(func_source_file)
        os.remove(func_source_file)
        logger.info(str("removeLocalFile INFO: Removed the following file: "+func_source_file))
    except OSError as e:
        if e.errno != errno.ENOENT:
            logger.info(str("removeLocalFile ERROR[not deleted]: FAILED to Remove the following file: "+func_source_file+ "with error: " + e.strerror))
            file_errors += 1
            raise

#Logs a message to file
def logMessage(func_message):
    log_data = func_message
    logger.info(log_data)

#find out file and open it, exit if we cant find it
def fileExist(path):
    try:
        fi = open(path)
        fi.close()
    except OSError as e:
        handleExit("validation ERROR: File:"+path+" Code: "+str(e.errno)+" Message: "+str(e.strerror),'2','0','0')
    except IOError as e:
        handleExit("validation ERROR: File:"+path+" Code: "+str(e.errno)+" Message: "+str(e.strerror),'2','0','0')

#checks our config file exsits and we can open it then loads it if it does
def getConfigFile(config_loc):
    fileExist(config_loc)
    with open(config_loc, "r") as f:
        config = yaml.load(f)
    return config

#checks if a foler exists
def check_folder_exists(path):
    if (os.path.isdir(path)):
        return True
    logger.info(str("main ERROR: Folder: "+path+" does not exist"))
    return False

#Function used to list blobs in a azure container, this calculates
#the time since the file was created and now and add its as total_seconds
#you are returned a list of name of file, size, when last modified and
# delta between last modified and now in seconds
def listAzureFiles(func_block_blob, func_container):
    try:
        generator = func_block_blob.list_blobs(func_container)
        blob_names = []
        for blob in generator:
            prop = blobProperties(func_block_blob, func_container, blob.name)
            utc_delta = (timeSinceEpochSecondsUTC(datetime.datetime.utcnow(), "") - timeSinceEpochSecondsUTC(prop.properties.last_modified, "Etc/UTC"))
            blob_names.append([blob.name, prop.properties.content_length, str(prop.properties.last_modified), utc_delta])
        return blob_names
    except Exception as e:
        handleExit(str(e),2,"0","0")

def timeSinceEpochSecondsUTC(time, timezone):
    epoch = datetime.datetime.utcfromtimestamp(0)
    if timezone != "": #set time to UTC if we dont pass a timezone
        timezone = pytz.timezone("Etc/UTC")
        epoch = timezone.localize(epoch)
    return ((time - epoch).total_seconds())

#Query and check if the blob exsists in the cloud
def checkBlobExsists(func_block_blob, func_container, func_blob_name):
    exists = func_block_blob.exists(func_container, func_blob_name)
    return exists

def blobProperties(func_block_blob, func_container, func_blob_name):
    blob_prop = func_block_blob.get_blob_properties(func_container, func_blob_name)
    return (blob_prop)

def setBlobAzure(azure_account_name, azure_account_key):
    block_blob_service = BlockBlobService(account_name=azure_account_name, account_key=azure_account_key)
    return block_blob_service

def removeAzureFile(azure_pull,func_container, func_blob_name):
    try:
        azure_pull.delete_blob(func_container, func_blob_name)
        if not(checkBlobExsists(azure_pull,func_container, func_blob_name)):
          log_data = "removeFile SUCCESS[deleted]: " +  func_blob_name + "succesfully removed the file from: " + func_container
          logMessage(log_data)
          return True
        else:
          logMessage(str("removeFile FAILURE[not deleted]: " +  func_blob_name + "failed to remove the file from: " + func_container))
          return False
    except azure.common.AzureMissingResourceHttpError:
        logMessage(str("removeFile FAILURE[not deleted]: " +  str(func_blob_name) + "failed to remove the file from: " + str(func_container) +" As it does not exist"))
    except:
        logMessage(str("removeFile FAILURE[not deleted]: " +  str(func_blob_name) + "failed to remove the file from: " + str(func_container) + "due to some unknown random azure error"))

def main(argv):
    configuration_file = "settings.conf" #sets our config file
    config = getConfigFile(configuration_file) #gets our config file

    mode = config['options']['mode'] #
    if mode != "azure" and mode != "local" and mode != "both":
        handleExit("main ERROR: No mode set",'2','0','0')

    if mode == "local" or mode == "both":
        for folder in config['local']['folder']:
            if(check_folder_exists(folder['name'])):
                handleLocalFiles(folder['name'],folder['retention'],config['options']['run'])
            else:
                handleExit(str("main Error: "+str(folder['name'])+" does not exist"),'2','0','0')
    if mode == "azure" or mode == "both":
        for azureAccounts in config['azure']['storage_accounts']: #loops through all the storage accounts
            azure_pull = setBlobAzure(azureAccounts['name'],azureAccounts['key']) #creates us an object which to do stuff
            for azureContainer in azureAccounts['containers']: # loops through all the containers under our storage account
                current_azure_files = listAzureFiles(azure_pull,azureContainer['container_name']) # lists all the files in that storage account and returns a list of files with a list of attributes for that file (should be a dictionary tbh)
                for item in current_azure_files: # goes through each file
                    if item[3] > azureContainer['retention'] and run == "live": # checks if our files age of last modification is greater than our retention age in seconds
                        removeAzureFile(azure_pull,azureContainer['container_name'],item[0]) # deletes the file
                    elif item[3] > azureContainer['retention'] and run == "test":
                        logMessage(str("main INFO[not deleted]: Mode: " + run + " File: " + item[0] + "" + str(azu) + ""))

    logMessage("main SUCCESS: We have finished the script")
    sys.exit(0)

if __name__ == "__main__":
   main(sys.argv[1:])
