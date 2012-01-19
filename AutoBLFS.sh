#!/bin/bash
trialrun="$1"
book=~/BLFS/BOOK
ENTITIES=$book/general.ent
Output=~/BLFSscripts
BLFSsrc=/Source
Passwd=/etc/passwd
#Passwd=~/fakePasswd
wgetlist=~/public_html/blfs-book-xsl/wget-list
commands=~/blfs-commands
Header () {
echo "#!/bin/bash" > $Output
echo "Passwd=$Passwd" >> $Output
cat >> $Output << "Header"
BLFSsrc=/Source
pkgscripts=/etc/pkgusr/scripts
GetFiles () {
cat << "EOF"
GetFiles () {
BLFSsrc=/Source
for File in $Downloads $Patches;do
   # suppose I could grab the md5sum and test that
   if [ ! -e ${BLFSsrc}/`basename $File` ];
   then
       wget -c $File -O ${BLFSsrc}/`basename $File`
       ln -sf ${BLFSsrc}/`basename $File` .
   fi
done
}
EOF
}
UnPack () {
cat << "EOF"
UnPack () {
# bit hacky, assume that the first is our main tarball ( pretty sure it always is )
Tarball=$( basename $( echo $Downloads | awk '{print $1}') )
cd `tar vxf $Tarball | awk -F\/ 'END{print $1}'`
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

# we want to use a wget list if available
if [ "`grep -q "ENT.*-wget" $Pkg;echo $?`" == "0" ];
then
    DLRule="ENT.*-wget"
else
    DLRule="ENT.*-download-"
fi
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
GetCommands () {
for i in `find $commands -type f -name "???-${FullName}"`;do
   echo "commands () {" >> $Output
   echo "#Begin $i"
   case $Name in
       which)
           # the book's commands includes two solutions, full package and a script
           # For now I will kill the script version, but in future will set this up as an option
           CustomSed="-e /cat/,/chown/d"
       ;;
       aspell)
           # need to sort out a dictionary
       ;;
       unzip)
           CustomSed="-e /This.block.must.be.edited/,/End.of.editable.block/d"
       ;;
       *)
           CustomSed=""
       ;;
   esac
   cat $i \
   | sed -e '/mencoder -dvd/,/mencoder -forceidx/d' $CustomSed \
   | awk '{
           sub(/swat >>/,"swat\" >>")
           sub(/>>>/,">>")
           if (/EDITME/ || /uudecode="no"/) sub(/^/,"#",$0)
           if ( $NF ==  "&&" ) $NF = ""
          ;print
          }'


   echo "}" >> $Output
   echo "#End $i"
done
#TODO fix the below, it will be much better to pull from the book instead of having to dump_commands
#sed -e '/<screen><userinput>/,/<.userinput><.screen>/!d' \
#    -e 's/<.*serinput>//g' \
#    -e 's/<.*creen>//g' \
#    -e 's/&amp;/&/g' \
#    -e 's/&lt;/</g' \
#    -e 's/&gt;/>/g' \
#$Pkg \
#| awk '/gsub(/&amp;/,"&"){print}'
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



Header
# Trialrun is $1, which should be a package 'name', it is simply for testing
if [ "$trialrun" == "" ];
then
    Pkgs=`find $book -type f -name "*.xml" `
else
    Pkgs=`find $book -type f -name "${trialrun}.xml"`
fi
for Pkg in $Pkgs;do
    Section=`dirname $Pkg | sed s@$book@@`
    case $(basename $Section) in
       common|otherlibs|welcome)
         continue
       ;;
    esac
    FullName=`basename $Pkg .xml`
    if [ "`find $commands -type f -name "???-${FullName}"`" = "" ];
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
           Group=Xorg
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
               Required="$Required PerlModule-`grep -B1 $i $book/general/prog/perl-modules.xml | awk '/<!--/{print $2}'`"
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
