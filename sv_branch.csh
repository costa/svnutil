#!/bin/echo For sourcing from inside a sv_init_PROJ script only, not running like

cd $WORK_DIR/$SVN_PROJ

set svn_branches = `ls -d [ef]_* | grep -vE '\..+$'`

if ("$svn_branches" == "") exit

set wb_def = `readlink curr_branch`;

echo 'Here are your working branches:'
set wb_num = 0
set wb_def_num = ''
foreach wb ($svn_branches)
  @ wb_num++
  echo "$wb_num. $wb"
  if ($wb == $wb_def) set wb_def_num = $wb_num
end
echo -n "Enter the branch number from the list (or 0 to exit) [$wb_def_num]: "
set wb_ent_num = $<
if ("$wb_ent_num" == "") set wb_ent_num = $wb_def_num
if ($wb_ent_num < 1 || $wb_ent_num > $wb_num) exit

\mkdir $svn_branches[$wb_ent_num].build >& /dev/null
\mkdir $svn_branches[$wb_ent_num].bench >& /dev/null
\rm curr_build >& /dev/null
\rm curr_bench >& /dev/null
\rm curr_branch >& /dev/null
\ln -s $svn_branches[$wb_ent_num].build curr_build
\ln -s $svn_branches[$wb_ent_num].bench curr_bench
\ln -s $svn_branches[$wb_ent_num] curr_branch

if (! -e build.env && -e $svn_branches[$wb_ent_num]/build/${OSTYPE}_build.env) echo "Note that you can 'cp $WORK_DIR/$SVN_PROJ/$svn_branches[$wb_ent_num]/build/${OSTYPE}_build.env $WORK_DIR/$SVN_PROJ/build.env' to initialize the build environment automatically."

if (-e build.env) if ("`find $svn_branches[$wb_ent_num]/build/ -name ${OSTYPE}_build.env -newer build.env`" != "") echo "Note that you can 'cp $WORK_DIR/$SVN_PROJ/$svn_branches[$wb_ent_num]/build/${OSTYPE}_build.env $WORK_DIR/$SVN_PROJ/build.env' to get the updated build-environment-initializing script."

cd $svn_branches[$wb_ent_num]

echo "You are welcome to $SVN_PROJ/$svn_branches[$wb_ent_num]."
