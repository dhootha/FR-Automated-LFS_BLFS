#!/bin/bash
trialrun="$1"
Header () {
echo "#!/bin/bash" > $Output
echo "XORG_PREFIX=\"$XORG_PREFIX\"" >> $Output
cat >> $Output << "Header"
set -e

BLFSsrc=/SourceBLFS
pkgscripts=/etc/pkgusr/scripts
GetFiles () {
cat << "EOF"
GetFiles () {
BLFSsrc=/SourceBLFS
loopcount=0
for File in $Downloads;do
   if [ "` echo $File | grep -qE "/$" ;echo $?`" = "0" ];
   then
       eval Mirror${loopcount}=$File
       Downloads=`echo $Downloads | sed 's@'$File'@@'`
       loopcount=`expr $loopcount + 1`
   elif [ "` echo $File | grep -qE "wget$" ;echo $?`" = "0" ];
   then
       wget -c $File
       Downloads=`echo $Downloads | sed 's@'$File'@@'`
       wgetlist=`basename $File`
   elif [ "` echo $File | grep -qE "md5$" ;echo $?`" = "0" ];
   then
       wget -c $File
       Downloads=`echo $Downloads | sed 's@'$File'@@'`
       md5list=`basename $File`
   fi
done
for File in $Downloads $Patches;do
   # suppose I could grab the md5sum and test that
   if [ ! -e ${BLFSsrc}/`basename $File` ];
   then
       wget -c $File -O ${BLFSsrc}/`basename $File`
   fi
   ln -sf ${BLFSsrc}/`basename $File` .
done
}
EOF
}
UnPack () {
cat << "EOF"
UnPack () {
# TODO , re-write this, for now just skip unpack if we have a wgetlist or just writing xorg config
if [ "$wgetlist" != "" ]; then return;fi
case $Name in
    profile|xorg7) return;;
esac
Tarball=$( basename $( echo $Downloads | awk '{print $1}') )
ext=`echo $Tarball | awk -F\. '{print $NF}'`
case $ext in
    zip) cd `unzip $Tarball | awk '/:/{print $NF}' | awk -F\/ 'END{print $1}'`;;
    ?*) cd `tar vxf $Tarball | awk -F\/ 'END{print $1}'`;;
esac
}
EOF
}
######################################

######################################
Header
}
CheckReq () {
cat << "EOF"
#for Req in $Required $Optional;do
for Req in $Required ;do
if [ "`grep -q ^${Req}$ /etc/pkgusr/Installed;echo $?`" != "0" ];
then
   case $Req in
       PerlModule*)
           su perl -c "cpan -i $( echo $Req | sed 's/PerlModule-//' )"
       ;;
       *)
           ${Req}_
       ;;
   esac
fi
done
EOF
}
GetDownloadInfo () {
# lol, this is messy
# but meh, it works, and this is just a shell script so who cares :)
GetEntities () {
EntRaw=$(echo $1 | sed -e s/__//)
Ent=$(echo $EntRaw | sed -e s/-/_/g)
echo "$Ent=$(awk -F\" '/ENTITY '$EntRaw' / {print $2}' $ENTITIES )"
}
GetEntsLoop () {
AnEnt=`GetEntities $1`
if [ "`echo $AnEnt | grep -q \&;echo $?`" = "0" ];
then
    for i in `echo $AnEnt | awk '{gsub(/\;/," ;",$0) gsub(/&/," &",$0); for(i=1; i <= NF; i++) if ( $i ~ /^&/ ) {sub(/&/,"",$i); print $i } }'`;do
       Link=`echo $AnEnt | AwkIt` ; Links="$Link `echo $Links | sed 's['$Link'[['`"
       GetEntsLoop $i
       #echo $AnEnt | AwkIt
    done
fi
#echo $AnEnt | AwkIt
Link=`echo $AnEnt | AwkIt` ; Links="$Link `echo $Links | sed 's['$Link'[['`"
return
}
AwkIt () {
awk '{gsub(/\;/," ;",$0) gsub(/&/," &",$0)
          for(i=1; i <= NF; i++)
             if ( $i ~ /&/ )
                gsub(/-/,"_",$i)
                gsub(/&/,"${",$0)
                gsub(/ ;/,"}",$0)
                gsub(/ /,"",$0)
                sub(/">/,"");
                print $0; }'
}
DLRule="ENT.*-download-|ENT.*-wget|ENT.*-md5sum.*md5.>$"
PatchRule="url=.*diff|url=.*patch"
Ents="$(for Rule in $DLRule $PatchRule;do
      cat $Pkg | sed '/<!--/,/-->/d' | awk '/'$Rule'/{gsub(/\;/," ;",$0 )
                     gsub(/&/," &",$0);
                     for(i=1; i <= NF; i++)
                       if ( $i ~ /^&/ )
                         {
                           sub(/&/,"",$i);
                           print $i
                         }
                     }'
done)"
for Entity in $Ents;do
   GetEntsLoop $Entity
done
echo $Links | sed 's/\ /\n/g'
Downloads="$(cat $Pkg | sed '/<!--/,/-->/d' | awk -F\" '/'$DLRule'/ && !/-->/ { ($0 = $2);gsub(/\;/," ;",$0);gsub(/&/," &",$0);print $0; }' | awk '{for(i=1; i <= NF; i++)if ( $i ~ /&/ ) gsub(/-/,"_",$i); gsub(/&/,"${",$0) gsub(/ ;/,"}",$0) gsub(/ /,"",$0); print $0 }')"

Patches="$(cat $Pkg | sed '/<!--/,/-->/d' | awk -F\" '/'$PatchRule'/&& !/-->/{print $2}' | AwkIt)"
}
DumpCommands () {
eval REPODIR=\$${1}_REPO/\$${1}_SVN_TAG
target=$( echo $1 | awk '{print tolower($1)}')
SVNINFO="`svn info $REPODIR | awk '{printf $0"|"}'`"
# Note, tagged | on the end so it can be used as a record separator later
# e.g.
#   echo $SVNINFO | awk 'BEGIN{ RS = "|" }; {print $0}'
# will 'reconstitute it
SVNrevision=$( echo $SVNINFO | awk 'BEGIN{ RS = "|" };/Revision/ {print $0}' )
for dir in $DumpedCommands ;do
    if [ ! -d $dir ];
    then
        install -vd $dir
        touch $dir/.revision
    fi
done
for dir in $Dumpedhtml $DumpedCommands ;do
    if [ -e "$dir" -a "$SVNrevision" != "$( cat $dir/.revision | awk '/Revision/ {print $0}')" ];
    then
        rm -r $Dumpedhtml $DumpedCommands
        pushd $REPODIR
            make -j1 DUMPDIR=$DumpedCommands BASEDIR=$Dumpedhtml $target dump-commands
            for dir in $DumpedCommands $Dumpedhtml;do
                echo $SVNINFO | awk 'BEGIN{ RS = "|" }; {print $0}' > $dir/.revision
            done
        popd
        break
    fi
done
}
GetCommands () {
for i in `find $DumpedCommands -type f -name "???-${FullName}"`;do
   echo "commands () {" >> $Output
   echo "#Begin $i"
   case $Name in
       which)
           # the book's commands includes two solutions, full package and a script
           # For now I will kill the script version, but in future will set this up as an option
             cat $i | sed -e '/cat/,/chown/d' ;;
       aspell)
           # TODO need to sort out a dictionary
       ;;
       unzip) cat $i | sed -e '/This.block.must.be.edited/,/End.of.editable.block/d' ;;
       xorg7) cat $i | sed -e '/xc/d' ;;
        lynx) cat $i | sed -e '/chgrp/d' ;;
       junit) cat $i | sed -e '/AllTests/d' ;;
         x7*) cat $i | sed -e '/.md5/ a for i in \$(grep\ -v\ ^#\ ../\$wgetlist);do\npushd \$( tar vxf \$i | awk -F\\/ '\''{print\ \$1}'\'')' \
                           -e '/mkdir/ i set +e' \
                           -e '/&&/d' \
                           -e '/mkdir/ a set -e' \
                           -e 's/ln -sv/ln -sfv/'
              echo -e "popd\ndone";;
  fontconfig) cat $i | sed -e 's@^install@/usr/lib/pkgusr/install@' -e 's/m755/m1775/';;
     texlive) cat $i | sed -e 's/&&//' -e 's/>>>/>>/';;
           *) cat $i | sed -e 's/&&//' -e '/make -C doc p/d';;
              # TODO fix this
              # make ps pdf requires TeX which is *Huge*
              # eventually setup an option for it
   esac

   echo "}"
   echo "#End $i"
done
}

InstallPkgUser () {
cat << "EOF"
InstallPkgUser () {
if [ "`grep -q ^${Name}\: /etc/passwd;echo $?`" != "0" ];
then
    add_package_user "$Name" $Name 10000 20000 $Group 10000 20000
fi
su $Name
}
EOF
}

InstallScript () {
#cat > ${pkgscripts}/${Name}.sh << "IPS"
##!/bin/bash -e
#IPS
cat << "EOF"
echo "
Name=\$LOGNAME
Downloads=\"$Downloads\"
Patches=\"$Patches\"
XORG_PREFIX=$XORG_PREFIX
XORG_CONFIG=\"--prefix=\$XORG_PREFIX --sysconfdir=/etc --mandir=\$XORG_PREFIX/share/man --localstatedir=/var\"
" > ${pkgscripts}/${Name}.sh

GetFiles >> ${pkgscripts}/${Name}.sh
UnPack >> ${pkgscripts}/${Name}.sh
EOF
cat << "EOF"
cat >> ${pkgscripts}/${Name}.sh << "IPS"
EOF
GetCommands
cat << "EOF"
GetFiles
UnPack
commands
touch ~/.$LOGNAME
echo $LOGNAME | sed s'/-/_/g' >> /etc/pkgusr/Installed
IPS
EOF
}



#config (){
. ~/.AutoLFS.cfg

if [ "$XORG_PREFIX" = "" ];
then
    XORG_PREFIX=/usr/X11
fi
#}
BLFS_BOOK=${BLFS_REPO}/${BLFS_SVN_TAG}
ENTITIES=$BLFS_BOOK/general.ent
Output=$LFS/BLFSscripts.sh
#TODO remove 'hardcoding' of BLFSsrc, probably echo it into pkgusers bash_profile
BLFSsrc=/SourceBLFS
DumpedCommands=$LFS/blfs-commands
Dumpedhtml=$LFS/blfs-html

DumpCommands BLFS
Header
# Trialrun is $1, which should be a package 'name', it is simply for testing
if [ "$trialrun" == "" ];
then
    Pkgs=`find $BLFS_BOOK -type f -name "*.xml" `
else
    Pkgs=`find $BLFS_BOOK -type f -name "${trialrun}.xml"`
fi
for Pkg in $Pkgs;do
    Section=`dirname $Pkg | sed s@$BLFS_BOOK@@`
    case $(basename $Section) in
       common|otherlibs|welcome)
         continue
    esac
    FullName=`basename $Pkg .xml`
    if [ "`find $DumpedCommands -type f -name "???-${FullName}"`" = "" ];
    then
        continue
    fi
    Name=`basename $Pkg .xml|sed s/\+//g`

    Grp=`echo $Section | awk -F\/ '{print $2}'`
    case $Grp in
        gnome|kde|kde4|multimeda|networking)
           Group=$Grp
        ;;
        x)
           Group=xorg
        ;;
        *)
           Group="$Name"
        ;;
    esac
    echo "Processing $Pkg"
    FuncName=`echo $Name | sed -e 's/-/_/g'`
    Version=`awk -F\" '/ '${Name}'-version/ {gsub(/\ /,"."); print $2}' $ENTITIES | head -n1`
#    if [ "$Version" == "" ]; then continue;fi
    depen=required
    # TODO push recomended into required
    required="$(cat $Pkg \
                | sed -e '/<!--/d' \
                      -e 's/recommended/required/g' \
                      -e '/<para role="'$depen'">/,/^$/!d' \
                      -e 's/<xref linkend=/\n/g' \
                      -e 's/python/python2/g' \
                | awk -F\" '{if (!/'$depen'/) printf $2" ";}' )"
    Required=""
    for i in $required;do
       case $i in
           perl-*)
               # these are perl modules
               Required="$Required PerlModule-`grep -B1 $i $BLFS_BOOK/general/prog/perl-modules.xml | awk '/<!--/{print $2}'`"
           ;;
           xorg7-*)
               Required="$Required $( echo $i | sed 's/org7-/7/' )"
           ;;
           *)
               Required="$Required $( echo $i | sed 's/-/_/g' )"
           ;;
       esac
    done
    depen=optional
    Optional="$(cat $Pkg \
                | sed -e '/<!--/d' \
                      -e '/<para role="'$depen'">/,/^$/!d' \
                      -e 's/<xref linkend=/\n/g' \
                      -e 's/python/python2/g' \
                | awk -F\" '{if (!/'$depen'/) printf $2" ";}' )"

    echo "${FuncName}_ () {" >> $Output
    echo "FuncName=${FuncName}_ # To dump this function.. sed '/\${FuncName} () {/,/#End_\${FuncName}$/!d' \$0" >> $Output
    echo "# `awk '/\$Date\:/ {print}' $Pkg`" >> $Output
    echo "Section=\"$Section\"" >> $Output
    echo "Group=$Group" >> $Output
    echo "# Downloads" >> $Output
    GetDownloadInfo >> $Output
    echo "Downloads=\"$Downloads\"" >> $Output
    echo "Patches=\"$Patches\"" >> $Output
    echo "###########" >> $Output
    echo "Name=$Name" >> $Output
#    echo "Version=\"$Version\"" >> $Output
    echo "Required=\"$Required\"" >> $Output
    echo "Optional=\"$Optional\"" >> $Output
    CheckReq >> $Output
    InstallPkgUser >> $Output
    InstallScript >> $Output
    echo "InstallPkgUser" >> $Output
    echo "fixSticky" >> $Output
    echo "ldconfig" >> $Output
    echo "}" >> $Output
    echo "#End_${FuncName}" >> $Output
    echo "" >> $Output
    Links=""
done
cat >> $Output << "EOF"
if [ "$1" != "" ];
then
    ${1}_
fi
EOF
