#!/bin/echo For sourcing from inside a sv_init_PROJ script only, not running like

# svnutil aliases

#TODO(low) Rewrite all this for bash and automate the code below by
#          implementing svnutil.pl functionality request command (svfunc)

foreach svcmd (svco svci  svmf svmd svmv svrm  sv_mkenh sv_mkfix sv_rework  svss sv_update  sva_mkproj sva_mkver sva_lstr)
    alias $svcmd $SVN_UTIL/svnutil.pl $svcmd
end

alias svst '\svn status'

echo 'Override any disabled commands by escaping them (e.g. \mv)'

# disable rm and mv

foreach nonsv (rm mv rmdir mkdir md)
    alias $nonsv echo "svnutil: Please don\'t use $nonsv with the revisioned files. Use appropriate svnutil command instead. Disabled $nonsv"
end

# disable original subversion commands

alias $SVN echo "svnutil: Please don\'t use the svn command directly as it may interfere with the svnutil commands. Disabled svn"
alias svnadmin echo "svnutil: A developer is not supposed to run svnadmin. Please \'unalias svnadmin\' if you\'re an admin and you know what you\'re doing. Disabled svnadmin"
