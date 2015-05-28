#!/bin/bash
#set -x

###############################################################################
#                      S C R I P T    D E F I N I T I O N
################################################################################
#

#-------------------------------------------------------------------------------
# Revision History
#-------------------------------------------------------------------------------
# 20150317     Jason W. Plummer          Original: A generic script to output 
#                                        the vimdiff of two files as HTML
# 20150318     Jason W. Plummer          renamed from "compare.sh" to 
#                                        "compare-files.sh"
# 20150319     Jason W. Plummer          Added vimdiff version check

################################################################################
# DESCRIPTION
################################################################################
#

# NAME: compare-files.sh
# 
# This script performs a vimdiff of two files and creates HTML output
#
# OPTIONS:
#
# --infile1     - The fully qualified path and name of the first input file
#                 The file *MUST* be a text file.
#                 This argument is REQUIRED.
# --infile2     - The fully qualified path and name of the second input file
#                 The file *MUST* be a text file.
#                 This argument is REQUIRED.
# --outfile     - The fully qualified path and name of the file to save HTML output
#                 File extension of ".html" will be added if ".html" or ".htm"
#                 is not detected.
#                 This argument is REQUIRED.
# --colorscheme - A vim colorscheme override.  Defaults to 'desert'
#                 This argument is OPTIONAL.
#

################################################################################
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
USAGE="${USAGE}[ --infile1 <the path and name of input file 1 *REQUIRED*> ]${USAGE_ENDLINE}"
USAGE="${USAGE}[ --infile2 <the path and name of input file 2 *REQUIRED*> ]${USAGE_ENDLINE}"
USAGE="${USAGE}[ --outfile <the path and name of output file *REQUIRED*> ]${USAGE_ENDLINE}"
USAGE="${USAGE}[ --colorscheme <the vim colorscheme to use *OPTIONAL*> ]${USAGE_ENDLINE}"

###############################################################################
# VARIABLES
################################################################################
#

err_msg=""
exit_code=${SUCCESS}

default_colorscheme="desert"
vimdiff_minimum_version="7.3"

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
#
f__check_command() {
    return_code=${SUCCESS}
    my_command="${1}"

    if [ "${my_command}" != "" ]; then
        my_command_check=`unalias "${i}" 2> /dev/null ; which "${1}" 2> /dev/null`

        if [ "${my_command_check}" = "" ]; then
            return_code=${ERROR}
        else
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

    for command in awk bc diff egrep file sed vimdiff wc ; do
        unalias ${command} > /dev/null 2>&1
        f__check_command "${command}"

        if [ ${?} -ne ${SUCCESS} ]; then
            let exit_code=${exit_code}+1
        fi

    done

fi

# WHAT: Check vimdiff version for compatibility
# WHY:  We must have ${vimdiff_minimum_version} or higher for things to work
#       properly
#
if [ ${exit_code} -eq ${SUCCESS} ]; then
    vimdiff_version=`${my_vimdiff} --version 2>&1 | ${my_egrep} "^VIM" | ${my_awk} '{print $5}'`
    let version_check=`echo "${vimdiff_version}>=${vimdiff_minimum_version}" | ${my_bc}`

    if [ ${version_check} -eq 0 ]; then
        err_msg="Found vimdiff version ${vimdiff_version}, but version ${vimdiff_minimum_version} or higher is required"
        exit_code=${ERROR}
    fi

fi

# WHAT: Make sure we have necessary arguments
# WHY:  Cannot proceed otherwise
#
if [ ${exit_code} -eq ${SUCCESS} ]; then

    while (( "${#}" )); do
        key=`echo "${1}" | ${my_sed} -e 's?\`??g'`
        value=`echo "${2}" | ${my_sed} -e 's?\`??g'`

        case "${key}" in

            --infile1|--infile2|--outfile|--colorscheme)
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

    if [ "${infile1}" = "" -o "${infile2}" = "" -o "${outfile}" = "" ]; then
        err_msg="This script requires a minimum of three arguments"
        exit_code=${ERROR}
    fi

fi

# WHAT: Make sure argument 1 is sane
# WHY:  Cannot proceed otherwise
#
if [ ${exit_code} -eq ${SUCCESS} ]; then

    if [ ! -e "${infile1}" ]; then
        err_msg="Could not locate input file 1: \"${infile1}\""
        exit_code=${ERROR}
    else
        let is_text=`${my_file} "${infile1}" | ${my_egrep} -ic "text"`

        if [ ${is_text} -eq 0 ]; then
            err_msg="Input file 1 \"${infile1}\" is not a text file"
            exit_code=${ERROR}
        fi

    fi

fi

# WHAT: Make sure argument 2 is sane
# WHY:  Cannot proceed otherwise
#
if [ ${exit_code} -eq ${SUCCESS} ]; then

    if [ ! -e "${infile2}" ]; then
        err_msg="Could not locate input file 1: \"${infile2}\""
        exit_code=${ERROR}
    else
        let is_text=`${my_file} "${infile2}" | ${my_egrep} -ic "text"`

        if [ ${is_text} -eq 0 ]; then
            err_msg="Input file 2 \"${infile2}\" is not a text file"
            exit_code=${ERROR}
        fi

    fi

fi

# WHAT: Make sure argument 3 is sane
# WHY:  Cannot proceed otherwise
#
if [ ${exit_code} -eq ${SUCCESS} ]; then
    is_html=`echo "${outfile}" | ${my_egrep} -ic "\.htm$|\.html$"`

    if [ ${is_html} -eq 0 ]; then
        outfile="${outfile}.html"
    fi


fi

# WHAT: Define colorscheme
# WHY:  Needed later
#
if [ ${exit_code} -eq ${SUCCESS} ]; then

    if [ "${colorscheme}" = "" ]; then
        colorscheme="${default_colorscheme}"
    fi

fi

# WHAT: Create the HTML vimdiff output
# WHY:  Asked to
#
if [ ${exit_code} -eq ${SUCCESS} ]; then

    if [ -e "${outfile}" ]; then

        while [ "${answer}" = "" ] ;do
            echo
            read -p "${STDOUT_OFFSET}WARNING:  Filename \"${outfile}\" exists ... overwrite? " answer
            answer=`echo "${answer}" | ${my_sed} -e 's?\`??g'`
 
            case ${answer} in
 
                [Nn][Oo]|[Nn])
                    echo
                    echo "Operation cancelled by user"
                    exit ${SUCCESS}
                ;;
 
                [Yy]es|[Yy])
                    echo
                    echo "${STDOUT_OFFSET}* * * Local file \"${outfile}\" WILL BE REMOVED * * *"
                    echo
                    read -p "${STDOUT_OFFSET}Press <ENTER> to continue or <CTRL>-C to quit ... " input
                    rm -f "${outfile}"
                ;;
 
            esac
 
        done

    fi

    let is_diff=`${my_diff} "${infile1}" "${infile2}" | ${my_wc} -l | ${my_awk} '{print $1}'`

    if [ ${is_diff} -gt 0 ]; then
        echo "${STDOUT_OFFSET}INFO:  Differences were found"

        if [ -e "${outfile}" ]; then
             echo
    
    
        fi

        echo "${STDOUT_OFFSET}${STDOUT_OFFSET}    Creating HTML output file \"${outfile}\" with color coded differences"
        eval "${my_vimdiff} \"${infile1}\" \"${infile2}\" -c ':colorscheme ${colorscheme}' +TOhtml '+w! ${outfile}' '+qall!' > /dev/null 2>&1"

        if [ ${?} -eq ${SUCCESS} ]; then
            echo "SUCCESS"
        else
            err_msg="vimdiff failed"
            exit_code=${ERROR}
        fi

    else
        echo "${STDOUT_OFFSET}INFO:  NO difference were found"
        echo "${STDOUT_OFFSET}${STDOUT_OFFSET}   Creating HTML output file \"${outfile}\""
        echo "<html><body>No differences were found</body></html>" > "${outfile}"
    fi

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
    
