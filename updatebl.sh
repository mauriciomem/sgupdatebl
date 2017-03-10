#!/bin/bash
# folders
dirbltmp='' # bl temp folder. Ex /tmp/bltmp 
dirbldst='' # bl destination folder. Ex /var/lib/squidguard/db
dirblsrc='' # bl source folder. Ex /tmp/blacklists
# admin
adminmail='johndoe@example.net'
mfrom=$(hostname -s)'@example.net'
fecha=$(date "+%F %T")
mailinfo='' # Ex $dirblsrc/update.log
logfile='' # Ex /var/log/bl.log'
cod=1

# Add bl to install
declare -A blacklists
blacklists=(
    [list]='url'
    [examplelist]='http://examplelist.com/lists/bl.tar.gz'
)
# Add categories to install
categories=() # Ex (warez porn publicite tracker redirector)

# Init controls
if [ ! "`ps auxw | grep squid[G]uard`" ]; then
        msg="$(date +%T) -- squidGuard no se encuentra levantado\n"
        echo "ERROR: $msg" | tee -a $logfile
        exit $cod
else
        if [ $(id -u) != "0" ]; then
                msg="$(date +%T) -- El script debe ser invocado por el usuario root\n"
                echo "ERROR: $msg" | tee -a $logfile
                exit $cod
        else
                msg="$fecha **** Actualizacion de blacklists ****"
                echo "INFO: $msg" | tee -a $logfile
                if [ -d $dirblsrc ] || [ -d $dirbltmp ]; then
                        msg="$(date +%T) -- Se eliminan y crean nuevamente las carpetas $dirblsrc y $dirbltmp\n"
                        echo "INFO: $msg" | tee -a $logfile
                        rm -rvf $dirblsrc $dirbltmp ; mkdir -v $dirblsrc $dirbltmp
                else
                        msg="$(date +%T) -- Se crean carpetas no existentes previamentes $dirblsrc y $dirbltmp\n"
                        echo "INFO: $msg" | tee -a $logfile
                        mkdir -v $dirblsrc $dirbltmp
                fi
        fi
fi
# Download, creation and merge of categories
for list in "${!blacklists[@]}"
do
        url=${blacklists[$list]}
        bldir=$dirblsrc/$list
        mkdir $bldir;
        wget -O $bldir.tar.gz $url
        for cat in ${categories[*]}
        do
        pathcatg=$(tar -ztf $bldir.tar.gz | grep -E /$cat.*[^/]$ | sed -n -e 's/\(url.$\|domain.$\|usage.$\|expression.$\)$//g' -e '1 p')
        pathdeep=$(tar -ztf $bldir.tar.gz | grep ^./.*$cat.*[^/]$ | sed -n '1 p')
        pathcatdst=$dirbldst/$cat
                if [ $pathcatg ]; then
                        if [ $pathdeep ]; then strip=2; else strip=1; fi
                        if [ ! -d $dirbltmp/$cat ]; then mkdir -v $dirbltmp/$cat; fi
                        msg="$(date +%T) -- Extrajendo categoria $cat de lista $lista en $bldir\n"
                        echo "INFO: $msg" | tee -a $logfile
                        tar --ungzip --extract --exclude=*.diff --directory=$bldir --strip-components=$strip -f $bldir.tar.gz $pathcatg
                        filecat=($(find $bldir/$cat -type f -exec basename {} \; 2>/dev/null | egrep \(domain.$\|url.$\)$))
                        for file in ${filecat[*]}
                        do
                                msg="$(date +%T) -- Creando archivo temporal $dirbltmp/$cat/$file correspondiente a lista $list\n"
                                echo "INFO: $msg" | tee -a $logfile
                                cat "$bldir/$cat/$file" | sort | uniq >> $dirbltmp/$cat/$file
                        done
                else
                        msg="$(date +%T) -- La categoria $categoria no se encuentra en la lista $list\n"
                        echo "INFO: $msg" | tee -a $logfile
                fi
                if [ -d $dirbldst ] && [ ! -d $pathcatdst ]; then
                        msg="$(date +%T) -- Se agrega nueva carpeta de categoria $cat en directorio destino $pathcatdst\n"
                        echo "INFO: $msg" | tee -a $logfile
                        mkdir -v $pathcatdst
                fi
        done
done
# Install or Update categories
if [ ! -d $dirbldst ]; then
        msg="$(date +%T) -- No se encontro blacklist en el servidor. Instalando blacklist descargada.\n"
        echo "INFO: $msg" | tee -a $logfile
        mkdir -vp $dirbldst;
        cp -rf $dirbltmp/* $dirbldst
else
        for pathbltmp in `find $dirbltmp -type f`
        do
                tmpcat=$(basename `dirname $pathbltmp`)
                tmpfile=$(basename $pathbltmp)
                if [ -d $dirbldst/$tmpcat ] && [ ! -e $dirbldst/$tmpcat/$tmpfile ]; then
                        msg="$(date +%T) -- La carpeta $dirbldst/$tmpcat no tiene el archivo $tmpfile, necesario para compilar. Se instala.\n"
                        echo "INFO: $msg" | tee -a $logfile
                        cp -f $pathbltmp $dirbldst/$tmpcat/
                else
                        for pathbldst in `find $dirbldst -type f | egrep \(domain.$\|url.$\)$`
                        do
                                dstcat=$(basename `dirname $pathbldst`)
                                dstfile=$(basename $pathbldst)
                                if [ $tmpcat == $dstcat ] && [ $tmpfile == $dstfile ]; then
                                        diff $pathbltmp $pathbldst; res_diff=$?
                                        if [ $res_diff = 0 ]; then
                                                msg="$(date +%T) -- No se encontraron diferencias en la categoria $dstcat entre $pathbltmp y $pathbldst\n"
                                                echo "INFO: $msg" | tee -a $logfile
                                        else
                                                msg="$(date +%T) -- Se instala bl categoria $dstcat en $rutabldst y se actualiza archivo $dstarch.diff con fecha $(find $dirbldst/$dstcat/$dstfile.diff -maxdepth 1 -printf '%f %CY-%Cm-%Cd\n')\n"
                                                echo "INFO: $msg" | tee -a $logfile
                                                diff -u $pathbltmp $pathbldst > $dirbldst/$dstcat/$dstfile.diff
                                                touch $mailinfo; echo "*** Actualizacion de blacklist $dirbldst/$dstcat/$dstarch" >> $mailinfo
                                                cat $dirbldst/$dstcat/$dstarch.diff >> $mailinfo
                                                cp -f $pathbltmp $pathbldst
                                                break
                                        fi
                                fi
                        done
                fi
        done
fi
# set perms
#chmod -Rv 644 $dirbldst >> $logfile 2>&1
chown -Rv $user.$group $dirbldst >> $logfile 2>&1
sleep 5s
# regenerate squidguard database
su - proxy -c "/usr/bin/squidGuard -c /etc/squidguard/squidGuard.conf -C all" >> $logfile 2>&1
sleep 5s
#reload squid
/etc/init.d/squid reload >> $logfile 2>&1

sleep 5s
exit 0
