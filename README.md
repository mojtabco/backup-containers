# backup-containers Script
This script provides a robust solution for automating Docker container backups, offering flexibility through a YAML configuration file. It ensures that only relevant data is backed up based on user preferences, making it efficient and customizable for various backup scenarios

This Bash script is designed to automate the backup process for Docker containers, including their images, volumes, and inspection data. It leverages several tools such as jq, yq, pv, and docker to perform its operations. Here's an analysis and explanation of the script

Main Logic
- Parses command-line arguments and reads configuration from a YAML file.
- After backing up, it compresses the backup directory if enabled and prints the execution summary.
- Iterates through each container specified in the YAML file, performing backups based on the provided options (inspection data, images, volumes).
- After backing up, it compresses the backup directory if enabled and prints the execution summary.

Features
- Backup Images: Saves the Docker images of specified containers.
- Backup Volumes: Archives the volumes attached to the containers.
- Inspect Data: Collects metadata and network information of the containers.
- Compression: Options to compress backup files for efficient storage.
- Customizable via YAML: Configuration file allows customization of backup paths, deletion of old backups, and other parameters

Requirements
- jq: is a lightweight and flexible command-line JSON processor.
- yq: yq is a lightweight command-line YAML File processor
- pv: To monitor progress during backup operations.

Installation
- Ensure all dependencies (jq, yq, pv) are installed on your system.
-   $ sudo apt install jq
-   $ sudo apt install yq
-   $ sudo apt install pv
- Save the script in a directory of your choice.
- Create a YAML configuration file (e.g., config.yml) following the format provided in the script comments or documentation.

Usage
- you need to set executable permissions for the .sh script files. You can do this by running the following command in the directory containing your .sh scripts:
-   $ chmod +x *.sh

- The script expects a YAML file as input, which contains configurations for the backup process, including paths, whether to compress backups, and specific steps for each container (such as whether to inspect data, backup images, or volumes).
- To run the script, ensure you have jq, yq, pv, and docker installed on your system. Then, execute the script with the path to your YAML configuration file as an argument.
-   $ ./backup-containers.sh config.yml

Configuration
Edit the backup-config.yml file to specify backup options, such as backup paths, whether to compress backups, and which containers to back up. Refer to the script for detailed instructions on configuring each option.
Functions YAML File
- BACKUP_PATH_MAIN: Specifies the main directory where backup files should be stored. If left empty, the script defaults to creating a backups directory within the current working directory.
- DELETE: Determines whether old backup files should be deleted after a successful backup operation. Setting this to true helps manage disk space by removing outdated backups.
- BACKUP_COMPRESS: Indicates whether backup files should be compressed. Setting this to false means backup files will not be compressed, potentially saving space but resulting in larger backup files.
- FORCE: When set to true, the script proceeds without asking for confirmation, allowing for automated execution without manual intervention.
  
Steps Section
- container_name: The name of the Docker container to be backed up.
- container_state: Determines the state of the container at the time of the backup. If stopped, it stops the container before the backup operation and starts the container after it is finished. Ditto for pause
-   INSPECT: Collects and saves inspection data and network information of a specified container.
-   IMAGE: Saves the Docker image of a specified container.
-   VOLUME: Collects and saves volume details of a specified container.

Example YAML Configuration

backups:

  BACKUP_PATH_MAIN: /mnt/drive
  
  BACKUP_COMPRESS: true
  
  DELETE: true
  
  FORCE: true
  
  steps:
  
    - step:
    
        container_name: mysql-server
        
        container_state: pause
        
        environment:
        
          INSPECT: yes
          
          IMAGE: no
          
          VOLUME: yes
          
    - step:
    
        container_name: zabbix-server-mysql
        
        container_state: pause
        
        environment:
        
          INSPECT: yes
          
          IMAGE: no
          
          VOLUME: yes
          
    - step:
    
        container_name: mynginx
        
        container_state: stop
        
        environment:
        
          INSPECT: yes
          
          IMAGE: yes
          
          VOLUME: yes
          

Developer: This script was developed by Mojtabco. For assistance or suggestions, please contact him or create an issue in the GitHub repository.

For access to the source code and reporting issues, visit the GitHub Repository: https://github.com/mojtabco/backup-containers
