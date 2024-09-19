#!/bin/sh                                                                                                                                                                                                                                                                                    

no_args="true"

BLUE='\033[0;94m'
GREEN='\033[0;92m'
YELLOW='\033[0;93m'
RED='\033[0;31m'
NC='\033[0m'


print_heading()
{
    printf "${BLUE}$1${NC}\n" 
}

print_info()
{
    printf "${GREEN}$1${NC}\n" 
}

print_warning()
{
    printf "${YELLOW}$1${NC}\n" 
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
while getopts 'f:d:s:i:o:' opt; do 
    case ${opt} in
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

if [[ $no_args == "true" || -z ${files_count} || -z ${depth} || -z ${file_size} || -z ${iteration} || -z ${output_dir} ]]; then 
   usageFunction
fi

if [ ! -d ${output_dir} ]; then
    print_error  "The target directory ${output_dir} does not exist. Unable to update files...exiting"
    exit 1
fi

ts=`date +%Y-%m-%d-%H.%M.%S`                                                
if [ ! -d ${output_dir}/logs ]; then                                                    
   mkdir -p ${output_dir}/logs                                                          
fi                                                                                      
log_file_name=${output_dir}/logs/apply-change-$ts.log                   
print_info "`date +%Y-%m-%d-%H:%M:%S` - Starting to apply change..." >> ${log_file_name}

itr=1
while [[ ${itr} -le ${iteration} ]]                                                                                                                                                                                                                                                                   
do   

  print_info "===========================================" >> ${log_file_name}    
  print_info "`date +%Y-%m-%d-%H:%M:%S` - Applying Change - Iteration : ${itr}" >> ${log_file_name} 
  rm -rf ${output_dir}/lost+found
  oldest_dir_name=`ls -trd ${output_dir}/iteration*/ | head -n1`
  if [[ -z ${oldest_dir_name} ]]; then                                       
    print_error "oldest dir name is null .. something went wrong" >> ${log_file_name} 
    exit 1 
  fi
  print_info "deleting oldest directory : ${oldest_dir_name}" >> ${log_file_name} 
  rm -rf ${oldest_dir_name}

  latest_dir_name=`ls -td ${output_dir}/iteration*/ | head -n1 |awk -F '/' '{print $3}'`
  print_info "latest dir name is : ${latest_dir_name}" >> ${log_file_name} 

  if [[ -z ${latest_dir_name} ]]; then
     print_error "latest dir name is null .. something went wrong" >> ${log_file_name} 
     exit 1 
  else
     latest_dir_num=`ls -td ${output_dir}/iteration*/ | head -1 |awk -F '/' '{print $3}' | grep -Eo "[0-9]+"`
     if [[ -z ${latest_dir_num=} ]]; then                          
       print_error "latest dir number is null .. something went wrong" >> ${log_file_name} 
       exit 1 
     else  
       print_info "Latest directory sequence number is : $latest_dir_num" >> ${log_file_name} 
       latest_dir_num=$((latest_dir_num+1))
       directory=${output_dir}/iteration${latest_dir_num}                                                                                                                                                                                                                                                            
       mkdir -p ${directory}                                                                                                                                                                                                                                                                      
       print_info "Created new directory : ${directory}" >> ${log_file_name} 
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
     fi                                                                                                                                                                                                                                                                                         
     iterate "$directory"                                                                                                                                                                                                                                                                         
     print_info "`date +%Y-%m-%d-%H:%M:%S` - Completed populating files and directories in : ${directory}" >> ${log_file_name}                                                                                                                                                                                                                                                    
  fi         

itr=$((itr+1))                                                                                                                                                                                                                                                                               

done
print_info "===========================================" >> ${log_file_name}
total_file_count=`ls -lR ${output_dir} |grep ^- |wc -l`
total_dir_count=`ls -lR ${output_dir} |grep ^d |wc -l`
print_info "Total Directory Count in ${output_dir} : $total_dir_count" >> ${log_file_name}   
print_info "Total File Count in ${output_dir} : $total_file_count" >> ${log_file_name}   

print_info "`date +%Y-%m-%d-%H:%M:%S` - Completed applying data change." >> ${log_file_name} 
