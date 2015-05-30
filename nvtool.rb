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
BLOG_TAG="@blog"  # publish any text with presence of "@blog" in filename 
# DB_FILENAME="db.yml"
# LOG_FILENAME="nvtool.log"  # not implemented yet

$config= {}

def debug(text)
  puts text
end

def url_is_image?(url)
  url.downcase.end_with?(*%w(.jpg .png .jpeg .gif))
end

def deslugify(title)
  title=title[1..-1] if title[0]=='/' # remove leading "/" on title, though
  #strip "#..", "@blog".
  title.strip.gsub(/[\-_]/, ' ').gsub(/\#.*/,'').gsub(BLOG_TAG,"")
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
  
  # Handle GFM URL https://google.com ==> <https://google.com> if needed
  # and images into ![]()
  # if matches = line.scan(/([\[<]*)[\s]*(https?\:\/\/[^\s\]>\)]+)/)
  if matches = line.scan(/\s*([(<\[{]*)[\s]*(https?\:\/\/[^\s\]>\)}]+)/)
    matches.each do |match|

      possible_prefix=match[0] || '' # grabs any [,[[,<,(

      link=match[1]
      
      # if it starts with < or [, then ignore it..
      if possible_prefix.start_with?(*%w([ <  { ! \( ))
        # no action is required for those already inside brackets
      else  
      
        # link to image means it's an image => ![pic](pic-url)
        if url_is_image?(link)
          new_link="![#{link}](#{link})"
        else
        # link to normal external url "www.google.com" => <www.google.com>
          new_link="<#{link}>"
        end
        line.gsub!(link,new_link) #TODO: bug with same multiple URL in 1 line
      end
    end
  end
  
  line
end

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

# 
# rename "/txt/blog_post.txt" ==> "/jekyll/_posts/2015-06-01-blog-post.md"
# * "BLOG 123.TXT" ==> "blog-123.txt"
#
def get_jekyll_filename(input_file)
  # find dates 
  # dates: use yaml front-matter, if it exists
  date=nil
  slug=nil
  begin
    front_matter= YAML.load_file(input_file)
    date = front_matter["date"].strftime("%Y-%m-%d").to_s
    slug= front_matter["permalink"]  #currently, this is ignored.

  rescue
    # no front-matter found in input_file
  end
  if !date# dates: use file creation date as last resort
    date=File.birthtime(input_file).strftime("%Y-%m-%d").to_s
  end
  # if slug
    # ignore all slug/permalink and also mark the slug as invalid
  # else
  if !slug
    slug=File.basename(input_file,".*").downcase.gsub(BLOG_TAG,"").strip
    slug.gsub!(" ","-")  #replace space with dash
  end

  File.join($config[:jekyll_path],"#{date}-#{slug}.md")

end

def read_config

  config_file=File.join(File.expand_path(DEFAULT_CONFIG_PATH),CONFIG_FILENAME)
  store=YAML::Store.new config_file
  store.transaction do 
    $config[:notes_path] = store["notes_path"]
    $config[:jekyll_path] = store["jekyll_path"]
  end
end

def convert_texts_to_jekyll

  # db_file=File.join(File.expand_path(DEFAULT_CONFIG_PATH),DB_FILENAME)
  # store=YAML::Store.new db_file
  # store.transaction do 
  #   $config[:notes_path] = store["notes_path"]
  #   $config[:jekyll_path] = store["jekyll_path"]
  # end
  
  convert_count=0

  Dir[File.join($config[:notes_path],"*"+BLOG_TAG+"*.txt")].each do |input_file|
    output_file = get_jekyll_filename(input_file)  

    if !$config[:force] 
      if File.exists?(output_file)
        input_date = File.mtime(input_file)
        output_date = File.mtime(output_file)
        next if input_date <= output_date
      end
    end
    debug "processing #{input_file} to #{output_file}"
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

    opts.on_tail("-h", "--help", "Show this message") do
      puts opts
      exit
    end

  end.parse!
end

if __FILE__ == $0   
  read_config
  read_commandline_option
  convert_texts_to_jekyll
end
