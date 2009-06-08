#!/bin/sh

if [ $# -lt 1 ] || [ $# -gt 2 ]
    then
    /usr/local/bin/svn help import
    exit 1
fi

echo -e "\nWARNING: Check the svn ignores for the file types you might want to import!"
echo -e "    (though the installation defaults are probably okay)\n"

sleep 3

if [ $# -eq 1 ]
    then
    echo -e "svn help:  \"If PATH is omitted '.' is assumed.\"\n"
    opath='.'
    url="$1"
else
    opath="$1"
    url="$2"
fi

echo -e "# /usr/local/bin/svn -m '' import $opath $url"
if /usr/local/bin/svn -m '' import $opath $url
    then
    echo -e "OK.\n"
    else
    exit $?
fi

tmpath="/tmp/`/bin/date '+%Y%m%d%H%M%S'`"

echo -e "# /usr/local/bin/svn checkout $url $tmpath"
if /usr/local/bin/svn checkout $url $tmpath
    then
    echo -e "OK.\n"
else
    exit $?
fi

echo -e "# /usr/local/bin/svn -R list $tmpath\n"
for node in `/usr/local/bin/svn -R list $tmpath`
  do
  owner=`/usr/bin/stat -f '%Su:%Sg' $opath/$node`
  echo -e "# /usr/local/bin/svn propset svu:chown $owner $tmpath/$node; /usr/sbin/chown -h $owner $tmpath/$node"
  if /usr/local/bin/svn propset svu:chown $owner $tmpath/$node \
      && /usr/sbin/chown -h $owner $tmpath/$node
      then
      echo -e "OK.\n"
  else
      exit $?
  fi

  moder=`/usr/bin/stat -f '%Mp%Lp' $opath/$node`
  echo -e "# /usr/local/bin/svn propset svu:chmod $moder $tmpath/$node; /bin/chmod -h $moder $tmpath/$node"
  if /usr/local/bin/svn propset svu:chmod $moder $tmpath/$node \
      && /bin/chmod -h $moder $tmpath/$node
      then
      echo -e "OK.\n"
  else
      exit $?
  fi
done

echo -e "\nWARNING!WARNING!WARNING!: Destructive changes are about to be made to $opath!"
echo -e "    (It is critical that the files will NOT be accessed during the moving)\n"

sleep 3
read -p "Are you sure? (yes/no) " domove

case $domove in
    [Yy][Ee][Ss])

    echo -e "# mkdir ${tmpath}.old; mv $opath ${tmpath}.old/; mv $tmpath $opath"
    if mkdir ${tmpath}.old \
        && mv $opath ${tmpath}.old/ \
        && mv $tmpath $opath
        then
        echo -e "OK.\n"
    else
        exit $?
    fi

    echo -e "# /usr/local/bin/svn -m '' commit $opath"
    if /usr/local/bin/svn -m '' commit $opath
        then
        echo -e "OK.\n"
    else
        exit $?
    fi

    echo -e "\nWARNING: Be sure to 'rm -Rf ${tmpath}.old' after reviewing the changes!\n"

    exit 0

    ;;
esac

echo -e "\nWARNING: Be sure to 'rm -Rf ${tmpath}' after reviewing the problems!\n"
