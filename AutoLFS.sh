#!/bin/bash
#
# TODO add license , GPL or probably DTFWYW
#
# 2011-12, 2012-01 , Firer4t@googlemail.com
#
# This shell script shall create full install scripts for LFS
# ( http://www.linuxfromscratch.org )
# The actual commands are taken from LFS' svn ''make dump-commands''
# Q/ Why not just run the dump-commands straight as is?
# A/   The dumped scripts don't do untar an stuff, + I wanted to use
# Matthias S. Benkmann <article at winterdrache dot de> 's  ( excelent )
# http://www.linuxfromscratch.org/hints/downloads/files/more_control_and_pkg_man.txt
#
# initially I will concentrate on Chapters 5 and 6, and assume downloads are already done
#

#
# Alternatives:
# =============
# TBH, I'm kinda reinventing the wheel, there are other Automated solutions for LFS
# http://www.linuxfromscratch.org/alfs
#
LFS=$LFS

# TODO test to make sure it is there
#
DumpedCommands=$LFS/lfs-commands
Dumpedhtml=$LFS/lfs-html

WgetOpts="" # Options for wget, e.g. proxy settings etc

# the below are relative to installed system ( i.e. without $LFS prefix )
pkgscripts=/etc/pkgusr/scripts
sourcedir=/Source
builddir=/build
PkgUsers=/home/pkgusers

BuildLog=$LFS/LFS-buildlog.log
if [ ! -e $BuildLog ]; then
    touch $BuildLog
fi


Config () {
GetTimezone () {
if [ "$TZ" = "" ]; then
    TZ=`$( which tzselect | sed 's@/tools@/usr@' )` # horrid workaround TODO fix it
    echo "TZ=$TZ" | tee -a $cfg
fi
}
GetPapersize () {
if [ "$paper_size" = "" ]; then
    validpapersizes="`echo {A,B,C,D}{0..7} DL letter legal tabloid ledger statement executive com10 monarch`"
    PS3="Please select Paper size : "
    select paper_size in $validpapersizes;do
        case $paper_size in
           '') echo >&2 "Please enter a number listed above";;
           ?*) echo >&2 "You have Selected $paper_size";;
        esac
        echo >&2 ""
        PS3="Is this correct? : "
        select confirm in Yes No;do
            case $confirm in
                '') echo >&2 "Please enter 1 for Yes or 2 for No";;
                ?*) break
            esac
        done
        case $confirm in
             No) PS3="Please select Paper size (Enter to refresh list) : ";;
            Yes) echo "paper_size=$paper_size" | tee -a $cfg
                 break
        esac
    done
fi
}
DefaultSVN () {
#TODO if exists prompt for deletion (maybe)
install -vd $DefaultSVNLoc
echo "${REPO}_REPO=$DefaultSVNLoc" >> $cfg
}
GetLocalREPO () {
eval TEST_REPO=\$${REPO}_REPO
if [ "$TEST_REPO" != "" ];
then
    return
fi
echo >&2 "Local $REPO is not set"
PS3="What would you like to do? : "
select Action in \
    'Create local SVN repo' \
    'Use existing local SVN repo'
do
    case $Action in
    '') echo >&2 "Please select a numbered option";;
    ?*) case $Action in
        Create*) DefaultSVN;break
        ;;
        Use*)
            # build list of potential LFS svn repos ) only works relative to ~/
            unset Paths
            for Path in $( find $HOME -name index.xml -exec dirname {} ';' );do
            if [ -e $Path/.svn ];
            then
                Paths="$Paths $Path"
            fi
            done
            PathCount=$( echo $Paths | awk '{print NF}' )
            case $PathCount in
            0)  echo >&2 "Couldn't find any local svn repos ( containing index.xml )"
                echo >&2 "But I only checked ~/"
                echo >&2 "I will setup 'my own', but should you wish to you can edit $cfg"
                DefaultSVN;break
            ;;
            1) Path=$Paths
               svn info $Path >&2
               PS3="Is this correct? : "
               select confirm in Yes No;do
                   case $confirm in
                       '') echo >&2 "Please enter 1 for Yes or 2 for No";;
                       ?*) break
                   esac
               done
               case $confirm in
                    No) PS3="What would you like to do? : ";;
                   Yes) echo "${REPO}_REPO=$Path" | tee -a $cfg
                        break
               esac
            ;;
            *)
                PS3="which is your $REPO svn repo? : "
                select Path in $( echo $Paths | sed 's@'$HOME'@~@g');do
                    Path=$( echo $Path | sed 's@~@'$HOME'@' )
                    case $Path in
                    '') >&2 "Please select using number";;
                    ?*) echo >&2 "You have selected svn repo"
                        svn info $Path >&2
                        PS3="Is this correct? : "
                        select confirm in Yes No;do
                            case $confirm in
                                '') echo >&2 "Please enter 1 for Yes or 2 for No";;
                                ?*) break
                            esac
                        done
                        case $confirm in
                             No) PS3="What would you like to do? : ";;
                            Yes) echo "${REPO}_REPO=$Path" | tee -a $cfg
                                 break
                        esac
                    break
                    esac
                done
            ;;
            esac
        ;;
        esac
    ;;
    esac
    case $confirm in
    Yes) break;;
     No) PS3="What would you like to do? : "
esac
done
}
GetSVN () {
eval TEST_REPO=\$${REPO}_SVN_URL
if [ "$TEST_REPO" != "" ];
then
    return
fi
SVN_URL="svn://svn.linuxfromscratch.org"
Ignore="bootscripts"

PS3="Please select the book version : "
select TAG in 'Current Development' $( svn ls ${SVN_URL}/${REPO}/tags | grep -vE "$Ignore" );do
    case $TAG in
    '') echo >&2 "Please select a numbered option";;
    Current*)
        BOOK_SVN_URL="${SVN_URL}/${REPO}/trunk/BOOK"
    ;;
    ?*) BOOK_SVN_URL="${SVN_URL}/${REPO}/tags/$TAG"
    ;;
    esac
    echo >&2 "You have selected \'$TAG\'"
    echo >&2 "$BOOK_SVN_URL"
    PS3="Is this correct? : "
    select confirm in Yes No;do
        case $confirm in
            '') echo >&2 "Please enter 1 for Yes or 2 for No";;
            ?*) break
        esac
    done
    case $confirm in
         No) PS3="Please select the book version : ";;
        Yes) echo "${REPO}_SVN_URL=\"$BOOK_SVN_URL\"" | tee -a $cfg
             break
    esac
done
}
#Gawd, that is a mess
cfg=~/.AutoLFS.cfg
if [ -e $cfg ]; then
    . $cfg
fi

# TODO Tidy up this mess

GetTimezone
GetPapersize

for REPO in LFS BLFS;do
    DefaultSVNLoc=$HOME/LFS_SVN/$REPO
    GetLocalREPO
    GetSVN
done
# make sure we have sourced the config we have written
. $cfg
}
CheckoutSVN () {
for REPO in LFS BLFS;do
    eval Dir=\$${REPO}_REPO
    eval Url=\$${REPO}_SVN_URL
    Tag=$( basename $Url )
    case $Tag in
        BOOK) # don't spam, once a day should be fine
              # TODO stay locked to a revision
              Tag=WIP
              eval ${REPO}_BOOK=\$${REPO}_REPO/$Tag
              if [ -e ${Dir}/$Tag/.svn/entries ];
              then
                  EntriesDate=$( stat --printf=%y ${Dir}/$Tag/.svn/entries | awk 'gsub(/-/,"") {printf $1}' )
                  if [ "$EntriesDate" -le "$( date +%Y%m%d )" ];
                  then
                      continue
                  fi
              fi
          ;;
          ?*) # tags should only need to be checked out once
              if [ ! -e ${Dir}/$Tag/.svn/entries ];
              then
                  eval ${REPO}_BOOK=\$${REPO}_REPO/$Tag
                  continue
              fi
          ;;
    esac
svn co $Url ${Dir}/$Tag
done
}
DumpCommands () {
# for the moment only interested in LFS
Tag=$( basename $LFS_SVN_URL )
case $Tag in
    BOOK) Tag=WIP
    ;;
esac
SVNINFO="`svn info $LFS_REPO/$Tag | awk '{printf $0"|"}'`"
# Note, tagged | on the end so it can be used as a record separator later
# e.g.
#   echo $SVNINFO | awk 'BEGIN{ RS = "|" }; {print $0}'
# will 'reconstitute it
SVNrevision=$( echo $SVNINFO | awk 'BEGIN{ RS = "|" };/Revision/ {print $0}' )
#for dir in $DumpedCommands $Dumpedhtml;do
for dir in $DumpedCommands ;do
    if [ ! -d $dir ];
    then
        install -vd $dir
        touch $dir/.version
    fi
done
#for dir in $DumpedCommands $Dumpedhtml;do
for dir in $DumpedCommands ;do
    if [ -e "$dir" -a "$SVNrevision" != "$( cat $dir/.version | awk '/Revision/ {print $0}')" ];
    then
        rm -r $dir
        install -vd $dir
        pushd $LFS_REPO/$Tag
            #make BASEDIR=$Dumpedhtml
            make DUMPDIR=$DumpedCommands maketar dump-commands
            #for dir in $DumpedCommands $Dumpedhtml;do
            for dir in $DumpedCommands ;do
                echo $SVNINFO | awk 'BEGIN{ RS = "|" }; {print $0}' > $dir/.version
            done
        popd
        break
    fi
done
}
GetSource () {
#TODO put this in the chapter05 Script
make -f $LFS_REPO/$Tag/Makefile -C $LFS_REPO/$Tag BASEDIR=${LFS}${sourcedir} wget-list md5sums
WgetList=${LFS}${sourcedir}/wget-list
md5sums=${LFS}${sourcedir}/md5sums

# Move `out of date` tarballs
SourceArchive=$LFS/Source_Old
#TODO option to delete old stuff instead of moving it

# Future TODO, option to checkout src from some cvs repo
for File in $( ls ${LFS}${sourcedir} );do
   case $File in
     more_control_*|wget-list|md5sums) continue;;
     ?*)
       if [ "$( grep -q $File $WgetList ; echo $? )" = "1" ];
       then
           install -vd $SourceArchive
           mv -v ${LFS}${sourcedir}/$File $SourceArchive/$File
       fi
   esac
done
pushd ${LFS}${sourcedir}
    RequiredFiles=$( md5sum --quiet -c $md5sums 2> /dev/null | awk -F\: '!/OK/{printf "%s ",$1}' )
popd
for File in $RequiredFiles;do
    Url=$( grep $File $WgetList )
    wget $WgetOpts -c $Url -O ${LFS}${sourcedir}/$File
    # TODO handle d/l error
done
# undo symlink fudge
find ${LFS}${sourcedir} -type l -exec rm {} ';'
# redo symlink fudge
case $( ls ${LFS}${sourcedir} ) in
    linux-*) ln -s $File ${LFS}${sourcedir}/linux-headers.tar.$( echo $File | awk -F\. '{print $NF}' );;
    xz-*) ln -s $File ${LFS}${sourcedir}/xz-utils-.tar.$( echo $File | awk -F\. '{print $NF}' );;
esac
# TODO, maybe make the symlink fudge redundent
}
GetCommands () {
find ${DumpedCommands}/${Chapter}/ -name "*${Name}" -exec cat {} ';'
}
Header () {
cat > $Output << "EOF"
#!/bin/bash -e
EOF
echo "me=\$0
LFS=$LFS
SVNINFO=\"$SVNINFO\"
pkgscripts=$pkgscripts
sourcedir=$sourcedir
builddir=$builddir
PkgUsers=$PkgUsers
BuildLog=$BuildLog
" >> $Output

CreateBuildDir >> $Output
unpack >> $Output
}

more_control_helpers () {
cat >> $Output << "EOF"
more_control_helpers_ () {
if [ "`grep -q more_ctrl_helpers\:. /etc/passwd;echo $?`" == "0" ];
then
    echo "Skipping more_control_helpers"
    return
fi
#
# in the long run,
# it makes life easier to have the pkguser tools installed with their own id instead of root
#
echo "more_ctrl_helpers:x:9998:9998:more_ctrl_helpers:/etc/pkgusr:/bin/bash" >> /etc/passwd
echo "more_ctrl_helpers:x:9998:" >> /etc/group

cd /tools
#cd `tar vxf ${sourcedir}/more_control_helpers.tar.bz2 | awk -F\/ 'END{print $1}'`
tar vxf ${sourcedir}/more_control_helpers.tar.bz2
cd more_control_helpers
if [ "$?" == "0" ];
then
    chown -R more_ctrl_helpers:more_ctrl_helpers .
else
    echo "failed to extract package helpers ;("
    exit 1
fi
cp -v ./sbin/* /tools/bin
cp -av /tools/more_control_helpers/etc /etc/pkgusr
cp -av /tools/more_control_helpers/lib /usr/lib/pkgusr
cp -v /tools/more_control_helpers/bin/* /usr/bin
cp -v /tools/more_control_helpers/sbin/* /usr/sbin
rm -v /usr/sbin/{useradd,groupadd}
ln -sv su-tools /tools/bin/su

groupadd -g 9999 install

## Nasty workaround
# well, at least dumb it down a little
chgrp install /tools/libexec/pt_chown
chmod 4750 /tools/libexec/pt_chown
## Why the work around?
# Normally Chapter 06 is carried out as root, which has no problems doin rooty type stuffs
# As pkgusers have no root powers they get stuck creating ptys for expect which is used in testsuites
# setting pt_chown suid solves this issue.
# Restricting execution to root and the install group effectivly means you need root
# ( as the only way to get to a pkguser is via su from root )
# At least that's the plan

cat >> /etc/pkgusr/bash_profile << "BashProfile"
#
complete -o default -o nospace -A user su finger pinky
export MAKEFLAGS='-j 14'
export Pkg=$LOGNAME
export PKGUSERS=/home/pkgusers
if [ -e /etc/pkgusr/scripts/${LOGNAME}.sh -a ! -e ~/.${LOGNAME} ];
then
    cd
    bash -e /etc/pkgusr/scripts/${LOGNAME}.sh
    exit
fi
BashProfile
install -v -d /etc/pkgusr/scripts
ln -sv /etc/pkgusr/scripts  /etc/pkgusr/skel-package/scripts
cat > /sbin/fixSticky << "fixSticky"
#!/bin/bash -e
for i in `find /bin /sbin /usr /opt /lib /etc /var/lib -type d ! -group install`;do
   echo "chgrp install $i && chmod g+w,o+t $i"
   chgrp install $i && chmod g+w,o+t $i
done
#TODO - put this some place else
# this makes sure pkgusers can update dir
for i in `find /*{,/*}/share/info   -type f -name dir ! -user root \
                                 -o -type f -name dir ! -group install \
                                 -o -type f -name dir ! -perm 664`;do
    chown root:install $i
    chmod 664 $i
done
fixSticky
chmod 755 /sbin/fixSticky
/sbin/fixSticky

touch /.lfs
}
EOF
}

Function () {
case $Name in
    changingowner|kernfs|chroot)
    # meh, fix my mess
    case $Name in
        changingowner)
        Chapter=`echo $Chapter | sed s/06/05/`
    ;;
    esac
    WriteScript
    return
;;
esac
echo "${FuncName}_ () {
FuncName=$FuncName
Name=$Name
Pkg=$Pkg
BuildDir=\${LFS}\${builddir}/\$FuncName" >> $Output
case "$Chapter" in
chapter05)
    case $Name in
    readjusting|adjusting|stripping|creatingdirs|createfiles)
    cat >> $Output << "EOF"
BuildDir=~/
EOF
    TestBuilt
    ;;
    gcc-pass1|gcc-pass2)
    TestBuilt
cat >> $Output << "EOF"
CreateBuildDir

# chapter 5 gcc requires some extra stuff
for i in mpfr gmp mpc;do
       ln -sfv ${LFS}${sourcedir}/${i}*.*z* .
done

unpack

EOF

    ;;
    *)
    TestBuilt
cat >> $Output << "EOF"

CreateBuildDir
unpack

EOF
    ;;
    esac
;;
chapter06)
    case $Name in
    chroot|kernfs|readjusting|strippingagain|adjusting|creatingdirs|createfiles)
    cat >> $Output << "EOF"
if [ "`grep -q \"$Name\" $BuildLog;echo $?`" == "0" ];
then
    echo "skipping $Name"
    return
fi
EOF
    ;;
    *)
    cat >> $Output << "EOF"
if [ -e "$PkgUsers/$Name/.$Name" ];
then
    echo "skipping $Name"
    return
fi

cat > ${pkgscripts}/${Name}.sh << "IPS"
Pkg=$LOGNAME
EOF
    ;;
    esac
    echo "Name=$Name
sourcedir=$sourcedir" >> $Output
    case $Name in
       chroot|revisedchroot|kernfs|readjusting|strippingagain|adjusting|creatingdirs|createfiles)
       ;;
       *)
            unpack >> $Output
            cat >> $Output << "EOF"
unpack
EOF
       ;;
    esac
;;
esac
WriteScript
closefunction
}
closefunction () {
case "$Chapter" in
    chapter05)
        cat >> $Output << "EOF"
echo ${Name} >> $BuildLog
}
EOF
    ;;
    chapter06)
        case $Name in
            chroot|kernfs|readjusting|adjusting|strippingagain|creatingdirs|createfiles)
                cat >> $Output << "EOF"
echo ${Name} >> $BuildLog
}
EOF
            ;;
            *)
                 cat >> $Output << "EOF"
touch ~/.${Name}
IPS
EOF
                 resolvelinks
                 cat >> $Output << "EOF"
if [ "`grep -q ^$Pkg\: /etc/passwd;echo $?`" != "0" ];
then
    add_package_user "$Pkg" $Pkg 10000 20000 $Pkg 10000 20000
fi
resolvelinks
su $Pkg
if [ ! -e $PkgUsers/$Name/.$Name ];
then
    echo "${Pkg} failed"
    exit 1
fi
if [ "`ldconfig`" = "" ]; then echo "";fi
fixSticky
}
EOF
            ;;
        esac
    ;;
esac
}

resolvelinks () {
# At the begining of chapter 06 we include some symlinks to the tools dir
# Trouble is these will now get in the way of package users, as the links are owned by root
# Relativly painless to fix.
case $Pkg in
    gcc)
        Extra=""
        links="/usr/lib/libgcc_s.so{,.1} /usr/lib/libstdc++.so{,.6}"
    ;;
    bash)
        Extra=""
        links="/bin/bash"
    ;;
    coreutils)
        Extra=""
        links="/bin/{cat,echo,false,pwd,stty} /etc/group"
    ;;
    perl)
        Extra=""
        links="/usr/bin/perl"
    ;;
    shadow)
        Extra=""
        links="/usr/share/man/man{5/passwd.5,3/getspnam.3} /etc/{passwd,shadow,group,gshadow}{,-}"
    ;;
    sysklogd)
        Extra=""
        links="/usr/share/man/man8/sysklogd.8"
    ;;
    udev)
        Extra="install -dv /lib/{firmware,udev/devices/pts} && mknod -m0666 /lib/udev/devices/null c 1 3 && fixSticky"
        links="/lib/{firmware,udev/devices/pts}"
    ;;
    *)
        Extra=""
        links=""
    ;;
esac
echo "resolvelinks () {
$Extra
for link in $links;do
   if [ -e "\$link" ];
   then
       chown -h \$Pkg:\$Pkg \$link
   fi
done
return
}" >> $Output
}

CreateBuildDir () {
cat << "EOF"
CreateBuildDir () {
BuildDir=${LFS}${builddir}/$FuncName
if [ ! -e $BuildDir ];
then
    install -d $BuildDir
    cd $BuildDir
else
    cd $BuildDir
fi
}
EOF
}

unpack () {
case $Pkg in
    udev)
    cat << "EOF"
unpack () {
ln -sf ${LFS}${sourcedir}/${Pkg}*.* .
cd `tar vxf ${Pkg}-???.tar*z* | awk -F\/ 'END{print $1}'`
}
EOF
    ;;
    *)
    cat << "EOF"
unpack () {
ln -sf ${LFS}${sourcedir}/${Pkg}*.* .
cd `tar vxf ${Pkg}*z* | awk -F\/ 'END{print $1}'`
}
EOF
   ;;
esac
}

TestBuilt () {
    cat >> $Output << "EOF"
if [ "`grep -q \"$Name\" $BuildLog;echo $?`" == "0" ];
then
    echo "skipping $Name"
    return
fi
EOF
}

WriteScript () {
# Fixup some stuff

case $Name in
    binutils*|gcc*)
        # these create build dirs, which can be a pita if you have a hangover
        # ( mkdir exits none zero and the script exits ) so
        GetCommands \
        | sed -e 's/make -k /make -kj1 /' \
        | awk '{if ($1 == "mkdir")
                    print "if [ ! -e "$NF" ];\nthen\n    "$0"\nfi\n";
                else
                    print $0
               }' \
        >> $Output
    ;;
    glibc)
        # set up glibc's timezone
        # + fix the builddir issue
        GetCommands \
        | sed -e '/tzselect/d' \
              -e 's[\*\*EDITME<xxx>EDITME\*\*['$TZ'[' \
        | awk '{if ($1 == "mkdir")
                      print "if [ ! -e "$NF" ];\nthen\n    "$0"\nfi\n";
                  else
                      print $0
                 }' \
        >> $Output
    ;;
    e2fsprogs)
        GetCommands \
        | awk '{if ($1 == "mkdir")
                    print "if [ ! -e "$NF" ];\nthen\n    "$0"\nfi\n";
                else
                    print $0
               }' \
        >> $Output
    ;;
    bash)
       GetCommands \
        | sed -e '/nobody/d' \
              -e '/--login/d' \
        >> $Output

    ;;
    groff)
        GetCommands \
        | sed -e 's/\*\*EDITME<paper_size>EDITME\*\*/'$paper_size'/' \
        >> $Output
    ;;
    gmp)
        # if building for 64bit need to remove config for 32
        # TODO fix this
        GetCommands \
        | sed -e '/ABI=32/d' \
        >> $Output
    ;;
    procps)
       #
       GetCommands \
        | sed -e '/make install/ i sed -i /ldconfig/d Makefile' \
        >> $Output
    ;;
    stripping)
        # strip always exits with 1, wrap it up in an if to dodge bash's -e flag
        GetCommands \
        | awk '{if (/strip/) printf "if [ \"`"$0"`\" = \"1\" ];\nthen\n    echo \""$0" done\"\nfi\n";else print $0}' \
        >> $Output
    ;;
    createfiles)
        # we don't want/need to start a new shell just yet
        GetCommands \
        | sed '/exec \/tools\/bin\/bash --login +h/d' \
        >> $Output
    ;;
    gawk|flex)
        # gawk-4.0.0's make check has a race condition, so force jobs to 1
        # hmm, so does flex-2.5.35
        #
        GetCommands \
        | sed -e 's/check/-j1 check/' \
        >> $Output
    ;;
    shadow)
        # don't set root passwd, a pkguser dont haz nuf p0wuz
        # setup shadow pssswd files
        GetCommands \
        | sed -e '/passwd root/d' \
              -e '/pwconv/ i touch /etc/shadow\nchmod 640 /etc/shadow' \
              -e '/grpconv/ i touch /etc/gshadow\nchmod 640 /etc/shadow' \
        >> $Output
    ;;
    sysklogd)
       # fix the Make file to use the install wrapper and not the default install bin
       GetCommands \
        | awk '{if ($NF == "install" && $1 == "make") $1 = "make INSTALL=/usr/lib/pkgusr/install"; print $0}' \
        >> $Output
    ;;
    sysvinit)
        # tries to instal a fifo to /dev/, which is kinda pointless
        GetCommands \
        | sed -e '/install/ i sed -i '\''s/mknod/echo mknod/'\''  src/Makefile' \
        >> $Output
    ;;
    texinfo)
        # tries, and fails, to clobber /usr/share/info/dir
        GetCommands \
        | sed -e '/rm -v dir/d' \
              -e 's/dir/dir-/' \
              -e '/dir-/ a cat dir- > dir\nrm dir-' \
        >> $Output
    ;;
    udev)
        # we do these as root
        GetCommands \
        | sed -e '/install -dv\|mknod/d' \
        >> $Output
    ;;
    vim)
        GetCommands \
        | sed -e 's/make test/make -j1 test/' \
              -e '/:options/d' \
        >> $Output
    ;;
    strippingagain)
        # this strip is a little more awkward
        #
        GetCommands \
        | sed -e '/logout/ i echo "Woot\nWe are done, well nearly\ncopy'\''n'\''paste the below\n"' \
              -e 's/^/echo "/' \
              -e 's/\$/\\$/g' \
              -e 's/\\$/\\\\/' \
              -e 's/$/"/' \
        >> $Output
        cat >> $Output << "EOF"
echo "
#
# NOTE , if you want to do serious debuging then you don't want to strip
# instead just skip this copy'n'paste
#
# from now on use the ~/LFS-chroot.sh script to enter"
EOF
    ;;
    zlib)
        # fix race conditions
        GetCommands \
        | sed -e 's/make/make -j1/' \
        >> $Output
    ;;
    *)
        GetCommands \
        >> $Output
    ;;
esac
}

cleanstart () {
for Script in chapter{05,06,06-asroot,06-chroot}.sh LFS-chroot.sh;do
   for loc in $LFS ~/;do
      if [ -e $loc/$Script ]; then rm $loc/$Script;fi
   done
done
}

Start () {
cleanstart

for Chapter in chapter{05,06};do
   Output=$LFS/${Chapter}.sh
   Header
   for Name in $( awk -F\" '/href/ && !/<!--/ {gsub(/\.xml/,"");print $(NF -1)}' ${LFS_BOOK}/${Chapter}/${Chapter}.xml );do
      FuncName=$( echo $Name | sed -e s/-//g )
      Pkg=$( echo $Name | sed -e s/pass.$// -e s/-$// )
      Output=$LFS/${Chapter}.sh
      case $Name in
          introduction|toolchaintechnotes|generalinstructions|pkgmgt|aboutdebug)
          continue
      ;;
      changingowner|kernfs)
          Chapter=`echo $Chapter | sed s/05/06/`
          # changingowner is at the end of chapter 5, but you need to be root
          # made sense to shift it into chapter06's 'requires root' script
          Output=$LFS/${Chapter}-asroot.sh
          Function
      ;;
      chroot)
          Output=$LFS/${Chapter}-chroot.sh
          # if you log out, reboot or whatever you need to mount the kernelfs again
          # So, include some conditionals to look after that
          cat $LFS/${Chapter}-asroot.sh \
          | awk '/mount -v/ { printf "if [ \"`grep -q \""$NF"\" /proc/mounts;echo $?`\" != \"0\" ];\nthen\n    "$0"\nfi\n"}' \
          >> $Output
          Function
      ;;
      revisedchroot)
          Output=~/LFS-chroot.sh
          # use this once LFS chapter06  is done, again conditionals added
          cat $LFS/${Chapter}-asroot.sh \
          | awk '/mount -v/ {printf "if [ \"`grep -q \""$NF"\" /proc/mounts;echo $?`\" != \"0\" ];\nthen\n    "$0"\nfi\n"}' \
          >> $Output
          WriteScript
      ;;
      createfiles)
          Function
          # Now that we have a base file structure add more_control_helpers

          more_control_helpers

      ;;
      *)
          Function
      ;;
      esac
   done
done
# add more_control_helpers
Output=$LFS/chapter05.sh
cat >> $Output << "EOF"
more_control_helpers_ () {
cd /tools
if [ ! -e ${LFS}${sourcedir}/more_control_helpers.tar.bz2 ];
then
    wget -O ${LFS}${sourcedir}/more_control_helpers.tar.bz2 -c http://linuxfromscratch.org/~chris/more_control_helpers.tar.bz2
fi
}
EOF
for Script in $LFS/chapter{05,06,06-asroot,06-chroot} ~/LFS-chroot;do
   Output=${Script}.sh
   awk '/_\ \(\)\ \{/ {print $1}' $Output >> $Output
   chmod 700 $Output
done
sed -e s@#!/bin/bash@#!/tools/bin/bash@ -e 's@BuildLog='$LFS'@BuildLog=@' -i $LFS/chapter06.sh
# remove checks from chapter05
sed -e '/make check/d' \
    -e '/make test/d' \
    -i $LFS/chapter05.sh
}





Config
CheckoutSVN
DumpCommands
GetSource
Start
