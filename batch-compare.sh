#!/bin/bash
#set -x

###############################################################################
#                      S C R I P T    D E F I N I T I O N
################################################################################
#

#-------------------------------------------------------------------------------
# Revision History
#-------------------------------------------------------------------------------
# 20150318     Jason W. Plummer          Original: A script to perform batch
#                                        comparisons of files using 
#                                        confluence.sh and compare.sh
# 20150319     Jason W. Plummer          Added check to ignore lines starting 
#                                        with '#' in the input data file

################################################################################
# DESCRIPTION
################################################################################
#

# NAME: batch-compare.sh
# 
# This script performs a vimdiff of two files and creates HTML output
#
# OPTIONS:
#
# --datafile    - The fully qualified path and name of a CSV formatted input
#                 file, the data of which is in the form:
#
#                     <input file 1>,<confluence page ID 1>,<input file 2>,<confluence page ID 2>,<output file>,<confluence page ID 3>
#
#                 WHERE:
#
#                 <input file 1> and <input file 2> and pulled from confluence 
#                 page IDs 1 and 2, respectively and the HTML output file that
#                 captures the side by side vimdiff output is pushed to 
#                 confluence page ID 3.
#                 This argument is REQUIRED.
# --username    - The confluence username to use.
#                 This argument is REQUIRED.
#

###############################################################################
# CONSTANTS
################################################################################
#

PATH=/bin:/usr/bin:/usr/local/bin:/sbin:/usr/sbin:/usr/local/sbin
TERM=vt100
export TERM PATH

SUCCESS=0
ERROR=1
STDOUT_OFFSET="    "

SCRIPT_NAME="${0}"

USAGE_ENDLINE="\n${STDOUT_OFFSET}${STDOUT_OFFSET}${STDOUT_OFFSET}${STDOUT_OFFSET}"
USAGE="${SCRIPT_NAME}${USAGE_ENDLINE}"
USAGE="${USAGE}[ --datafile <the name of a properly formatted CSV file *REQUIRED*> ]${USAGE_ENDLINE}"
USAGE="${USAGE}[ --username <the confluence username to use for authentication *REQUIRED*> ]${USAGE_ENDLINE}"

###############################################################################
# VARIABLES
################################################################################
#

err_msg=""
exit_code=${SUCCESS}

################################################################################
# SUBROUTINES
################################################################################
#

# WHAT: Subroutine f__check_command
# WHY:  This subroutine checks the contents of lexically scoped ${1} and then
#       searches ${PATH} for the command.  If found, a variable of the form
#       my_${1} is created.
# NOTE: Lexically scoped ${1} should not be null, otherwise the command for
#       which we are searching is not present via the defined ${PATH} and we
#       should complain

f__check_command() {
    return_code=${SUCCESS}
    my_command="${1}"

    if [ "${my_command}" != "" ]; then
        my_command_check=`unalias "${my_command}" 2> /dev/null ; which "${1}" 2> /dev/null`

        if [ "${my_command_check}" = "" ]; then
            return_code=${ERROR}
        else
            my_command=`echo "${my_command}" | sed -e 's?\-?_?g'` 
            eval my_${my_command}="${my_command_check}"
        fi

    else
        echo "${STDOUT_OFFSET}ERROR:  No command was specified"
        return_code=${ERROR}
    fi

    return ${return_code}
}

#-------------------------------------------------------------------------------

################################################################################
# MAIN
################################################################################
#

# WHAT: Make sure we have some useful commands
# WHY:  Cannot proceed otherwise
#
if [ ${exit_code} -eq ${SUCCESS} ]; then

    for command in awk compare-files confluence egrep file sed strings stty ; do
        unalias ${command} > /dev/null 2>&1
        f__check_command "${command}"

        if [ ${?} -ne ${SUCCESS} ]; then
            let exit_code=${exit_code}+1
        fi

    done

fi

# WHAT: Make sure we have necessary arguments
# WHY:  Cannot proceed otherwise
#
if [ ${exit_code} -eq ${SUCCESS} ]; then

    while (( "${#}" )); do
        key=`echo "${1}" | ${my_sed} -e 's?\`??g'`
        value=`echo "${2}" | ${my_sed} -e 's?\`??g'`

        case "${key}" in

            --datafile|--username|--debug)
                key=`echo "${key}" | ${my_sed} -e 's?^--??g'`

                if [ "${value}" != "" ]; then
                    eval ${key}="${value}"
                    shift
                    shift
                else
                    echo "${STDOUT_OFFSET}ERROR:  No value assignment can be made for command line argument \"--${key}\""
                    exit_code=${ERROR}
                    shift
                fi

            ;;

            *)
                # We bail immediately on unknown or malformed inputs
                echo "${STDOUT_OFFSET}ERROR:  Unknown command line argument ... exiting"
                exit
            ;;

        esac

    done

    if [ "${datafile}" = "" -o "${username}" = "" ]; then
        err_msg="Not enough command line arguments detected"
        exit_code=${ERROR}
    fi

fi

# WHAT: Make sure we have a datafile
# WHY:  Cannot continue otherwise
#
if [ ${exit_code} -eq ${SUCCESS} ]; then

    if [ ! -e "${datafile}" ]; then
        err_msg="Could not locate CSV file \"${datafile}\""
        exit_code=${ERROR}
    else
        let is_text=`${my_file} "${datafile}" | ${my_egrep} -c "text"`

        if [ ${is_text} -gt 0 ]; then
            let is_csv=`${my_egrep} -c "," "${datafile}"`

            if [ ${is_csv} -eq 0 ]; then
                err_msg="Data input file \"${datafile}\" is not a CSV file"
                exit_code=${ERROR}
            fi

        else
            err_msg="Data input file \"${datafile}\" is not a TEXT file"
            exit_code=${ERROR}
        fi

    fi

fi

# WHAT: Request a password
# WHY:  Needed later
#
if [ ${exit_code} -eq ${SUCCESS} ]; then

    while [ "${password}" = "" ]; do
        ${my_stty} -echo
        read -p "    Please enter the password for username: \"${username}\": " password
        password=`echo "${password}" | ${my_sed} -e 's?\`??g'`
        ${my_stty} echo

        if [ "${password}" = "" ]; then
            echo
            echo "    ERROR:  Password cannot be blank"
            echo
        fi

    done

fi

# WHAT: Process the CSV file
# WHY:  The reason we are here
#
if [ ${exit_code} -eq ${SUCCESS} ]; then

    for line in `${my_awk} '{print $0}' "${datafile}"` ; do
        line=`echo "${line}" | ${my_egrep} -v "^#"`

        if [ "${line}" != "" ]; then
            line=`echo "${line}" | ${my_strings} | ${my_sed} -e 's?\ ??g' -e 's?\r??g' -e 's?\t??g'`
            infile1=`echo "${line}" | ${my_awk} -F',' '{print $1}'`
            pageid1=`echo "${line}" | ${my_awk} -F',' '{print $2}'`
            infile2=`echo "${line}" | ${my_awk} -F',' '{print $3}'`
            pageid2=`echo "${line}" | ${my_awk} -F',' '{print $4}'`
            outfile=`echo "${line}" | ${my_awk} -F',' '{print $5}'`
            pageid3=`echo "${line}" | ${my_awk} -F',' '{print $6}'`
  
            if [ "${infile1}" != "" -a "${pageid1}" != "" -a "${infile2}" != "" -a "${pageid2}" != "" -a "${outfile}" != "" -a "${pageid3}" != "" ]; then

                if [ ! -e "${infile1}" ]; then
                    echo
                    echo "${STDOUT_OFFSET}Downloading input file 1 \"${infile1}\" from confluence ..."
                    ${my_stty} -echo

                    if [ "${debug}" = "" ]; then
                        ${my_confluence} --action pull --pageid "${pageid1}" --filename "${infile1}" --username "${username}" --password "${password}"
                    else
                        ${my_confluence} --action pull --pageid "${pageid1}" --filename "${infile1}" --username "${username}" --password "${password}" --debug "${debug}"
                    fi

                    ${my_stty} echo

                    if [ ! -e "${infile1}" ]; then
                        echo "${STDOUT_OFFSET}ERROR:  Failed to download input file \"${infile1}\" from confluence"
                    fi

                fi

                if [ ! -e "${infile2}" ]; then
                    echo "${STDOUT_OFFSET}Downloading input file 2 \"${infile1}\" from confluence ..."
                    ${my_stty} -echo

                    if [ "${debug}" = "" ]; then
                        ${my_confluence} --action pull --pageid "${pageid2}" --filename "${infile2}" --username "${username}" --password "${password}"
                    else
                        ${my_confluence} --action pull --pageid "${pageid2}" --filename "${infile2}" --username "${username}" --password "${password}" --debug "${debug}"
                    fi

                    ${my_stty} echo

                    if [ ! -e "${infile2}" ]; then
                        echo "${STDOUT_OFFSET}ERROR:  Failed to download input file \"${infile2}\" from confluence"
                    fi

                fi

                if [ -e "${infile1}" -a -e "${infile2}" ]; then
                    ${my_compare_files} --infile1 "${infile1}" --infile2 "${infile2}" --outfile "${outfile}"

                    if [ -e "${outfile}.html" ]; then
                        ${my_stty} -echo

                        if [ "${debug}" = "" ]; then
                            ${my_confluence} --action push --pageid "${pageid3}" --filename "${outfile}.html" --username "${username}" --password "${password}"
                        else
                            ${my_confluence} --action push --pageid "${pageid3}" --filename "${outfile}.html" --username "${username}" --password "${password}" --debug "${debug}"
                        fi

                        ${my_stty} echo
                    fi

                fi
    
            fi

            read -p "Press <ENTER> to continue"
        fi

    done

fi

# WHAT: Complain if necessary and exit
# WHY:  Success or failure, either way we are through
#
if [ ${exit_code} -ne ${SUCCESS} ]; then

    if [ "${err_msg}" != "" ]; then
        echo -ne "\n\n"
        echo -ne "${STDOUT_OFFSET}ERROR:  ${err_msg} ... processing halted\n"
        echo
    fi

    echo
    echo -ne "${STDOUT_OFFSET}USAGE:  ${USAGE}\n"
    echo
fi

exit ${exit_code}
