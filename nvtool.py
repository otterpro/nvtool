import os.path
import shutil
from glob import iglob

import time
from watchdog.observers import Observer  
from watchdog.events import PatternMatchingEventHandler

import re
import sys
import urllib


# setup, done once when app launches
NV_PATH=os.path.expanduser("~/Dropbox/_notes/")
PELICAN_CONTENT_PATH= os.path.expanduser("~/project/blog.pelican/content/")
SERVER_IMAGE_ROOT_PATH="img"
PELICAN_IMAGE_PATH=os.path.join(PELICAN_CONTENT_PATH,SERVER_IMAGE_ROOT_PATH)

print "PELICAN_IMAGE_PATH="+PELICAN_IMAGE_PATH

NV_FILE_EXTENSION="*.txt"

#If the filename either starts or ends with certain word,
#it will grab it as a blog entry.
BLOG_PREFIX=""
BLOG_POSTFIX="(blog)"
# correct BLOG_PREFIX, to make it lower case and to add " " as separator
BLOG_PREFIX =BLOG_PREFIX.lower().strip()
# +" "
BLOG_POSTFIX = BLOG_POSTFIX.lower().strip()

#TODO: Use Logging instead
DEBUG=True
def dprint(message ):
    if DEBUG: print message

def files_have_same_timestamp(file1,file2):
    """useful for determining if file needs to be copied/examined"""
    # If more than 1 second difference
    if os.stat(file1).st_mtime - os.stat(file2).st_mtime > 1:
        return false
        # shutil.copy2 (src, dst)
    return true

def get_content_blog_filename(original_blog_fullpath):
    # make sure only file that are marked as blog are retrieved. 
    # return False if it is not a blog entry
    # example: must start with "(blog)" or it will be rejected 

    (original_path,original_filename)=os.path.split(original_blog_fullpath)
    if BLOG_PREFIX and not original_filename.lower().startswith(BLOG_PREFIX):
        return (False,False)
    elif BLOG_POSTFIX:
        (original_filename_without_ext,ext)=os.path.splitext(original_filename)
        if not original_filename_without_ext.lower().strip().endswith(BLOG_POSTFIX):
            print "Not valid blog file"
            return (False,False)
    else:   # CRITICAL ERROR. Neither has been assigned.
        dprint ("CRITICAL ERROR: BLOG_POSTFIX or BLOG_PREFIX not defined")
        return (False,False)


    (destination_filename,extension)=os.path.splitext(original_filename)
    destination_filename = destination_filename.strip() #remove extra space

    # ?????
    # make destination path
    #(unused,destination_filename)=os.path.split(filename_with_md)

    #strip prefix/postfix here from filename, (remove "blog " prefix)
    #   ie "(blog) Hello World.md" -> "Hello World.md"
    if (BLOG_PREFIX):
        destination_filename = destination_filename[len(BLOG_PREFIX):]
    else:
        destination_filename = destination_filename[:-len(BLOG_POSTFIX)]
    destination_filename = destination_filename.strip() #remove extra space
   
    # add ".md" extension
    destination_filename+=".md"

   # add full path
    #   ie "/home/blog/Hello World.md"
    destination_fullpath= os.path.join(PELICAN_CONTENT_PATH,destination_filename)
    return (destination_fullpath, destination_filename)


def copy_txt_to_content(source_filename):
    """
    Copy NV notes/*.txt into pelican/content/*.md
    also copy images if needed

    """ 
    (destination_fullpath,destination_filename)=get_content_blog_filename(source_filename)
    
    print "destination_fullpath"+destination_fullpath
    print "destination_filename"+destination_filename
    if not destination_filename: return
    """
    # add ".md" extension
    (filename_with_md,extension)=os.path.splitext(source_filename)
    filename_with_md+=".md"

    # make destination path
    (old_path,destination_filename)=os.path.split(filename_with_md)
    #strip prefix here from filename, (remove "blog " prefix)
    #   ie "blog Hello World.md" -> "Hello World.md"
    destination_filename = destination_filename[len(BLOG_PREFIX):]
    # add full path
    #   ie "/home/blog/Hello World.md"
    destination_fullpath= os.path.join(PELICAN_CONTENT_PATH,destination_filename)
    #copy
    #print ("copy from %s to %s" %(source_filename, destination_fullpath))
    #shutil.copy2(source_filename,destination_fullpath)
    #instead of copy, use write (see below)
    """
    
    # copy the file line-by-line, and make changes as needed
    input_file = open(source_filename)
    output_file = open(destination_fullpath,"w")

    # TODO:make these as a Pelican plugin

    # write Title and other metadata if needed
    first_line=input_file.readline()
    if first_line.lower().startswith("title:"):
        #already has a title. just skip
        input_file.seek(0)  #don't forget to move position to 0
    else:   # Title metatag is not there. Add it here.
        (blog_title,unused)=os.path.splitext(destination_filename)
        output_file.write("Title: "+blog_title+"\n")
    
    # check for image and copy as needed, and also alter img source
    image_search=r"file:\/\/(?P<origpath>[-\/\w\.\(\)%]+\.(jpg|png|jpeg))"
    internal_link_search=r"(\[\[)(?P<blogtitle>[^\]]+)(\]\])"
    #TODO: handle other case where NV can't handle capitalized extension
    #       ie JPG, PNG (vs jpg, png)
    #       in which it creates <file> instead of MD image 
    for line in input_file:
        # handle images 
        m = re.search(image_search,line,re.I)
        if m:
            original_image_path = m.group("origpath")
            print "match,external file ="+original_image_path
            #
            # copy image
            (old_path,destination_image_filename)=os.path.split(original_image_path)
            # convert URI to os.path ("file%20.txt" to "file .txt") 
            destination_image_path=os.path.join(PELICAN_IMAGE_PATH,
                    destination_image_filename)
            print "copy to " + destination_image_path
            original_image_path=urllib.unquote(original_image_path)
            destination_image_path=urllib.unquote(destination_image_path)
            #TODO: use rsync type copy instead of copy2
            #   to avoid unneeded image copy
            shutil.copy2(original_image_path,destination_image_path)

            # not sure if i need to add "/", but it should work.
            repl_string=os.path.join("/"+SERVER_IMAGE_ROOT_PATH,destination_image_filename)

            print "old line="+line
            # replace text with new path
            line=re.sub(image_search,repl_string,line)
            print "new line="+line
        
        # handle internal links
        m = re.search(internal_link_search,line,re.I)
        if m:
            # TODO: choice on link_text. By default, uses the blog title.
            link_title= m.group("blogtitle")
            # strip away "blog " prefix
            if BLOG_PREFIX: link_title=link_title[len(BLOG_PREFIX):].strip()
            else: link_title=link_title[len(BLOG_PREFIX):].strip() 
            link_url=urllib.quote(link_title.replace(' ','-').lower())+".html"
            repl_string="["+link_title+"]("+link_url+")"
            line=re.sub(internal_link_search,repl_string,line)
            #TODO: check for bad links and linked pages that didn't get generated 
        output_file.write(line)

    input_file.close()
    output_file.close()

def delete_blog(blog_fullpath):
    (destination_fullpath,destination_filename)=get_content_blog_filename(blog_fullpath)
    if not destination_filename: return
    os.remove(destination_fullpath)

class WatchdogHandler(PatternMatchingEventHandler):
    patterns=[NV_FILE_EXTENSION]
    #patterns=["*.txt"]

    #patterns=["blog *.txt","*.rtf","*.html"]
    # note: this could be ".rtf" or "html", but decided to leave it as txt

    def process(self,event):
        print "watchdog: "+ event.src_path, event.event_type

        #copy to pelican path if it qualifies
        copy_txt_to_content(event.src_path)

    def on_modified(self,event):
        self.process(event)
    def on_created(self,event):
        self.process(event)
    def on_deleted(self,event):
        delete_blog(event.src_path)  

observer = Observer()
observer.schedule(WatchdogHandler(), NV_PATH)
observer.start()

try:
    while True:
        time.sleep(1)
except KeyboardInterrupt:
    observer.stop()

observer.join()

def old_copy():
    destination_path = PELICAN_CONTENT_PATH
    search_path = os.path.join(NV_PATH,"blog *.txt")

    files=iglob(search_path)
    for source_filename in files:

        copy_to_content(source_filename)
        # switch from ".txt" to ".md"
        (filename_with_md,extension)=os.path.splitext(source_filename)
        filename_with_md+=".md"

        # destination path 
        (old_path,destination_filename)=os.path.split(filename_with_md)
        destination_filename = os.path.join(destination_path,destination_filename)

        print ("copy from %s to %s" %(source_filename, destination_filename))
        shutil.copy2(source_filename,destination_filename)

        #
        # TODO: search for images and copy to 
        #
        destination_path = PELICAN_IMAGE_PATH
        #search_path = os.path.join(PELICAN_CONTENT_PATH,"*.md")

        """ # grep for image 
        # Replace source with dest path
        # Change image files if file doesn't exist or is not correct
        
        destination_filename = os.path.join(destination_path,destination_filename)

        print ("copy from %s to %s" %(source_filename, destination_filename))
        shutil.copy2(source_filename,destination_filename)
        """
