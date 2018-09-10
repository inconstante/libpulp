#!/bin/sh

LIBNAME="libdummy.so"

function schedule_retry
{
    $0 -r 10 &
}

function save_retry
{
    echo $1 >> /tmp/patch_retries.ulp
}

function patch_me
{
    echo "** PATCHING PID $1"
    /usr/bin/ulp_trigger $1 /tmp/metadata1.ulp
    if [ $? = 1 ];
    then
	save_retry $1
    fi
}

function check_me
{
    echo "** LIVEPATCH CHECKER: CHECKING PID $1"
    /usr/bin/ulp_check $1 /tmp/metadata1.ulp
    if [ $? = 0 ];
    then
        echo "- NOT PATCHED!"
    else
        echo "- PATCHED!"
    fi
}

function patch_targets
{
    rm -f /tmp/patching.ulp
    rm -f /tmp/patch_retries.ulp
    cd /proc
    for D in *;
    do
	if [ -d ${D} ];
        then
	    if [[ ${D} =~ [0-9] ]];
	    then
		pmap ${D} | grep -q ${LIBNAME}
		if [ $? = 0 ];
		then
		    echo ${D} >> /tmp/patching.ulp
		fi
	    fi
	fi
    done
}

function apply_patch
{
    cat /tmp/patching.ulp | while read pid
    do
        check_me ${pid}
        sleep 1
        patch_me ${pid}
        sleep 1
        check_me ${pid}
    done
}

function retry_patch
{
    if [ ! -f /tmp/patch_retries.ulp ]; then
        echo "No patching retries left."
	return
    fi

    mv /tmp/patch_retries.ulp /tmp/patching.ulp
    sleep 1
    apply_patch
}

if [[ $# -gt 0 && $1 = "-r" ]];
then
    if [[ ! $2 ]];
    then
	timer=60
    else
	timer=$2
    fi
    echo "Retrying to patch in $timer secs."
    sleep $timer
    retry_patch
else
    patch_targets
    apply_patch
fi

if [ -f /tmp/patch_retries.ulp ]; then
    schedule_retry
fi
