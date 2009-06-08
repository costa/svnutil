#!/bin/sh

if [ $# -gt 1 ]
    then
    /usr/local/bin/svn help import
    exit 1
fi

if [ $# -eq 0 ]
    then
    echo -e "svn help:  \"If PATH is omitted '.' is assumed.\"\n"
    opath='.'
else
    opath="$1"
fi

echo -e "# /usr/local/bin/svn status $opath\n"
if ! /usr/local/bin/svn status $opath
    then
    echo -e "\nERROR: Hmm.. See above!\n"
    exit 1
fi


echo -e "# /usr/local/bin/svn status $opath | /usr/bin/grep -E '^(C|~|.?C)'\n"
if /usr/local/bin/svn status $opath | /usr/bin/grep -E '^(C|~|.?C)'
    then
    echo -e "\nERROR: Please solve conflicts first!\n"
    exit 1
fi

echo -e "# /usr/local/bin/svn status $opath | /usr/bin/grep -E '^\!' | cut -c8-\n"
for todel in `/usr/local/bin/svn status $opath | /usr/bin/grep -E '^\!' | cut -c8-`
  do
  echo -e "# /usr/local/bin/svn remove $todel"
  if /usr/local/bin/svn remove $todel
      then
      echo -e "OK.\n"
  else
      exit $?
  fi
done

echo -e "# /usr/local/bin/svn status $opath | /usr/bin/grep -E '^\?' | cut -c8-\n"
for toadd in `/usr/local/bin/svn status $opath | /usr/bin/grep -E '^\?' | cut -c8-`
  do
  echo -e "# /usr/local/bin/svn add $toadd"
  if /usr/local/bin/svn add $toadd
      then
      echo -e "OK.\n"
  else
      exit $?
  fi
done

echo -e "# /usr/local/bin/svn -R list $opath\n"
for node in `/usr/local/bin/svn -R list $opath`
  do
    if [ -e $opath/$node ]
        then
        owner=`/usr/bin/stat -f '%Su:%Sg' $opath/$node`
        echo -e "# /usr/local/bin/svn propset svu:chown $owner $opath/$node"
        if /usr/local/bin/svn propset svu:chown $owner $opath/$node
            then
            echo -e "OK.\n"
        else
            exit $?
        fi

        moder=`/usr/bin/stat -f '%Mp%Lp' $opath/$node`
        echo -e "# /usr/local/bin/svn propset svu:chmod $moder $opath/$node"
        if /usr/local/bin/svn propset svu:chmod $moder $opath/$node
            then
            echo -e "OK.\n"
        else
            exit $?
        fi
    fi
done

echo -e "# /usr/local/bin/svn commit $opath"
if /usr/local/bin/svn commit $opath
    then
    echo -e "OK.\n"
else
    exit $?
fi
