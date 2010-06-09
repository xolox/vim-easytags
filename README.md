# Automated tag generation and syntax highlighting in Vim

[Vim] [vim] has long been my favorite text editor and combined with [Exuberant
Ctags] [exuberant_ctags] it has the potential to provide most of what I expect
from an [integrated development environment] [ide]. Exuberant Ctags is the
latest incarnation of a [family of computer programs] [ctags] that scan
source code files to create an index of identifiers (tags) and where they are
defined. Vim uses this index (a so-called tags file) to enable you to jump to
the definition of any identifier using the `Ctrl-]` mapping.

When you're familiar with integrated development environments you may recognize
this feature as "Go-to definition". One advantage of the combination of Vim and
Exuberant Ctags over integrated development environments is that Vim supports
syntax highlighting for [over 500 file types] [vim_support] (!) and Exuberant
Ctags can generate tags for [over 40 file types] [ctags_support] as well...

There's just one problem: You have to manually keep your tags files up-to-date
and this turns out to be a royal pain in the ass! So I set out to write a Vim
plug-in that would do this boring work for me. When I finished the plug-in's
basic functionality (one automatic command and a call to `system()`) I became
interested in dynamic syntax highlighting, so I added that as well to see if it
would work -- surprisingly well I'm happy to report!

## Install & first use

Unzip the most recent [ZIP archive] [latest_zip] file inside your Vim profile
directory (usually this is `~/.vim` on UNIX and `%USERPROFILE%\vimfiles` on
Windows), restart Vim and try it out: Edit any file type supported by Exuberant
Ctags and within ten seconds the plug-in should create/update your tags file
(`~/.vimtags` on UNIX, `~/_vimtags` on Windows) with the tags defined in the
file you just edited! This means that whatever file you're editing in Vim (as
long as its on the local file system), tags will always be available by the
time you need them!

Additionally if the file you just opened is a C, Lua, PHP, Python or Vim source
file you should also notice that the function and type names defined in the
file have been syntax highlighted.

If the plug-in warns you that `ctags` isn't installed you can download it from
its [homepage] [exuberant_ctags], or if you're running Debian/Ubuntu you can
install it by executing the following shell command:

    sudo apt-get install exuberant-ctags

## Configuration

The plug-in is intended to work without configuration but can be customized by
changing the following options:

### The `easytags_file` option

As mentioned above the plug-in will store your tags in `~/.vimtags` on UNIX and
`~/_vimtags` on Windows. To change the location of this file, set the global
variable `easytags_file`, e.g.:

    :let g:easytags_file = '~/.vim/tags'

A leading `~` in the `easytags_file` variable is expanded to your current home
directory (`$HOME` on UNIX, `%USERPROFILE%` on Windows).

### The `easytags_always_enabled` option

By default the plug-in automatically generates and highlights tags when you
stop typing for a few seconds. This means that when you edit a file, the
dynamic highlighting won't appear until you pause for a moment. If you don't
want this you can configure the plug-in to always enable dynamic highlighting:

    :let g:easytags_always_enabled = 1

Be warned that after setting this option you'll probably notice why it's
disabled by default: Every time you edit a file in Vim, the plug-in will first
run Exuberant Ctags and then highlight the tags, which slows Vim down quite a
lot. I have some ideas on how to improve this latency by executing Exuberant
Ctags in the background, so stay tuned!

Note: If you change this option it won't apply until you restart Vim, so you'll
have to set this option in your `~/.vimrc` script (`~/_vimrc` on Windows).

### The `easytags_on_cursorhold` option

As I explained above the plug-in by default doesn't update or highlight your
tags until you stop typing for a moment. The plug-in tries hard to do the least
amount of work possible in this break but it might still interrupt your
workflow. If it does you can disable the periodic update:

    :let g:easytags_on_cursorhold = 0
    
Note: Like the `easytags_always_enabled` option, if you change this option it
won't apply until you restart Vim, so you'll have to set this option in your
`~/.vimrc` script (`~/_vimrc` on Windows).

### The `easytags_resolve_links` option

UNIX has [symbolic links] [symlinks] and [hard links] [hardlinks], both of
which conflict with the concept of having one unique location for every
identifier. With regards to hard links there's not much anyone can do, but
because I use symbolic links quite a lot I've added this option. It's disabled
by default since it has a small performance impact and might not do what
unknowing users expect it to: When you enable this option the plug-in will
resolve symbolic links in pathnames, which means your tags file will only
contain entries with [canonical pathnames] [canon]. To enable this option
(which I strongly suggest doing when you run UNIX and use symbolic links)
execute the following Vim command:

    :let g:easytags_resolve_links = 1

## Troubleshooting

Once or twice now in several years I've experienced Exuberant Ctags getting
into an infinite loop when given garbage input. In my case this happened by
accident a few days ago :-|. Because my plug-in executes `ctags` in the
foreground this will block Vim indefinitely! If this happens you might be
able to kill `ctags` by pressing `Ctrl-C` but if that doesn't work you can also
kill it without stopping Vim using a task manager or the `pkill` command:

    pkill -KILL ctags

If Vim seems very slow and you suspect this plug-in might be the one to blame,
increase Vim's verbosity level:

    :set vbs=1

Every time the plug-in executes it will time how long the execution takes and
add the results to Vim's message history, which you can view by executing the
`:messages` command.

## Contact

If you have questions, bug reports, suggestions, etc. the author can be
contacted at <peter@peterodding.com>. The latest version is available at
<http://peterodding.com/code/vim/easytags> and
<http://github.com/xolox/vim-easytags>. If you like this plug-in please vote
for it on [www.vim.org] [vim_scripts_entry].

## License

This software is licensed under the [MIT license] [mit_license].  
© 2010 Peter Odding &lt;<peter@peterodding.com>&gt;.


[canon]: http://en.wikipedia.org/wiki/Canonicalization
[ctags]: http://en.wikipedia.org/wiki/Ctags
[ctags_support]: http://ctags.sourceforge.net/languages.html
[exuberant_ctags]: http://ctags.sourceforge.net/
[hardlinks]: http://en.wikipedia.org/wiki/Hard_link
[ide]: http://en.wikipedia.org/wiki/Integrated_development_environment
[latest_zip]: http://peterodding.com/code/vim/download.php?script=easytags
[mit_license]: http://en.wikipedia.org/wiki/MIT_License
[symlinks]: http://en.wikipedia.org/wiki/Symbolic_link
[vim]: http://www.vim.org/
[vim_scripts_entry]: http://www.vim.org/scripts/script.php?script_id=3114
[vim_support]: http://ftp.vim.org/vim/runtime/syntax/
