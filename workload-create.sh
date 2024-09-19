#!/bin/sh                                                                                                                                                                                                                                                                                    

no_args="true"

GREEN='\033[0;92m'
RED='\033[0;31m'
NC='\033[0m'

print_info()
{
    printf "${GREEN}$1${NC}\n"
}

print_error()
{
    printf "${RED}$1${NC}\n"
}

usageFunction()
{
   print_error "Error - Invalid parameters passed to the script" 
   print_error "Usage: $0 -f <# of files to create> -d <directory depth> -s <file size> -i <# of iterations> -o <Output Directory>" 
   print_error "-f (required) specifies the number of files and sub-directories to create in each folder until the specified depth is reached"
   print_error "-d (required) specifies the depth of the sub-directories to create"
   print_error "-s (required) specifies the size of files in bytes to create"
   print_error "-i (required) specifies the number of iterations to run"
   print_error "-o (required) specifies the Output directory where the files are created. The script assumes the output directory exists and has permissions to write."
   exit 1
}
                                                                                                                                                                                                                                                                                             
function createfiles() 
{                                                                                                                                                                                                                                                                     
local dir="$1"                                                                                                                                                                                                                                                                               
local i=1                                                                                                                                                                                                                                                                                    
dircount=`echo ${dir} | grep -o "/"  | wc -l`                                                                                                                                                                                                                                                
                                                                                                                                                                                                                                                                                             
if [[ ${dircount} -le ${depth} ]]; then                                                                                                                                                                                                                                                             

  local count=1                                                                      
  while [[ ${count} -le ${files_count} ]]                                      
  do                                                                             
    #Create the specified number of files and directories                                     
    file_iden=`cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 6 | head -n1`                  
    dd if=/dev/urandom of=${dir}/fl-${file_iden}.bin bs=${file_size} count=1 status=none
                                                                                              
    dir_iden=`cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 6 | head -n1`                   
    if [[ ${dircount} -ne ${depth} ]]; then                                                                                                                                                                                                                                                         
        mkdir ${dir}/dir-${dir_iden}                                                                                                                                                                                                                                                         
    fi 
    count=$((count+1))                                                                    
  done

fi                                                                                                                                                                                                                                                                                           
}                                                                                                                                                                                                                                                                                            
                                                                                                                                                                                                                                                                                             
function iterate() {                                                                                                                                                                                                                                                                         
  local dir="$1"                                                                                                                                                                                                                                                                             
  for file in "$dir"/*; do                                                                                                                                                                                                                                                                   
    if [ -d "$file" ]; then                                                                                                                                                                                                                                                                  
      createfiles "${file}"                                                                                                                                                                                                                                                                  
      iterate "${file}"                                                                                                                                                                                                                                                                      
    fi                                                                                                                                                                                                                                                                                       
  done                                                                                                                                                                                                                                                                                       
}                                                                                                                                                                                                                                                                                            

#Parse the input parameters 
while getopts f:d:s:i:o: flag 
do
    case "${flag}"
        in
        f) files_count=${OPTARG}
           ;;
        d) depth=${OPTARG}
           ;;
        s) file_size=${OPTARG}
           ;;
        i) iteration=${OPTARG}
           ;;
        o) output_dir=${OPTARG}
           ;;
        *) usageFunction
           ;;
    esac
    no_args="false"
done

if [[ $no_args == "true" ]] 
then 
   usageFunction
fi

if [ ! -d ${output_dir} ]; then          
    print_error  "The target directory ${output_dir} does not exist. Unable to create files...exiting"
    exit 1                                                                                            
fi

ts=`date +%Y-%m-%d-%H.%M.%S`
if [ ! -d ${output_dir}/logs ]; then                                                         
   mkdir -p ${output_dir}/logs
fi                                                            
log_file_name=${output_dir}/logs/workload-create-$ts.log                                                            
print_info "Starting to create test workload...." >> ${log_file_name} 

itr=1                                                                                                                                                                                                                                                                                        
while [[ ${itr} -le ${iteration} ]]                                                                                                                                                                                                                                                                   
do                                                                                                                                                                                                                                                                                           
  print_info "========================================" >> ${log_file_name}  
  print_info "`date +%Y-%m-%d-%H:%M:%S` - Starting iteration : ${itr} " >> ${log_file_name}  
  directory=${output_dir}/iteration${itr}                                                                                                                                                                                                                                                            
  mkdir -p ${directory}                                                                                                                                                                                                                                                                      
  counter=1
  while [[ ${counter} -le ${files_count} ]]
  do 
    #Create the specified number of files and directories
    file_iden=`cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 6 | head -n1`          
    dd if=/dev/urandom of=${directory}/fl-${file_iden}.bin bs=${file_size} count=1 status=none

    dir_iden=`cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 6 | head -n1`           
    mkdir ${directory}/dir-${dir_iden}
    counter=$((counter+1))  
  done

iterate "$directory"                                                                                                                                                                                                                                                                         
print_info "`date +%Y-%m-%d-%H:%M:%S` - Completed iteration : ${itr} " >> ${log_file_name}  
                                                                                                                                                                                                                                                           
itr=$((itr+1))                                                                                                                                                                                                                                                                               
done
print_info "========================================" >> ${log_file_name}
print_info "Completed creating the test workload." >> ${log_file_name}
