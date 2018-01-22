#!/bin/python
#you need to ensure you have installed the azure, yaml, pytz with pip
from azure.storage.blob import BlockBlobService, PageBlobService, AppendBlobService, BlockListType, ContentSettings
import azure
import string
import os
import datetime
import logging
import platform
import shutil
import random
import time
import hashlib
import filecmp
import sys
import shutil
import re
import yaml
import pytz

#Configure logging parameters for logging
today = str(datetime.date.today())
log_location = "/yourpathhere/"+today+".log" #FILL ME IN
logging.basicConfig(format='%(asctime)s %(name)-20s %(levelname)-5s %(message)s', level=logging.INFO, filename=log_location)
logger = logging.getLogger(__name__)

def handleExit(message,code,method,email):
    logMessage("handleExit FATAL: "+message)
    sys.exit(code)

def handleLocalFiles(dir,file_delay):
    for root, dirs, files in os.walk(dir):
        for name in files:
            st=os.stat(os.path.join(root, name))
            age=(time.time()-st.st_mtime)
            if age >= file_delay:
                removeLocalFile(str(os.path.join(root, name)))
            else:
                logMessage("handleLocalFiles INFO: File:"+str(os.path.join(root, name))+" has been modified: "+str(age)+" seconds ago which is less than: "+str(file_delay)+" we will not touch this file until after its been modified")

#Removes a file from the OS or raises the appropriate error
def removeLocalFile(func_source_file):
    global file_errors
    try:
        os.remove(func_source_file)
        logger.info(str("removeLocalFile INFO: Removed the following file: "+func_source_file))
    except OSError as e:
        if e.errno != errno.ENOENT:
            logger.info(str("removeLocalFile ERROR: FAILED to Remove the following file: "+func_source_file+ "with error: " + e.strerror))
            file_errors += 1
            raise

#Logs a message to file
def logMessage(func_message):
    log_data = func_message
    logger.info(log_data)

def fileExist(path):
    try:
        fi = open(path)
        fi.close()
    except OSError as e:
        handleExit("validation ERROR: File:"+path+" Code: "+str(e.errno)+" Message: "+str(e.strerror),'2','0','0')
    except IOError as e:
        handleExit("validation ERROR: File:"+path+" Code: "+str(e.errno)+" Message: "+str(e.strerror),'2','0','0')

def getConfigFile(config_loc):
    fileExist(config_loc)
    with open(config_loc, "r") as f:
        config = yaml.load(f)
    return config

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
    configuration_file = "settings.conf"
    config = getConfigFile(configuration_file)

    mode = config['options']['mode']
    if mode != "azure" and mode != "local" and mode != "both":
        handleExit("main ERROR: No mode set",'2','0','0')

    if mode == "local" or mode == "both":
        for folder in config['local']['folder']:
            if(check_folder_exists(folder)):
                handleLocalFiles(folder,config['options']['retention'])
            else:
                handleExit(str("main Error: "+folder+" does not exsist"),'2','0','0')
    if mode == "azure" or mode == "both":
        for azureAccounts in config['azure']['storage_accounts']:
            azure_pull = setBlobAzure(azureAccounts['name'],azureAccounts['key'])
            for azureContainer in azureAccounts['containers']:
                current_azure_files = listAzureFiles(azure_pull,azureContainer)
                for item in current_azure_files:
                    if item[3] > azureAccounts['retention']:
                        removeAzureFile(azure_pull,azureContainer,item[0])

if __name__ == "__main__":
   main(sys.argv[1:])
