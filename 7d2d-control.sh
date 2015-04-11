#!/bin/bash -e

# Message to stderr and exit 1.
errExit() {
    echo "$@" >&2
    exit 1
}

printUsage() {
echo "Usage: $0 <task> <config>"
}

printUsageAndExit() {
  printUsage
  exit 1
}

task="$1"
cfg="$2"

[ -n "$task" ] || printUsageAndExit
[ -f "$cfg" ] || printUsageAndExit

steam_user=""
admin_pass=""
home_dir=""
server_name=""

. "$cfg"

[ -n steam_user ] || errExit "Property steam_user not set in the config file ${cfg}"
[ -n admin_pass ] || errExit "Property admin_pass not set in the config file ${cfg}"
[ -n home_dir ] || errExit "Property home_dir not set in the config file ${cfg}"
[ -n server_name ] || errExit "Property server_name not set in the config file ${cfg}"

save_dir=${home_dir}/savegame/${server_name}
server_dir=${home_dir}/server
backup_dir=${home_dir}/backup
steamcmd_dir=${home_dir}/steamcmd
config_dir=${home_dir}/config
log_dir=${home_dir}/log

config_file=${config_dir}/${server_name}-config.xml
admin_file=${config_dir}/${server_name}-admin.xml
log_file=${log_dir}/${server_name}.log

# use  "_64" for 64-bit, "" for 32-bit
bitCount=""

installSteam() {
  echo ""
  echo "Installing steam..."
  echo ""
  dir=$1
  [ -n ${dir} ] || errExit "Argument DIR is required"
  if [ ! -d ${dir} ]; then
     mkdir -p ${dir}
  fi

  if hash curl; then
     curl -s http://media.steampowered.com/installer/steamcmd_linux.tar.gz | tar -xz -C ${dir}
  elif hash wget; then
     wget -q http://media.steampowered.com/installer/steamcmd_linux.tar.gz -O - | tar -xz -C ${dir}
  else
    echo "No curl OR wget ??? WTF kind of server is this ?"
    exit 1
  fi
}

echo ""
[ $EUID -eq 0 ] && errExit "ERROR: This script must not be run using sudo or as the root user"
[ -z "${steam_user}" ] && errExit "ERROR: No steam user entered, create file user.txt with steam login."

[ -f ${steamcmd_dir}/steamcmd.sh ] || installSteam ${steamcmd_dir}

case "$task" in
  start)
    echo "Starting 7dtd..."
    ${server_dir}/7DaysToDie.x86${bitCount} -logfile ${log_file} -quit -batchmode -nographics -configfile=${config_file} -dedicated
  ;;

  stop)
    echo "Not supported yet."
  ;;

  update)
    [ -d ${steamcmd_dir} ] || installSteam ${steamcmd_dir}

    echo "Updating 7d2d..."

    [ -d ${backup_dir} ] || mkdir -p ${backup_dir}
    [ -d ${server_dir} ] || mkdir -p ${server_dir}
    [ -d ${config_dir} ] || mkdir -p ${config_dir}

    [ -f ${config_file} ] && cp ${config_file} ${backup_dir}/${server_name}-config.xml.`date -I`
    [ -f ${admin_file} ] && cp ${admin_file} ${backup_dir}/${server_name}-admin.xml.`date -I`
    
    ${steamcmd_dir}/steamcmd.sh +@ShutdownOnFailedCommand 1 +login "${steam_user}" +force_install_dir "${server_dir}" +app_update 294420 validate +quit

    [ -f ${config_file} ] || cp ${server_dir}/serverconfig.xml ${config_file}

    echo "Updated ${server_dir}"

    $0 configure ${cfg}
  ;;

  backup) 
    echo "Backuping 7d2d savegames from ${save_dir}..."
    sleep 8
    [ -d ${backup_dir} ] || mkdir ${backup_dir}
    tar cvzf ${backup_dir}/${server_name}-`date -I`.tar.gz ${save_dir}
  ;;

  configure)
    echo "Your configuration is in ${config_file}"
    echo "Set SaveGameFolder to ${save_dir}"
    #sed -i "s@<!--property name=\"SaveGameFolder\"[^>]+@<property name=\"SaveGameFolder\" value=\"\"/@" ${config_file}
    #sed -i "s@name=\"SaveGameFolder\"[:space:]+value=\"[^\"]*@name=\"SaveGameFolder\" value=\"${save_dir}@" ${config_file}
  ;;

  *)
    printUsageAndExit
  ;;
esac

echo ""
