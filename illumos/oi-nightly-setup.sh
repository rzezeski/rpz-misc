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
set -e

# ############################################################################
# Variables
# ############################################################################
CLOSED_BIN_URL="http://dlc.sun.com/osol/on/downloads/20100817/on-closed-bins.i386.tar.bz2"
CLOSED_BIN_ND_URL="http://dlc.sun.com/osol/on/downloads/20100817/on-closed-bins-nd.i386.tar.bz2"
CODE_DIR=/code
GATE=illumos-gate
GATE_DIR="$CODE_DIR/$GATE"
VERSION="1.0.0 2014-10-20T15:03:39 3025ea091e2f2f4836c5df8ab537bbd16cbf22ca"

# ############################################################################
# Functions
# ############################################################################
clone_illumos()
{
    info "Checking for $CODE_DIR dir"
    if [ ! -d $CODE_DIR ]; then
        sudo mkdir /code
        sudo chmod $LOGNAME:staff /code
        info "Directory /code created with ownership $LOGNAME:staff"
    fi

    info "Checking for copy of illumos-gate"
    if [ ! -d $GATE_DIR ]; then
        cd $CODE_DIR
        git clone git://github.com/illumos/illumos-gate.git
    fi
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
    echo "Checking for closed binaries"
    if [ ! -d closed/root_i386 ]; then
        [ ! -f on-closed-bins.i386.tar.bz2 ] && wget -c $CLOSED_BIN_URL
        tar xjvpf on-closed-bins.i386.tar.bz2
    fi

    if [ ! -d closed/root_i386-nd ]; then
        [ ! -f on-closed-bins-nd.i386.tar.bz2 ] && wget -c $CLOSED_BIN_ND_URL
        tar xjvpf on-closed-bins-nd.i386.tar.bz2
    fi
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
    info "Checking for GCC libs"
    if [ ! -h /usr/lib/libgcc_s.so.1 ]; then
        ln -s /opt/gcc/4.4.4/lib/libgcc_s.so.1 /usr/lib/libgcc_s.so.1
        info "Linked /usr/lib/libgcc_s.so.1 to /opt/gcc/4.4.4/lib/libgcc_s.so.1"
    fi

    if [ ! -h /usr/lib/libstdc++.so.6 ]; then
        ln -s /opt/gcc/4.4.4/lib/libstdc++.so.6 /usr/lib/libstdc++.so.6
        info "Linked /usr/lib/libstdc++.so.6 to /opt/gcc/4.4.4/lib/libstdc++.so.6"
    fi
}

#
# Replace /usr/bin/egrep with GNU egrep because nightly relies on the
# -q option.
#
link_gnu_egrep()
{
    info "Checking /usr/bin/egrep"
    if [ "$(readlink $(which egrep))" != "/usr/gnu/bin/egrep" ]; then
        sudo mv /usr/bin/egrep /usr/bin/egrep-old
        sudo ln -s /usr/gnu/bin/egrep /usr/bin/egrep
        info "Linked /usr/bin/egrep to /usr/gnu/bin/egrep"
    fi
}

#
# Copy and configure illumos.sh to be used with the nightly build.
# This step will not proceed if $GATE_DIR/illumos.sh already eixsts.
#
# This step assumes the CWD is $GATE_DIR.
#
setup_illumos_sh()
{
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
while getopts 'V(version)' opt
do
    case $opt in
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
