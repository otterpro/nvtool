---
title: NVTool
#layout: page
additional_copy_path: ~/project/nvtool/README.md
tags: nvtool
category: project
---
Summary
========
NVTool is a tool I wrote to assist in publishing my text documents to Jekyll as
well as to other projects. Originally, I used Notational Velocity on Mac, as it
is the best text managing editor that I'd ever used.  However, since I was also
on Linux, I began using Vim along with slew of plugins to imitate Notational
Velocity as much as I could.

While I could just start writing text files inside the Jekyll's _posts
directory,  I don't like the file naming format for each blog posts, which need
to start with date. 
It will create blog posts without having to name the files to the Jekyll's naming
convention.  

For example, it will name the blog post called "My first day at work.txt" to
"2015-07-01-my-first-day-at-work.md"


NVTool grabs all text files with "#blog" in its filename for further processing.
For example, a file called "About Me #blog.txt" will be processed.

NVTool translates internal links used in the text, following the Notational Velocity. 
Internal links are created using square brackets such as "[Another Page](/another-page)".  
It is compatible with Notational Velocity, and looks somewhat similar to
Wikipedia's Interwiki link format.

Once the text file is translated, it is copied to its target directory, usually
in the Jekyll's `_posts/` or `_pages/` directory.  The text can also be copied to another
location, if desired.

Alternative
===========
There are other tools that handle some of the tasks that needed.

* [Jekyll Asse://github.com/matthodan/jekyll-asset-pipelinet Pipeline](https://github.com/matthodan/jekyll-asset-pipeline)
* Grunt
* Rakefile

However, these were limited when it came to parsing and translating the text
files.

Prerequisite
=======
* Jekyll
* `_pages/` directory in Jekyll. This directory needs to be created, since it is
    not in the original Jekyll's directory structure.

Usage
========
Run in command line.  Only the newly updated files will be processed.

    ruby nvtool.rb

-- force, -f processes all files, even if it is not necessary.

    ruby nvtool.rb -f


Configuration
========
config.yml contains the system-wide setting.

    notes_path: "~/_notes"
    jekyll_path: "~/www/jekyll-site"

* notes_path: path where original text files are located. On Notational
    Velocity, this is usually in the "~/Library/Application Support/Notational
    Data". Make sure that Notational Velocity is using "Plain Text Files", not
    its binary database format. I usually assign the directory to `_notes/`.
* jekyll_path: jekyll's path, and should include _posts, and _pages directories.

Front Matter
=====
Each document can have YAML front matter, as it is on Jekyll.

    layout: page

* It is used by Jekyll to determine the layout file.  With NVTool, by default, all entries are considered posts, unless the layout is set to
    page.  NVTool will send all post to _posts/ directory and all page to
    _pages/

    additional_copy_path: ~/project/abc/README.md

* If specified, the output file will also be copied to another location. It is
    useful for generating additional copy to be used for another projects or
    blogs.  I use this to generate README.md for several projects, including
    this one.


