#this was written about 5 months ago in my spare time, used this as a basis for a range of other scripts
#that are running in prod. The full error handling has not been done though in this script as it was OneDrive
#of my early ones
#!/bin/python

from azure.storage.blob import BlockBlobService, PageBlobService, AppendBlobService, BlockListType, ContentSettings
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

#Random Date and number variables
today = str(datetime.date.today()) #This is used for offset calculations throughout the script
file_delay = 600

#Configure logging parameters for logging
log_location = ""
logging.basicConfig(format='%(asctime)s %(name)-20s %(levelname)-5s %(message)s', level=logging.DEBUG, filename=log_location)
logger = logging.getLogger(__name__)

#Mode allows you to either select azure to upload your files or copy to another location
mode = "azure" # this can either be azure or local
compare_method = "md5" #md5 or filecmp are acceptable, noting md5 has a performance hit

#define global azure Variables
azure_account_name = "" #storage account name in azure ###FILL ME IN###
azure_account_key = "" #Never upload this key anywhere!!!  ###FILL ME IN###
azure_container = "" # blob container name inside your storage account  ###FILL ME IN###
block_blob_service = BlockBlobService(account_name=azure_account_name, account_key=azure_account_key) #Generates the service we will use

#define local end point
local_location = "" #you need a / at the end of this!  ###FILL ME IN###
local_destination = "" #you need a / at the end of this!  ###FILL ME IN if you arent using azure###
file_errors = 0

#file variables
#this can be run on unix or windows but we need to set the correct deliminator for substituing later
if platform.system() == "Windows":
    delim = "\\" #windows
else:
    delim = "/" #unix based systems

# gets md5 hash of a file - some performance impact, to compare two files you would have to call this once for the two files you want
# to compare. This reads fille 4096 bytes at a time and is not currently implemented yet
def md5FileCheck(func_filename):
    hash_md5 = hashlib.md5()
    with open(func_filename, "rb") as f:
        for chunk in iter(lambda: f.read(4096), b""):
            hash_md5.update(chunk)
    return hash_md5.hexdigest()

#checks the directory for free space in bytes so we can determine if we have enough room to copy a
#source file to destination directory when utilizing mode = 'local'
def get_free_space_bytes(dirname):
    if platform.system() == 'Windows':
        free_bytes = ctypes.c_ulonglong(0)
        ctypes.windll.kernel32.GetDiskFreeSpaceExW(ctypes.c_wchar_p(dirname), None, None, ctypes.pointer(free_bytes))
        return free_bytes.value
    else:
        st = os.statvfs(dirname)
        return st.f_bavail * st.f_frsize

# std check using filecmp to see if these files match, this is quicker that md5 hash
def cmpFileCheck(func_source_file,func_destination_file):
    return filecmp.cmp(func_source_file, func_destination_file)

#Query and check if the blob exsists in the cloud, returns True or False in exsists
def checkBlobExsists(func_container, func_blob_name):
    exists = block_blob_service.exists(func_container, func_blob_name)
    return exists

#Function used to uplaod a file, pass the container in azure, the name of the blob your creaeting and what the blob will contain
def uploadFile(func_container, func_blob_name, func_source, func_metadata):
  global file_errors
  before_upload = datetime.datetime.now()
  block_blob_service.create_blob_from_path(
      func_container,
      func_blob_name,
      func_source,
      metadata=func_metadata
          )
  after_upload = datetime.datetime.now()
  upload_time = after_upload - before_upload
  if (checkBlobExsists(func_container, func_blob_name)):
      log_data = "uploadFile SUCCESS: " + func_blob_name + ' uploaded to ' + func_container + ' from ' + func_source + str(func_metadata) + " this took " + str(upload_time)
      logger.info(log_data)
      return True
  else:
      log_data = "uploadFile FAILURE: " + func_blob_name + ' uploaded to ' + func_container + ' from ' + func_source  + str(func_metadata) + " this took " + str(upload_time)
      file_errors += 1
      logger.info(log_data)
      return False

#lists all the files in a local directory. It uses file_delay to ensure we dont get anywhere
#files that may have recently been touched. Useful if you have things that may write out
#every 10 mintutes, you simply set this to be 21 minutes and you should not catch open files
def listLocalFiles(dir):
    only_files = []
    for root, dirs, files in os.walk(dir):
        for name in files:
            st=os.stat(os.path.join(root, name))
            age=(time.time()-st.st_mtime)
            if age >= file_delay:
                only_files.append(os.path.join(root, name))
            else:
                logMessage("File:"+name+" has been modified: "+str(age)+" seconds ago which is less than: "+str(file_delay)+" we will not touch this file until after its been modified")
    return only_files

#Logs a message to file
def logMessage(func_message):
    log_data = func_message
    logger.info(log_data)

#simple gets file size in bytes
def get_file_size(file):
    os.path.getsize(file)

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

def safeCopyFile(func_source_file,func_destination_file):
    global file_errors
    try:
        logger.info(str("safeCopyFile INFO: Attempting to copy files, source: "+func_source_file+", destination: " +func_destination_file))
        local_destination_relative = func_destination_file.replace(func_destination_file.split(delim)[-1],'')
        if not (check_folder_exsists(local_destination_relative)):
            mkdir_p(local_destination_relative)
        if get_file_size(func_source_file) < get_free_space_bytes(local_destination_relative):
            shutil.copy2(func_source_file,func_destination_file)
            if compare_method == "filecmp" and cmpFileCheck(func_source_file,func_destination_file):
                logger.info(str("safeCopyFile INFO: filecmp advises Files ARE THE SAME marking for deletion, source: "+func_source_file+", destination: " +func_destination_file))
                removeLocalFile(func_source_file)
            elif compare_method == "md5" and md5FileCheck(func_source_file) == md5FileCheck(func_destination_file):
                logger.info(str("safeCopyFile INFO: md5 advises Files ARE THE SAME marking for deletion, source: "+func_source_file+", destination: " +func_destination_file))
                removeLocalFile(func_source_file)
            else:
                logger.info(str("safeCopyFile ERROR: Files are not the same for some reason but no error happened, source: "+func_source_file+", destination: " +func_destination_file))
                file_errors += 1
        else:
            logger.info(str("safeCopyFile ERROR: There is not enough space to copy source: "+func_source_file+", to destination: " +local_destination_relative))
            file_errors += 1
    except IOError as e:
        logger.info(str("safeCopyFile ERROR: I/O error({0}): {1}".format(e.errno, e.strerror)+", source: "+func_source_file+", destination: " +func_destination_file))
        file_errors += 1
    except:
        logger.info(str("safeCopyFile ERROR: "+sys.exc_info()[0]+", source: "+func_source_file+", destination: " +func_destination_file))
        file_errors += 1

#gets the blob details such as
def blobProperties(func_container, func_blob_name):
    blob_prop = block_blob_service.get_blob_properties(func_container, func_blob_name)
    return (blob_prop)

#handles getting creation date for windows and unix systems
def creation_date(path_to_file):
    if platform.system() == 'Windows':
        return datetime.date.fromtimestamp(os.path.getctime(path_to_file))
    else:
        stat = os.stat(path_to_file)
        try:
            return datetime.date.fromtimestamp(stat.st_birthtime)
        except AttributeError:
            return datetime.date.fromtimestamp(stat.st_mtime)

#check if a folder exsists
def check_folder_exsists(path):
    if (os.path.isdir(path)):
        return True
    return False

#makes a directory structure even if it doesnt exsist similar to mkdir -p functionality
def mkdir_p(path):
    try:
        os.makedirs(path)
    except OSError as exc:  # Python >2.5
        if exc.errno == errno.EEXIST and os.path.isdir(path):
            pass
        else:
            raise

def check_initial_requirements():
    if mode != "azure" or mode != "local":
        logger.info(str("validation ERROR: "+mode+" does not equal azure or local"))
        return False
    if compare_method != "md5" or compare_method != "filecmp":
        logger.info(str("validation ERROR: "+file_method+" does not equal filecmp or md5"))
        return False
    if not (check_folder_exsists(local_location)):
        logger.info(str("validation ERROR: "+local_location+" does not exsist"))
        return False
    if not (check_folder_exsists(log_location)):
        logger.info(str("validation ERROR: "+log_location+" does not exsist"))
        return False
    if mode == "local" and not (check_folder_exsists(local_destination)):
        logger.info(str("validation ERROR: "+local_destination+" does not exsist"))
        return False
    for writeCheck in local_destination,log_location,local_location:
        if not os.access(writeCheck, os.W_OK):
            logger.info(str("validation ERROR: "+writeCheck+" does not have read/write permissions"))
            return False
    return True

def main(self):
    logger.info(str("main INFO: Main script is starting"))
    local_files = listLocalFiles(local_location)
    if (check_initial_requirements):
        for file in local_files:
            file_name = file.split(delim)[-1]
            file_size = get_file_size(file)
            file_created = str(creation_date(file))
            relative_filename = file.replace(local_location, '')
            relative_filename = relative_filename.replace('\\', '/')
            if mode == 'azure':
                file_hash = md5FileCheck(file)
                file_metadata = { 'name': file_name, 'size': str(file_size), 'created': file_created, 'hash': file_hash, 'path': file, 'path_relative': relative_filename}
                if (uploadFile(azure_container, relative_filename, file, file_metadata)):
                    removeLocalFile(file)
            elif mode == 'local':
                local_destination_file = file.replace(local_location,local_destination)
                safeCopyFile(file,local_destination_file)
    else:
        logger.info(str("main ERROR: initial requirements check failed - exiting immediatley"))
        sys.exit(2)

    logger.info(str("main INFO: Main script is finishing"))
    if file_errors > '1':
        sys.exit(2)
    sys.exit(0)

if __name__ == "__main__":
   main(sys.argv[1:])
