#! /bin/bash

cd "${BASH_SOURCE%/*}" || exit

RED="\033[31m"
YELLOW="\033[33m"
WHITE_BRIGHT="\033[97m"
GOLD="\033[93m"
RESET="\033[0m"
YAML_FILE=""
DATE_TIME=$(date +%Y%m%d-%H%M)
HOST_NAME=$(hostname)
BACKUP_COMPRESS=false
DELETE=false
FORCE=false
INSPECT_IMAGE_VOLUME="null"
BACKUP_INSPECTION_DATA="n"
BACKUP_CONTAINER_IMAGES="n"
BACKUP_VOLUMES="n"

check_backup_path(){
  # Check if backup path exists
  if ! [ -d "$BACKUP_PATH_MAIN" ];
  then
    # Attempt to create the directory - TIME
    if ! mkdir -p "$BACKUP_PATH"
    then
      echo "${WHITE_BRIGHT}Error: backup path does not exist and could not be created${RESET}"
      exit 1
    fi

    # Check if backup path is writable
    if ! touch "$BACKUP_PATH/RW-check.txt" 2>/dev/null
    then
      echo "${WHITE_BRIGHT}Error: backup path is not writable${RESET}"
      exit 1
    else
      rm "$BACKUP_PATH/RW-check.txt"
    fi
  fi
}
    
delete_file_path(){
  #Check if backup path is empty
  if [ "$(ls -A "$BACKUP_PATH_MAIN")" ];
  then
    echo -e "${RED}Warning: ${WHITE_BRIGHT}The file backup path is not empty, but according to the settings in the yml file, all files are deleted.\n${RESET}"
    rm -rf $BACKUP_PATH_MAIN/*
  else
    echo -e "${WHITE_BRIGHT}Backup path is empty\n${RESET}"
  fi
}    

compress(){

    if [ "$BACKUP_COMPRESS" = true ]
    then

      SIZE=$(du -sb $BACKUP_PATH | cut -f 1)
      tar -cf - $BACKUP_PATH -P | pv -rep -N Compressing -s $SIZE > $BACKUP_PATH_MAIN/$HOST_NAME-$DATE_TIME.tar.gz

      rm -rf $BACKUP_PATH
      
      echo -e "${GOLD}Backup file path: $BACKUP_PATH_MAIN/$HOST_NAME-$DATE_TIME.tar.gz${RESET}"
    else
      echo -e "${GOLD}Backup directory path: $BACKUP_PATH${RESET}"
    fi
}

inspect_data(){

  CONTAINER_NAME=$BACKUP_CONTAINER_NAME
  CONTAINER_NETWORK_NAME=$(docker container inspect $CONTAINER_NAME | jq -r '.[].NetworkSettings.Networks | keys[0]')
  CONTAINER_NETWORK=$(docker network inspect $CONTAINER_NETWORK_NAME | jq -r '.[]')
  CONTAINER_DATA=$(docker inspect "$CONTAINER_NAME" | jq -r '.[]')

  mkdir -p "$BACKUP_PATH/$CONTAINER_NAME"
   echo -e -n "  inspection data & network- "
  echo "$CONTAINER_DATA" > "$BACKUP_PATH/$CONTAINER_NAME/$CONTAINER_NAME-inspect-$DATE_TIME.json"
  echo "$CONTAINER_NETWORK" > "$BACKUP_PATH/$CONTAINER_NAME/$CONTAINER_NAME-network-inspect-$DATE_TIME.json"
  echo -e "${GOLD}Done${RESET}"
}

images(){

  CONTAINER_NAME=$BACKUP_CONTAINER_NAME
  CONTAINER_IMAGE=$(docker inspect --format='{{.Config.Image}}' "$CONTAINER_NAME")
  mkdir -p "$BACKUP_PATH/$CONTAINER_NAME"
  SAVE_FILE="$BACKUP_PATH/$CONTAINER_NAME/$CONTAINER_NAME-image-$DATE_TIME.tar"
  echo -e -n "  container images - "

  docker save -o "$SAVE_FILE" "$CONTAINER_IMAGE"
  # docker save -o - "$CONTAINER_IMAGE" | pv -re | tee "$SAVE_FILE"
  
  echo -e "${GOLD}Done${RESET}"
}

volumes(){

  CONTAINER_NAME=$BACKUP_CONTAINER_NAME
  mkdir -p "$BACKUP_PATH/$CONTAINER_NAME"

  echo "  volumes details"
  NUMBER_MOUNTS=$(docker inspect $CONTAINER_NAME | jq '.[].Mounts | length') 
  echo "    Mounts Number:" $NUMBER_MOUNTS
  
  j=0
  for ((j=0; j<NUMBER_MOUNTS; j++)); do

    VOULME_TYPE=$(docker inspect $CONTAINER_NAME | jq -r '.[].Mounts['$j'].Type')
    VOULME_NAME=$(docker inspect $CONTAINER_NAME | jq -r '.[].Mounts['$j'].Name')
    VOULME_SOURCE=$(docker inspect $CONTAINER_NAME | jq -r '.[].Mounts['$j'].Source')
    VOULME_DESTINATION=$(docker inspect $CONTAINER_NAME | jq -r '.[].Mounts['$j'].Destination')
    VOULME_RW=$(docker inspect $CONTAINER_NAME | jq -r '.[].Mounts['$j'].RW')

    echo -e "    Mounts Type: $VOULME_TYPE"
    echo -e "    Mounts Name: $VOULME_NAME"
    echo -e "    Mounts Source: $VOULME_SOURCE"
    echo -e "    Mounts Destination: $VOULME_DESTINATION"
    echo -e -n "    Mounts Volume Size: KB " 
    echo "scale=2; $(du -sb $VOULME_SOURCE | cut -f1) / 1024" | bc
    echo -e "    Mounts Read/Write: $VOULME_RW"

    SIZE=$(du -sb $VOULME_SOURCE | cut -f 1)
       
    if [ "$VOULME_TYPE" == "bind" ];
    then
      
      # tar -czf "$BACKUP_PATH/$CONTAINER_NAME/$VOULMES/$HOST_NAME-$DATE_TIME.tar.gz" "$VOULME_SOURCE" >/dev/null 2>&1 
      tar -cf - $VOULME_SOURCE -P | pv -re -N Backing -s $SIZE > $BACKUP_PATH/$CONTAINER_NAME/$CONTAINER_NAME-volumes-$DATE_TIME.tar.gz

    elif [ "$VOULME_TYPE" == "volume" ];
    then
     
      #  docker run --rm -v "$VOULME_SOURCE":/volume -v "$BACKUP_PATH/$CONTAINER_NAME/$VOULMES":/backup alpine tar -cvzf /backup/"$HOST_NAME-$DATE_TIME".tar.gz /volume >/dev/null 2>&1
      tar -cf - $VOULME_SOURCE -P | pv -re -N Backing -s $SIZE > $BACKUP_PATH/$CONTAINER_NAME/$CONTAINER_NAME-volumes-$DATE_TIME.tar.gz 

    fi
  done
  echo -e "  The backup of the volumes is finished - "${GOLD}Done${RESET}""
}

requisite(){

 if ! command -v jq &>/dev/null;
 then
    echo "jq could not be found, but can be installed with: "
    echo "apt install jq"
    echo "jq is a command line tool for processing JSON data."
    exit 1
 fi

 if ! command -v yq &>/dev/null;
 then
    echo "yq could not be found, but can be installed with:"
    echo "apt install yq"
    echo "yq is a command line tool designed to convert and process YAML files."
    exit 1
 fi
 
 if ! command -v pv &>/dev/null;
 then
    echo "pv could not be found, but can be installed with:"
    echo "apt install pv"
    echo "The pv utility is a command line utility on Linux operating systems that is used to display data while transferring files."
    exit 1
 fi

 if ! command -v docker >/dev/null 2>&1; then
   echo "Docker is not installed."
   exit 1
 fi
}


#main()
if [ "$1" == "-h" ];
then  
  echo ""
  echo "Usage:  backup-container [filename].yml"
  echo "        This script backs up the image and container volumes on the system"
  echo "        User's guide to use the script, for more guidance, refer to the address https://github.com/mojtabco/backup-containers"
  echo "    -h  show the help"
  exit 1
fi
[ "$1" == "" ] || [ ! -f "$1" ] && echo "Usage:  backup-containers [filename].yml" && exit 1


# Checks that jq,yq,pv and docker tools are installed
requisite

YAML_FILE=$1
BACKUP_PATH_MAIN=$(yq -r .backups.BACKUP_PATH_MAIN $YAML_FILE)
BACKUP_COMPRESS=$(yq -r .backups.BACKUP_COMPRESS $YAML_FILE)
DELETE=$(yq -r .backups.DELETE $YAML_FILE)
FORCE=$(yq -r .backups.FORCE $YAML_FILE)

if [ "$BACKUP_PATH_MAIN" == "null" ];
then
  # Default path
  BACKUP_PATH_MAIN="$(pwd)/backups"
  mkdir -p $BACKUP_PATH_MAIN
else
  BACKUP_PATH_MAIN="$BACKUP_PATH_MAIN/backups"
fi
BACKUP_PATH=$BACKUP_PATH_MAIN/$HOST_NAME-$DATE_TIME

check_backup_path

echo ""
echo -e "Current operation information"
echo -e "To back up, the information is read from the $YAML_FILE file"
echo -e "Backup path: $BACKUP_PATH"
echo -e "Delete all the files and folders of the backup path: $DELETE"
echo -e "The backup files must be compressed: $BACKUP_COMPRESS"
readarray -t CONTAINERS_AVAILABLE < <(docker ps -aq | xargs docker inspect --format='{{.Name}}' | cut -f2 -d/)
echo "---------------------------------------------------------------"
echo -e "Check the containers available in the system with the yml file"

i=0
STEPS=$(yq -r .backups.steps[$i] $YAML_FILE)
while [[ "$STEPS" != "null" && "$STEPS" != "" ]]; do

    BACKUP_CONTAINER_NAME=$(yq -r .backups.steps[$i].step.container_name $YAML_FILE)
    FOUND=false
    echo -n $BACKUP_CONTAINER_NAME

    for TEMP in "${CONTAINERS_AVAILABLE[@]}"; do
      if [[ "$TEMP" == "$BACKUP_CONTAINER_NAME" ]]; then
        FOUND=true
        echo -e " - ${GOLD}Done${RESET}"
        break
      fi
    done
   
    if [[ "$FOUND" = false ]]; then
      echo -e " - ${GOLD}Containers not available${RESET}"
      echo ""
      echo "List of containers available in the system"
      printf "%s\n" "${CONTAINERS_AVAILABLE[@]}"
      echo -e "${GOLD}Please edit the yml file according to the containers in the system${RESET}"
      echo ""
      exit 1
    fi

    i=$((i + 1))
    STEPS=$(yq -r .backups.steps[$i] $YAML_FILE)
done

if [ "$FORCE" = false ];
then
    echo -n -e "Press y key to continue (y/N)?: "
    read -r TEMP
    [[ ! "$TEMP" =~ ^[Yy]$ ]] && exit 1
fi

START_TIME=$(date +%s)

if [ "$DELETE" = true ];
then
  delete_file_path
fi

echo ""
echo -e "${GOLD}Backing up container: please wait..."
echo -e "-----------------------------------------------${RESET}"
i=0
STEPS=$(yq -r .backups.steps[$i] $YAML_FILE)
while [[ "$STEPS" != "null" && "$STEPS" != "" ]]; do

  BACKUP_CONTAINER_NAME=$(yq -r .backups.steps[$i].step.container_name $YAML_FILE)
  BACKUP_CONTAINER_STATE=$(yq -r .backups.steps[$i].step.container_state $YAML_FILE)
  BACKUP_INSPECTION_DATA=$(yq -r .backups.steps[$i].step.environment.INSPECT $YAML_FILE)
  BACKUP_CONTAINER_IMAGES=$(yq -r .backups.steps[$i].step.environment.IMAGE $YAML_FILE)
  BACKUP_VOLUMES=$(yq -r .backups.steps[$i].step.environment.VOLUME $YAML_FILE)

  CONTAINER_STATUS=$(docker inspect $BACKUP_CONTAINER_NAME | jq -r '.[].State.Status')
  CONTAINER_RUNING=$(docker inspect $BACKUP_CONTAINER_NAME | jq -r '.[].State.Running')
  CONTAINER_PAUSED=$(docker inspect $BACKUP_CONTAINER_NAME | jq -r '.[].State.Paused')

  echo -e "Container: $BACKUP_CONTAINER_NAME"
  echo -e "Status: $CONTAINER_STATUS"
  echo -e "Running: $CONTAINER_RUNING"
  echo -e "Paused: $CONTAINER_PAUSED"

  if [ $BACKUP_VOLUMES == "yes" ];
  then
    if [[ $BACKUP_CONTAINER_STATE == "stop" || $BACKUP_CONTAINER_STATE == "pause" ]];
    then
      # running   paused   exited
      if [ $CONTAINER_STATUS == "running" ]; then
        docker container "$BACKUP_CONTAINER_STATE" "$BACKUP_CONTAINER_NAME" >/dev/null 2>&1
        echo "Container $BACKUP_CONTAINER_NAME $BACKUP_CONTAINER_STATE Success."
      else
        echo "Container $BACKUP_CONTAINER_NAME is already $BACKUP_CONTAINER_STATE."   
      fi 
    fi
  fi  
  
  [ $BACKUP_INSPECTION_DATA == "yes" ] && inspect_data
  [ $BACKUP_CONTAINER_IMAGES == "yes" ] && images
  [ $BACKUP_VOLUMES == "yes" ]  && volumes

  # The last state of the container after backup
  CONTAINER_STATUS_LAST=$(docker inspect $BACKUP_CONTAINER_NAME | jq -r '.[].State.Status') 
    if [ $CONTAINER_STATUS != $CONTAINER_STATUS_LAST ];
  then
    if [ $CONTAINER_STATUS_LAST == "paused" ]; then
      docker container unpause "$BACKUP_CONTAINER_NAME" >/dev/null 2>&1 
      echo "Container $BACKUP_CONTAINER_NAME unpause Success."
    fi
    if [ $CONTAINER_STATUS_LAST == "exited" ]; then
      docker container start "$BACKUP_CONTAINER_NAME" >/dev/null 2>&1 
      echo "Container $BACKUP_CONTAINER_NAME start Success."
    fi
  fi

  echo ""
  i=$((i + 1))
  STEPS=$(yq -r .backups.steps[$i] $YAML_FILE)
done

compress

END_TIME=$(date +%s)
EXECUTION_TIME=$((END_TIME - START_TIME))
echo -e "${GOLD}Backup finished: Execution time: $((EXECUTION_TIME / 60)) minute(s) and $((EXECUTION_TIME % 60)) second(s) Success.${RESET}"
echo ""
