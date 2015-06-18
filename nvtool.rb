#!/usr/bin/env ruby
# nvtool.rb (ruby 1.9+)
# version: 0.1
# Daniel Kim (http://www.otter.pro)
#
# Goes through all the text files, searching for blog submission
# and then processes them before handing them over to jekyll
#
# External file: config.yml 
#
# Issues:
#   It works if permalink is set to /:title
#   Also, individual permalink cannot be used, since it affects
#   the internal link system. Rather, it removes permalink field in each post.
#   Therefore, it is best to rename the title instead.
#   
#   Cannot have same multiple URL on same line of text, 
#     results in extra "< >" brackets
#
#   Don't use permalink field on each post, or it will break the [[link]]
#   MAYBE: parse each file in 2 phase system where slugs are stored in DB
#     and use that to point to the right link

# require 'yaml'
require 'yaml/store'
require 'optparse'

CONFIG_FILENAME="config.yml"
DEFAULT_CONFIG_PATH="~/project/nvtool/"

# Default setting values
# TODO: possibly put these in the config.yml
BLOG_TAG="#blog"  # publish any text with presence of "#blog" in filename 
# TODO: Read these from Jekyll's config.yml if possible
JEKYLL_POST_DIR="_posts"
JEKYLL_PAGE_DIR="_pages"

# GLOBAL VAR
$config= {}
$jekyll_path=""
$post_path=""
$page_path=""

def d(text)
  if $config[:debug] 
    puts text
  end
end

def url_is_image?(url)
  url.downcase.end_with?(*%w(.jpg .png .jpeg .gif))
end

# given an URL, it retrieves last part of URL
# Else, returns whole string.
#
# "http://example.com/some/where/from/here.html" ==> "here.html"
def get_url_end_path(url)
  title=url
  
  if match=url.match(/^https?\:\/\/[\S]+\/([\S]+)\s*/i)
    title=match[1] # extract the last part of URL
  end
  title=title[1..-1] if title[0]=='/' # remove leading "/"
  title
end

# convert slug into readable title
# "my-first-post@blog" ==> "my first post"
def deslugify(title)
  title = get_url_end_path(title)
  # strip "#blog", and 
  # title.strip.gsub(/[\-_]/, ' ').gsub(/\#.*/,'').gsub(BLOG_TAG,"")
  title.strip.gsub(/[\-_]/, ' ').gsub(BLOG_TAG,"")
end

# given an url to an image file, convert URL to markdown image
# convert "http://example.com/pic_some.jpg" into "![pic some](http://....)"
def make_image_from_url(url)
  # title=url.match(/^https?\:\/\/[\S]+\/([\S]+\.[\w]+)\s*/i)
  # new_link="![#{title[1]}](#{url})"
  title=get_url_end_path(url)
  new_link="![#{title}](#{url})"

end

# given an url to flickr, convert to flickr liquid tag
# converts "https://www.flickr.com/photos/something/1234567/..." to 
# "{% flickr_photo 1234567 %}"
# It is careful to extract only the 3rd element of the path
def make_flickr_url(url)
  match = url.match(/^https?\:\/\/www\.flickr\.com\/[\w]+\/[\w]+\/([\d]+)/i)
  "{% flickr_photo #{match[1]} %}"
end

#TODO
def make_youtube_url(url)
  url
end

# 
# Convert bracket links [[ ]] to markdown links
#
# internal link: [[about]] ==> [about](/about)
# internal image : [[my_photo.jpg]] ==> ![my_photo](/my_photo.jpg)
# external link : [[http://google.com]] => [google.com](http://google.com)
# external image : [[http://example.com/abc.jpg]] ==> ![http://...](http://...)
def convert_link(link)
  link||=""  # remove nil
  link.strip!
  url=''
  if !link.empty?  # if not empty string
    title=link
    url=link.downcase
    if url.start_with?("http") || url.start_with?("www")
    # if HTTP/HTTPS/ external link, leave it alone unless it is a pic
      
    else  # normal internal link ie [[about]]
      # Fix URL
      url="/"+url if url[0]!='/'  #always prepend "/" to internal links
      # remove "@blog", replace space with "-"
      url = url.gsub(BLOG_TAG,"").gsub(" ","-").strip

      title=deslugify(title)
        
    end
    link="[#{title}](#{url})"   # form a markdown link

    # image file
    link="!"+link if url_is_image?(url)

    # debug "link #{link}"
    
  end
  link
end

# 
# Process each line of text here
#
def convert_line(line)
  # Handle [[internal-link]]
  if matches= line.scan(/\[\[(.*?)\]\]/)
    matches.each do |match|
      link = convert_link(match[0])
      line.gsub!(/\[\[#{match[0]}\]\]/,link)
    end
  end
  # MAYBE: Handle Markdown link [Hello world](/hello-world) 
  # if match = line.match(......)
  # link = do_something(match.captures[0])
  #   line.gsub!(.....link)
  # end

  # Handle naked URL, on its own line.
  # However, it does not handle URL that is inside the text, due to 
  # not having enough time to do it.

  #
  # ie GFM URL https://google.com ==> <https://google.com> if needed
  if link  = line[/^(https?\:\/\/[\S]+)/i]

    # link to image means it's an image => ![pic](pic-url)
    if url_is_image?(link)
      new_link=make_image_from_url(link)
    elsif link.include?("www.flickr.com")
      new_link = make_flickr_url(link)
    elsif link.include?("youtube.com")
      new_link = make_youtube_url(link)
    else
      # naked URL: "https://www.google.com" => <www.google.com>
      new_link="<#{link}>"
    end
    line.sub!(link,new_link) # replace 1st occurrence only
  end
  line
end

#
#
def convert_file(input_filename, output_filename)
  input=File.open(input_filename,"r") 
  output=File.new(output_filename,"w")
    while !input.eof?
      line=input.readline
      # puts "convert_line #{line}"
      output.write convert_line(line)
    end
  input.close
  output.close
  
end

# posts :
# rename "/txt/blog_post.txt" ==> "/jekyll/_posts/2015-06-01-blog-post.md"
# pages :
# rename "/foo/bar/BLOG 123.TXT" ==> "/jekyll/_pages/blog-123.txt"
#
def make_jekyll_filename(input_file)
  # find dates 
  # dates: use yaml front-matter, if it exists
  date=nil
  slug=nil
  layout=nil
  page_or_post_path=JEKYLL_POST_DIR  #by default, goes to "_posts"
    filename_prefix=""

    d "input file=#{input_file}"
  begin
    front_matter= YAML.load_file(input_file)
  rescue
    # no front-matter found in input_file
    d "no front-matter"
  end
    date = front_matter["date"]
    # slug= front_matter["permalink"]  #currently, this is ignored.
    # title= front_matter["title"]  
    layout = front_matter["layout"]  #used to determine if page or post

  if !date
    # dates: use file creation date as last resort
    date=File.mtime(input_file)
  end
    date = date.strftime("%Y-%m-%d").to_s
  # if slug
    # ignore all slug/permalink and also mark the slug as invalid
  # else

  
  # if !slug
  #   slug=File.basename(input_file,".*").downcase.gsub(BLOG_TAG,"").strip
  #   slug.gsub!(" ","-")  #replace filename's space with dash to match URL
  # end
  title=File.basename(input_file,".*").downcase.gsub(BLOG_TAG,"").strip
  title.gsub!(" ","-")  #replace filename's space with dash to match URL
  if layout
    puts "layout: #{layout}"
  end

  # PAGE
  if layout && layout.downcase == "page"  # this txt is page, not post
    page_or_post_path=JEKYLL_PAGE_DIR  

  # POST
  else
    filename_prefix="#{date}-"
  end
  File.join($jekyll_path,page_or_post_path,"#{filename_prefix}#{title}.md")
end

#
# read configuration data.
# As of now, config file is in ~/project/nvtool/config.yml.  
# In the future, change it to ~/.nvtool.yml
#
def read_config

  config_file=File.join(File.expand_path(DEFAULT_CONFIG_PATH),CONFIG_FILENAME)
  store=YAML::Store.new config_file
  store.transaction do 
    $config[:notes_path] = store["notes_path"]
    $config[:jekyll_path] = store["jekyll_path"]
  end
end

# 
#
def convert_texts_to_jekyll

  # db_file=File.join(File.expand_path(DEFAULT_CONFIG_PATH),DB_FILENAME)
  # store=YAML::Store.new db_file
  
  convert_count=0
  notes_path = File.expand_path($config[:notes_path])  
  $jekyll_path= File.expand_path($config[:jekyll_path])
  $post_path=File.join($jekyll_path,JEKYLL_POST_DIR )
  $page_path=File.join($jekyll_path,JEKYLL_PAGE_DIR )

  Dir[File.join(notes_path,"*"+BLOG_TAG+"*.txt")].each do |input_file|
    output_file = make_jekyll_filename(input_file) 

    if !$config[:force] 
      if File.exists?(output_file)
        input_date = File.mtime(input_file)
        output_date = File.mtime(output_file)
        next if input_date <= output_date
      end
    end
    d "processing #{input_file} to #{output_file}"
    convert_file(input_file,output_file)
    convert_count+=1
  end

  puts "Converted #{convert_count} files."

end

# Only here for future version if we add other options
def read_commandline_option
  # ARGV << '-h' if ARGV.empty?
  OptionParser.new do |opts|
    opts.banner = "Usage: nvtool.rb [options] <command>"

    opts.on("-f", "--force", "Run on all text file") do |v|
      $config[:force] = true
    end

    opts.on("-d", "--debug", "Show all debugging message") do |v|
      $config[:debug] = true
    end

    opts.on_tail("-h", "--help", "Show this message") do
      puts opts
      exit
    end

  end.parse!
end

if __FILE__ == $0   
  d "ruby version #{RUBY_VERSION}"
  read_config
  read_commandline_option
  convert_texts_to_jekyll
end
