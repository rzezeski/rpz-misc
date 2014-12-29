#!/bin/sh
#
# A script to prepare OpenIndiana for a nightly build of illumos-gate.
# For best results use the latest stable OI release.  This is intended
# for someone new to Illumos who just wants to test a patch without
# the hassel of learning the intricacies of building Illumos.
#
# This script should only need to be run once but it is also built to
# be idempotent, meaning you should be able to run it as many times as
# you want with no ill effect.
#
# If you run into any issues then please share them in #illumos IRC
# channel or on the illumos-discuss mailing list.
#
# References:
#
# http://wiki.illumos.org/display/illumos/How+To+Build+illumos
# https://us-east.manta.joyent.com/rmustacc/public/iondg/workflow.html
#
# Thanks:
#
# Piotr Jasiukajtis
# Robert Mustacchi

# ############################################################################
# Variables
# ############################################################################
CLOSED_BIN_URL="https://download.joyent.com/pub/build/illumos/on-closed-bins.i386.tar.bz2"
CLOSED_BIN_ND_URL="https://download.joyent.com/pub/build/illumos/on-closed-bins-nd.i386.tar.bz2"
CODE_DIR=/code
GATE=illumos-gate
GATE_DIR="$CODE_DIR/$GATE"
VERSION="1.0.3 2014-12-28T22:47:07 ea134d9804bfcf14b770cc2b57fac5a3cf47e262"

# ############################################################################
# Functions
# ############################################################################

#
# Print brief overview of build steps.
brief()
{
    printf "
*** Setup

$ ./oi-nightly-setup.sh

*** Build Nightly

$ cd /code/illumos-gate
$ ./nightly.sh illumos.sh || echo \"BUILD FAILED -- CHECK LOGS\"
$ tail -f log/nightly.log

*** Check Logs

$ grep '***' log/log.<ts>/nightly.log
$ less log/log<ts>/mail_msg

*** ON Update & Boot into Nightly BE

$ sudo ./usr/src/tools/scripts/onu -t nightly -d packages/i386/nightly
$ beadm list
$ sudo reboot

*** Return to Previous BE

$ sudo beadm activate openindiana
$ sudo reboot

*** Destory Nightly BE if Rebuilding

$ sudo beadm destroy nightly

"
}

#
# Clone the illumos-gate (ON) source code.
#
clone_illumos()
{
    set -e
    info "Checking for $CODE_DIR dir"
    if [ ! -d $CODE_DIR ]; then
        sudo mkdir /code
        sudo chown $LOGNAME:staff /code
        info "Directory /code created with ownership $LOGNAME:staff"
    fi

    info "Checking for copy of illumos-gate"
    if [ ! -d $GATE_DIR ]; then
        cd $CODE_DIR
        git clone git://github.com/illumos/illumos-gate.git
    fi
    set +e
}

#
# Copy files into the appropriate place.  Assumes it's in $GATE_DIR.
#
copy_files()
{
    set -e
    info "Copying nightly.sh"
    if [ ! -f nightly.sh ]; then
        cp ./usr/src/tools/scripts/nightly.sh .
        info "Copied nightly.sh"
    fi

    info "Check execute bit on nightly.sh"
    if [ ! -x nightly.sh ]; then
        chmod +x nightly.sh
        info "Granted execute bit on nightly.sh"
    fi
    set +e
}

#
# Get closed binaries needed for building nightly.
#
# This assumes that if the dirs are there that the contents are
# correct.  If anything goes wrong just rm -rf the entire closed dir
# and re-run the script.  Same goes for the tar archives.
#
get_closed_bins()
{
    set -e
    echo "Checking for closed binaries"
    if [ ! -d closed/root_i386 ]; then
        [ ! -f on-closed-bins.i386.tar.bz2 ] && wget -c $CLOSED_BIN_URL
        tar xjvpf on-closed-bins.i386.tar.bz2
    fi

    if [ ! -d closed/root_i386-nd ]; then
        [ ! -f on-closed-bins-nd.i386.tar.bz2 ] && wget -c $CLOSED_BIN_ND_URL
        tar xjvpf on-closed-bins-nd.i386.tar.bz2
    fi
    set +e
}

#
# Print INFO message to stdout.
#
info()
{
    echo "INFO: $1"
}

#
# Install packages necessary to perform the nightly build.
#
install_pkgs()
{
    info "Installing required packages"
    sudo pkg install -v \
         pkg:/data/docbook \
         pkg:/developer/astdev \
         pkg:/developer/build/make \
         pkg:/developer/build/onbld \
         pkg:/developer/illumos-gcc \
         pkg:/developer/gnu-binutils \
         pkg:/developer/opensolaris/osnet \
         pkg:/developer/java/jdk \
         pkg:/developer/lexer/flex \
         pkg:/developer/object-file \
         pkg:/developer/parser/bison \
         pkg:/developer/versioning/mercurial \
         pkg:/developer/versioning/git \
         pkg:/developer/library/lint \
         pkg:/library/glib2 \
         pkg:/library/libxml2 \
         pkg:/library/libxslt \
         pkg:/library/nspr/header-nspr \
         pkg:/library/perl-5/xml-parser \
         pkg:/library/security/trousers \
         pkg:/print/cups \
         pkg:/print/filter/ghostscript \
         pkg:/runtime/perl-510 \
         pkg:/runtime/perl-510/extra \
         pkg:/runtime/perl-510/module/sun-solaris \
         pkg:/system/library/math/header-math \
         pkg:/system/library/install \
         pkg:/system/library/dbus \
         pkg:/system/library/libdbus \
         pkg:/system/library/libdbus-glib \
         pkg:/system/library/mozilla-nss/header-nss \
         pkg:/system/header \
         pkg:/system/management/product-registry \
         pkg:/system/management/snmp/net-snmp \
         pkg:/text/gnu-gettext \
         pkg:/library/python-2/python-extra-26 \
         pkg:/web/server/apache-13 \
         pkg:/developer/sunstudio12u1
}

#
# Link GCC libs required for some of the libraries.
#
link_gcc_libs()
{
    set -e
    info "Checking for GCC libs"
    if [ ! -h /usr/lib/libgcc_s.so.1 ]; then
        sudo ln -s /opt/gcc/4.4.4/lib/amd64/libgcc_s.so.1 /usr/lib/amd64/libgcc_s.so.1
        sudo ln -s /opt/gcc/4.4.4/lib/libgcc_s.so.1 /usr/lib/libgcc_s.so.1
        info "Linked /usr/lib/libgcc_s.so.1 to /opt/gcc/4.4.4/lib/libgcc_s.so.1"
    fi

    if [ ! -h /usr/lib/libstdc++.so.6 ]; then
        sudo ln -s /opt/gcc/4.4.4/lib/amd64/libstdc++.so.6 /usr/lib/amd64/libstdc++.so.6
        sudo ln -s /opt/gcc/4.4.4/lib/libstdc++.so.6 /usr/lib/libstdc++.so.6
        info "Linked /usr/lib/libstdc++.so.6 to /opt/gcc/4.4.4/lib/libstdc++.so.6"
    fi
    set +e
}

#
# Replace /usr/bin/egrep with GNU egrep because nightly relies on the
# -q option.
#
link_gnu_egrep()
{
    set -e
    info "Checking /usr/bin/egrep"
    if [ "$(readlink $(which egrep))" != "/usr/gnu/bin/egrep" ]; then
        sudo mv /usr/bin/egrep /usr/bin/egrep-old
        sudo ln -s /usr/gnu/bin/egrep /usr/bin/egrep
        info "Linked /usr/bin/egrep to /usr/gnu/bin/egrep"
    fi
    set +e
}

#
# Display build instructions.
#
print_instructions()
{
    printf "

# ############################################################################
# Summary
# ############################################################################

This script is built specifically to setup a _fresh_ install of
OpenIndiana (aka OI) for running a nightly build of illumos-gate.  It
is intended for the _beginner_ who wants to test a patch without going
through the fuss of manual setup.  The instructions on the Illumos
wiki are followed as closely as possible.  This script has only been
tested on OI 151a8 and may not work under other circumstances.

This script is idempotent; you can re-run it without ill effect.  If
something in the process fails midway you should be able to revert or
delete that partial change and re-run this script.

# ############################################################################
# Terminology
# ############################################################################

The jargon of Illumos land...

* ON: OS/Network, this is the kernel, libc, network, system libs and
  system commands that make up the core of any Illumos distro.  This
  is what you are building when you build illumos-gate.

* Distribution: A distribution based on illumos-gate (ON).  These
  include OpenIndiana, SmartOS, and OmniOS, to name a few.

* nightly: This is nightly.sh, the script the builds ON.

* ONU: ON Update, this is a script that creates a new BE from the ON
  build.

* BE: Boot Environment, this is the environment from which the entire
  operating system runs.  It's also linked to IPS which is the Image
  Packaging System.  As a beginner, the main thing to understand is
  that testing kernel/libc changes require you to boot into a new BE
  which is created by the onu script.

* osnet consolidation/incorporation: The list of packages that make up
  ON. ONU tells IPS to update this consolidation package which causes
  all the appropriate packages to upgrade in lock step so you can test
  your new ON.

* IPS or Image Packaging System - The program that manages the
  packages.

* beadm: BE admin, used to administrate BEs.

# ############################################################################
# Build Instructions
# ############################################################################

*** 1. Setup

The first step is the initial setup which this script does on your
behalf.  Once this script has run successfully, the entire way
through, there should be no reason to re-run it unless you decide to
delete or change something required to perform the nightly build.

$ ./oi-nightly-setup.sh

*** 2. Modify

Before building nightly you'll want to make your modifications.
However, you could build ON first, then make your changes, and then
perform an incremental build (discussed in section 3).

*** 3. Build

Run the nightly.sh script to build ON.

$ cd /code/illumos-gate
$ ./nightly.sh illumos.sh || echo \"BUILD FAILED -- CHECK LOGS\"

Tail the nightly log to monitor progress.

$ tail -f log/nightly.log

When the build has finished the nightly log will be moved to a
timestamped dir and a mail_msg summary will be written.  If the build
returns a non-zero exit status you'll want to check both files.

$ grep '\*\*\*' log/log.<ts>/nightly.log
$ less log/log<ts>/mail_msg

If you fix something and need to rebuild but don't want to rebuild
everything then you can do an incremental build.

$ ./nightly.sh -i illumos.sh || echo \"BUILD FAILED -- CHECK LOGS\"

You can also cd into the subdir and build things directly, but at that
point you are becoming more advanced and should see the further
reading section.

*** 4. Boot nightly BE

Once you have a successful build the safest way to test your change is
to boot into a new BE that includes your changes.  You don't always
need to do this, e.g. say you only change a command.

https://us-east.manta.joyent.com/rmustacc/public/iondg/workflow.html#testing

Use the onu script to create the nightly BE with your freshly built
packages.

$ sudo ./usr/src/tools/scripts/onu -t nightly -d packages/i386/nightly

ONU creates the nightly BE, updates the osnet-incorporation, and then
marks the new BE as active.

$ beadm list

At that point you just need to reboot and test your change.

$ sudo reboot

When you are done testing you can get back into the previous BE by
using beadm to mark it active and reboot again.

$ sudo beadm activate openindiana
$ sudo reboot

# ############################################################################
# Further Reading
# ############################################################################

* http://wiki.illumos.org/display/illumos/How+To+Build+illumos
* https://us-east.manta.joyent.com/rmustacc/public/iondg/workflow.html

"

}

#
# Copy and configure illumos.sh to be used with the nightly build.
# This step will not proceed if $GATE_DIR/illumos.sh already eixsts.
#
# This step assumes the CWD is $GATE_DIR.
#
setup_illumos_sh()
{
    set -e
    info "Checking for illumos.sh"
    if [ ! -f "illumos.sh" ]; then
        cp usr/src/tools/env/illumos.sh .
        info "Copied illumos.sh from usr/src/tools/env/illumos.sh"
        sed -i -r \
            -e "s:export GATE.*:export GATE=$GATE:" \
            -e "s:export CODEMGR_WS.*:export CODEMGR_WS=$GATE_DIR:" \
            -e 's:export SPRO_ROOT.*:export SPRO_ROOT=/opt:' \
            -e 's:export SPRO_VROOT.*:export SPRO_VROOT=/opt/sunstudio12.1:' \
            illumos.sh

        # Use gcc for compilation
        echo "export __GNUC=''" >> illumos.sh
        echo "export CW_NO_SHADOW=1" >> illumos.sh

        # Make sure branch number for nightly packages is greater than
        # host system.
        echo "export ONNV_BUILDNUM=152.0.0" >> illumos.sh

        info "Configured illumos.sh"
    fi
    set +e
}

#
# Display usage statement.
#
usage()
{
    printf "Usage: ./oi-nightly-setup.sh [-Vhp]

-b, --brief
        Print brief build instructions.

-V, --version
        Print the version string.

-h, --help
        Print the usage statement.

-p, --print
        Print the build instructions.

"
}

#
# Display the version string.
#
version()
{
    echo $VERSION
    exit 0
}

# ############################################################################
# Main
# ############################################################################
while getopts 'V(version)h(help)p(print)b(brief)' opt
do
    case $opt in
        b)
            brief
            exit 0
            ;;
        h)
            usage
            exit 0
            ;;
        p)
            print_instructions
            exit 0
            ;;
        V)
            version
            ;;
    esac
done

shift $((OPTIND -1))

install_pkgs
clone_illumos
cd $GATE_DIR
get_closed_bins
setup_illumos_sh
link_gnu_egrep
link_gcc_libs
copy_files
