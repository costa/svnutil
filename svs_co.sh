#!/bin/sh

if [ $# -lt 1 ] || [ $# -gt 2 ]
    then
    /usr/local/bin/svn help checkout
    exit 1
fi

url="$1"

if [ $# -eq 1 ]
    then
    echo -e "svn help:  \"If PATH is omitted, the basename of the URL will be used as the destination.\"\n"
    opath="$1"
    opath="${opath%///}"
    opath="${opath%//}"
    opath="${opath%/}"
    opath="${opath##*/}"
else
    opath="$2"
fi

echo -e "# /usr/local/bin/svn status $opath\n"
if /usr/local/bin/svn status $opath
    then # an existing working copy, must check

    echo -e "# /usr/local/bin/svn status $opath | /usr/bin/grep -E '^(C|~|.?C)'\n"
    if /usr/local/bin/svn status $opath | /usr/bin/grep -E '^(C|~|.?C)'
        then
        echo -e "\nERROR: Please solve conflicts first!\n"
        exit 1
    fi

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
fi

echo -e "# /usr/local/bin/svn checkout $url $opath"
if /usr/local/bin/svn checkout $url $opath
    then
    echo -e "OK.\n"
else
    exit $?
fi

echo -e "# /usr/local/bin/svn -R list $opath\n"
for node in `/usr/local/bin/svn -R list $opath`
  do
  if [ -e $opath/$node ]
      then
      owner=`/usr/local/bin/svn propget svu:chown $opath/$node`
      echo -e "# /usr/sbin/chown -h $owner $opath/$node"
      if /usr/sbin/chown -h $owner $opath/$node
          then
          echo -e "OK.\n"
      else
          exit $?
      fi
          
      moder=`/usr/local/bin/svn propget svu:chmod $opath/$node`
      echo -e "# /bin/chmod -h $moder $opath/$node"
      if /bin/chmod -h $moder $opath/$node
          then
          echo -e "OK.\n"
      else
          exit $?
      fi
  fi
done
