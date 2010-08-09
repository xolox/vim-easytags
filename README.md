# Automated tag generation and syntax highlighting in Vim

[Vim] [vim] has long been my favorite text editor and combined with [Exuberant Ctags] [exuberant_ctags] it has the potential to provide most of what I expect from an [integrated development environment] [ide]. Exuberant Ctags is the latest incarnation of a [family of computer programs] [ctags] that scan source code files to create an index of identifiers (tags) and where they are defined. Vim uses this index (a so-called tags file) to enable you to jump to the definition of any identifier using the [Control-\]][jump_to_tag] mapping.

When you're familiar with integrated development environments you may recognize this feature as "Go-to definition". One advantage of the combination of Vim and Exuberant Ctags over integrated development environments is that Vim supports syntax highlighting for [over 500 file types] [vim_support] (!) and Exuberant Ctags can generate tags for [over 40 file types] [ctags_support] as well...

There's just one problem: You have to manually keep your tags files up-to-date and this turns out to be a royal pain in the ass! So I set out to write a Vim plug-in that would do this boring work for me. When I finished the plug-in's basic functionality (one automatic command and a call to [system()][system] later) I became interested in dynamic syntax highlighting, so I added that as well to see if it would work -- surprisingly well I'm happy to report!

## Install & usage

Unzip the most recent [ZIP archive] [latest_zip] file inside your Vim profile directory (usually this is `~/.vim` on UNIX and `%USERPROFILE%\vimfiles` on Windows), restart Vim and execute the command `:helptags ~/.vim/doc` (use `:helptags ~\vimfiles\doc` instead on Windows). Now try it out: Edit any file type supported by Exuberant Ctags and within ten seconds the plug-in should create/update your tags file (`~/.vimtags` on UNIX, `~/_vimtags` on Windows) with the tags defined in the file you just edited! This means that whatever file you're editing in Vim (as long as it's on the local file system), tags will always be available by the time you need them!

Additionally if the file you just opened is a C, C++, Objective-C, Java, Lua, Python, PHP or Vim source file you should also notice that the function and type names defined in the file have been syntax highlighted.

The `easytags.vim` plug-in is intended to work automatically once it's installed, but if you want to change how it works there are several options you can change and commands you can execute from your own mappings and/or automatic commands. These are all documented below.

Note that if the plug-in warns you `ctags` isn't installed you'll have to download it from its [homepage] [exuberant_ctags], or if you're running Debian/Ubuntu you can install it by executing the following shell command:

    $ sudo apt-get install exuberant-ctags

### The `g:easytags_cmd` option

The plug-in will try to determine the location where Exuberant Ctags is installed on its own but this might not always work because any given executable named `ctags` in your `$PATH` might not in fact be Exuberant Ctags but some older, more primitive `ctags` implementation which doesn't support the same command-line options and thus breaks the `easytags.vim` plug-in. If this is the case you can set the global variable `g:easytags_cmd` to the location where you've installed Exuberant Ctags, e.g.:

    :let g:easytags_cmd = '/usr/local/bin/ctags'

### The `g:easytags_file` option

As mentioned above the plug-in will store your tags in `~/.vimtags` on UNIX and `~/_vimtags` on Windows. To change the location of this file, set the global variable `g:easytags_file`, e.g.:

    :let g:easytags_file = '~/.vim/tags'

A leading `~` in the `g:easytags_file` variable is expanded to your current home directory (`$HOME` on UNIX, `%USERPROFILE%` on Windows).

### The `g:easytags_always_enabled` option

By default the plug-in automatically generates and highlights tags when you stop typing for a few seconds (this works using the [CursorHold][cursorhold] automatic command). This means that when you edit a file, the dynamic highlighting won't appear until you pause for a moment. If you don't like this you can configure the plug-in to always enable dynamic highlighting:

    :let g:easytags_always_enabled = 1

Be warned that after setting this option you'll probably notice why it's disabled by default: Every time you edit a file in Vim, the plug-in will first run Exuberant Ctags and then highlight the tags, and this slows Vim down quite a lot. I have some ideas on how to improve this latency by running Exuberant Ctags in the background (see my [shell.vim][shell] plug-in) so stay tuned!

Note: If you change this option it won't apply until you restart Vim, so you'll have to set this option in your [vimrc script][vimrc].

### The `g:easytags_on_cursorhold` option

As I explained above the plug-in by default doesn't update or highlight your tags until you stop typing for a moment. The plug-in tries hard to do the least amount of work possible in this break but it might still interrupt your workflow. If it does you can disable the periodic update:

    :let g:easytags_on_cursorhold = 0

Note: Like the `g:easytags_always_enabled` option, if you change this option it won't apply until you restart Vim, so you'll have to set this option in your [vimrc script][vimrc].

### The `g:easytags_resolve_links` option

UNIX has [symbolic links] [symlinks] and [hard links] [hardlinks], both of which conflict with the concept of having one unique location for every identifier. With regards to hard links there's not much anyone can do, but because I use symbolic links quite a lot I've added this option. It's disabled by default since it has a small performance impact and might not do what unknowing users expect it to: When you enable this option the plug-in will resolve symbolic links in pathnames, which means your tags file will only contain entries with [canonical pathnames] [canon]. To enable this option (which I strongly suggest doing when you run UNIX and use symbolic links) execute the following Vim command:

    :let g:easytags_resolve_links = 1

### The `:UpdateTags` command

This command executes [Exuberant Ctags] [exuberant_ctags] from inside Vim to update the global tags file defined by `g:easytags_file`. When no arguments are given the tags for the current file are updated, otherwise the arguments are passed on to `ctags`. For example when you execute the Vim command `:UpdateTags -R ~/.vim` (or `:UpdateTags -R ~\vimfiles` on Windows) the plug-in will execute `ctags -R ~/.vim` for you (with some additional arguments).

When you execute this command like `:UpdateTags!` (including the bang!) then all tags whose files are missing will be filtered from the global tags file.

Note that this command will be executed automatically every once in a while, assuming you haven't changed `g:easytags_on_cursorhold`.

### The `:HighlightTags` command

When you execute this command while editing one of the supported file types (see above) the relevant tags in the current file are highlighted. The tags to highlight are gathered from all tags files known to Vim (through the ['tags' option](http://vimdoc.sourceforge.net/htmldoc/options.html#'tags')).

Note that this command will be executed automatically every once in a while, assuming you haven't changed `g:easytags_on_cursorhold`.

## Troubleshooting

### The plug-in complains that Exuberant Ctags isn't installed

After a Mac OS X user found out the hard way that the `ctags` executable isn't always Exuberant Ctags and we spend a few hours debugging the problem I added proper version detection: The plug-in executes `ctags --version` when Vim is started to verify that Exuberant Ctags 5.5 or newer is installed. If it isn't Vim will show the following message on startup:

    easytags.vim: Plug-in not loaded because Exuberant Ctags isn't installed!
    Please download & install Exuberant Ctags from http://ctags.sf.net

If the installed Exuberant Ctags version is too old the plug-in will complain:

    easytags.vim: Plug-in not loaded because Exuberant Ctags 5.5
    or newer is required while you have version %s installed!

If you have the right version of Exuberant Ctags installed but the plug-in still complains, try executing the following command from inside Vim:

    :!which ctags

If this doesn't print the location where you installed Exuberant Ctags it means your system already had a `ctags` executable but it isn't compatible with Exuberant Ctags 5.5 and you'll need to set the `g:easytags_cmd` option (see above) so the plug-in knows which `ctags` to run.

### Vim locks up while the plug-in is running

Once or twice now in several years I've experienced Exuberant Ctags getting into an infinite loop when given garbage input. In my case this happened by accident a few days ago :-|. Because my plug-in executes `ctags` in the foreground this will block Vim indefinitely! If this happens you might be able to kill `ctags` by pressing [Control-C][control_c] but if that doesn't work you can also kill it without stopping Vim using a task manager or the `pkill` command (available on most UNIX systems):

    $ pkill -KILL ctags

If Vim seems very slow and you suspect this plug-in might be the one to blame, increase Vim's verbosity level:

    :set vbs=1

Every time the plug-in executes it will time how long the execution takes and add the results to Vim's message history, which you can view by executing the [:messages][messages] command.

### Failed to highlight tags because pattern is too big!

If the `easytags.vim` plug-in fails to highlight your tags and the error message mentions that the pattern is too big, your tags file has grown too large for Vim to be able to highlight all tagged identifiers! I've had this happen to me with 50 KB patterns because I added most of the headers in `/usr/include/` to my tags file. Internally Vim raises the error [E339: Pattern too long] [E339] and unfortunately the only way to avoid this problem once it occurs is to reduce the number of tagged identifiers...

In my case the solution was to move most of the tags from `/usr/include/` over to project specific tags files which are automatically loaded by Vim when I edit files in different projects because I've set the ['tags' option] [tags_option] as follows:

    :set tags=./.tags;,~/.vimtags

Once you've executed the above command, Vim will automatically look for a file named `.tags` in the directory of the current file. Because of the `;` Vim also recurses upwards so that you can nest files arbitrarily deep under your project directories.

## Contact

If you have questions, bug reports, suggestions, etc. the author can be contacted at <peter@peterodding.com>. The latest version is available at <http://peterodding.com/code/vim/easytags/> and <http://github.com/xolox/vim-easytags>. If you like this plug-in please vote for it on [www.vim.org] [vim_scripts_entry].

## License

This software is licensed under the [MIT license] [mit_license].  
© 2010 Peter Odding &lt;<peter@peterodding.com>&gt;.


[canon]: http://en.wikipedia.org/wiki/Canonicalization
[control_c]: http://vimdoc.sourceforge.net/htmldoc/pattern.html#CTRL-C
[ctags]: http://en.wikipedia.org/wiki/Ctags
[ctags_support]: http://ctags.sourceforge.net/languages.html
[cursorhold]: http://vimdoc.sourceforge.net/htmldoc/autocmd.html#CursorHold
[E339]: http://vimdoc.sourceforge.net/htmldoc/message.html#E339
[exuberant_ctags]: http://ctags.sourceforge.net/
[hardlinks]: http://en.wikipedia.org/wiki/Hard_link
[ide]: http://en.wikipedia.org/wiki/Integrated_development_environment
[jump_to_tag]: http://vimdoc.sourceforge.net/htmldoc/tagsrch.html#CTRL-]
[latest_zip]: http://peterodding.com/code/vim/downloads/easytags
[messages]: http://vimdoc.sourceforge.net/htmldoc/message.html#:messages
[mit_license]: http://en.wikipedia.org/wiki/MIT_License
[shell]: http://peterodding.com/code/vim/shell/
[symlinks]: http://en.wikipedia.org/wiki/Symbolic_link
[system]: http://vimdoc.sourceforge.net/htmldoc/eval.html#system()
[tags_option]: http://vimdoc.sourceforge.net/htmldoc/options.html#'tags'
[vim]: http://www.vim.org/
[vim_scripts_entry]: http://www.vim.org/scripts/script.php?script_id=3114
[vim_support]: http://ftp.vim.org/vim/runtime/syntax/
[vimrc]: http://vimdoc.sourceforge.net/htmldoc/starting.html#vimrc
