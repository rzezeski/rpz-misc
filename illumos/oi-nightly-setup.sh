#!/bin/sh
#
# A script to prepare OpenIndiana or OmniOS for a nightly build of
# illumos-gate. Intended for someone new to illumos who just wants to
# test a patch with minimum hassle.
#
# This script only needs run once. But it is also idempotent. You can
# run it many times safely.
#
# For issues with this script send an email to ryan@zinascii.com.
#
# For issues building illumos join the #illumos IRC channel.
#
# References:
#
# http://wiki.illumos.org/display/illumos/How+To+Build+illumos
# http://illumos.org/books/dev/workflow.html
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
COMMON_TAR_OPTS="--checkpoint=256 --checkpoint-action=dot"
GATE=illumos-gate
GATE_DIR="$CODE_DIR/$GATE"
VERSION="2015-09-10"

# ############################################################################
# Functions
# ############################################################################

#
# Print brief overview of build steps.
#
brief()
{
    printf "
*** Setup

$ ./oi-nightly-setup.sh

*** Build Nightly

$ cd /code/illumos-gate
$ /opt/onbld/bin/nightly illumos.sh || echo \"BUILD FAILED -- CHECK LOGS\"
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
# Determine the OS: set OS_NAME and OS_VSN. Fail if unsupported.
#
check_os()
{
    OS="unknown"

    if [ ! -e /etc/release ]; then
        echo "ERROR: couldn't determine OS" >&2
    fi

    if grep -i 'omnios' /etc/release > /dev/null; then
        OS_STR=$(sed -En -e 's/^ *//g' -e '1p' /etc/release)
        OS_NAME=$(echo $OS_STR | awk '{print $1}')
        OS_VSN=$(echo $OS_STR | awk '{print $3}')
    elif grep -i 'openindiana' /etc/release > /dev/null; then
        OS_STR=$(sed -En -e 's/^ *//g' -e '1p' /etc/release)
        OS_NAME=$(echo $OS_STR | awk '{print $1}')
        OS_VSN=$(echo $OS_STR | awk '{print $3}')
        if ! pkg publisher -H | grep hipster > /dev/null; then
            echo "ERROR: Must build on OI Hipster"
            echo "http://dlc.openindiana.org/isos/hipster/"
            exit 1
        fi
    else
        echo "ERROR: couldn't determine OS" 2>&2
        exit 1
    fi

    case $OS_NAME in
        OmniOS)
            # Remove the 'r' prefix.
            OS_VSN=$(echo $OS_VSN | tr -d r)

            case $OS_VSN in
                151014) ;;
                *)
                    echo "ERROR: unsupported version of \
OmniOS: $OS_VSN" 1>&2
                    exit 1
                    ;;
            esac
            ;;
        OpenIndiana)
            case $OS_VSN in
                oi_151.1.8) ;;
                *)
                    echo "ERROR: untested version of OI" 2>&1
                    exit 1
                    ;;
            esac
            ;;
        *)
            echo "ERROR: unsupported OS: $OS" 2>&2
            exit 1
            ;;
    esac
}

#
# Clone the illumos-gate (ON) source code.
#
clone_illumos()
{
    set -e
    info "Checking for $CODE_DIR dir"
    if [ ! -d $CODE_DIR ]; then
        sudo zfs create -o mountpoint=/code rpool/code
        sudo chown $LOGNAME:staff /code
        info "Filesystem rpool/code created, mounted under /code, \
with ownership $LOGNAME:staff"
    fi

    info "Checking for copy of illumos-gate"
    if [ ! -d $GATE_DIR ]; then
        cd $CODE_DIR
        git clone git://github.com/illumos/illumos-gate.git
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
#
# TODO add checksums
get_closed_bins()
{
    set -e
    echo "Checking for closed binaries"
    if [ ! -d closed/root_i386 ]; then
        [ ! -f on-closed-bins.i386.tar.bz2 ] && wget -c $CLOSED_BIN_URL
        gtar $COMMON_TAR_OPTS -xjpf on-closed-bins.i386.tar.bz2
    fi

    if [ ! -d closed/root_i386-nd ]; then
        [ ! -f on-closed-bins-nd.i386.tar.bz2 ] && wget -c $CLOSED_BIN_ND_URL
        gtar $COMMON_TAR_OPTS -xjpf on-closed-bins-nd.i386.tar.bz2
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
COMMON_PKGS="\
pkg:/archiver/gnu-tar \
pkg:/developer/astdev \
pkg:/developer/build/make \
pkg:/developer/build/onbld \
pkg:/developer/gnu-binutils \
pkg:/developer/java/jdk \
pkg:/developer/lexer/flex \
pkg:/developer/library/lint \
pkg:/developer/object-file \
pkg:/developer/parser/bison \
pkg:/developer/versioning/git \
pkg:/developer/versioning/mercurial \
pkg:/library/glib2 \
pkg:/library/libxml2 \
pkg:/library/libxslt \
pkg:/library/nspr/header-nspr \
pkg:/library/perl-5/xml-parser \
pkg:/library/python-2/python-extra-26
pkg:/library/security/trousers \
pkg:/system/header \
pkg:/system/library/dbus \
pkg:/system/library/install \
pkg:/system/library/libdbus \
pkg:/system/library/libdbus-glib \
pkg:/system/library/mozilla-nss/header-nss \
pkg:/system/management/snmp/net-snmp \
pkg:/text/gnu-gettext"

OMNI_PKGS="\
pkg:/developer/gcc44 \
pkg:/developer/sunstudio12.1 \
pkg:/runtime/perl \
pkg:/runtime/perl-64 \
pkg:/runtime/perl/module/sun-solaris \
pkg:/system/library/math"

OI_PKGS="\
pkg:/data/docbook \
pkg:/developer/illumos-gcc \
pkg:/developer/opensolaris/osnet \
pkg:/developer/sunstudio12u1 \
pkg:/print/cups \
pkg:/print/filter/ghostscript \
pkg:/runtime/perl-510 \
pkg:/runtime/perl-510/extra \
pkg:/runtime/perl-510/module/sun-solaris \
pkg:/system/library/math/header-math \
pkg:/system/management/product-registry \
pkg:/web/server/apache-22"

install_pkgs()
{
    info "Installing required packages"
    pkgs="$COMMON_PKGS"
    case $OS_NAME in
        OmniOS)
            pkgs="$pkgs $OMNI_PKGS" ;;
        OpenIndiana)
            pkgs="$pkgs $OI_PKGS" ;;
    esac
    sudo pkg install -v $pkgs
}

#
# Replace /usr/bin/egrep with GNU egrep because nightly relies on the
# -q and -E options.
#
link_gnu_egrep()
{
    set -e
    info "Checking /usr/bin/egrep"
    if [ "$(readlink $(which egrep))" != "/usr/gnu/bin/egrep" ]; then
        sudo mv /usr/bin/grep /usr/bin/grep-old
        sudo ln -s /usr/gnu/bin/grep /usr/bin/grep
        info "Linked /usr/bin/grep to /usr/gnu/bin/grep"
    fi
    set +e
}

#
# Need to link /opt/SUNWspro to /opt/sunstudio12.1 so that nightly can
# find dmake.
#
link_studio()
{
    set -e
    case $OS_NAME in
        OmniOS)
            if [ "$(readlink /opt/SUNWspro)" != "/opt/sunstudio12.1/" ]; then
                info "Linking /opt/SUNWspro to /opt/sunstudio12.1"
                sudo ln -s /opt/sunstudio12.1/ /opt/SUNWspro
            fi
    esac
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

This script is built specifically to setup OpenIndiana (aka OI) or
OmniOS for running a nightly build of illumos-gate. It is intended for
the beginner who wants to test a patch without going through the fuss
of manual setup. The instructions on the illumos wiki are followed as
closely as possible.

This script is idempotent; multiple executions should result in the
same end state. If something in the process fails midway you can
delete that partial change and re-run this script.

# ############################################################################
# Terminology
# ############################################################################

The jargon of illumos land...

* ON: OS/Network, this is the kernel, libc, network, system libs and
  system commands that make up the core of any Illumos distro.  This
  is what you are building when you build illumos-gate.

* Distribution: A distribution based on illumos-gate (ON).  These
  include OpenIndiana, SmartOS, and OmniOS, to name a few.

* nightly: The script the builds ON.

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

Run nightly(1ONBLD) to build ON.

$ cd /code/illumos-gate
$ /opt/onbld/bin/nightly illumos.sh || echo \"BUILD FAILED -- CHECK LOGS\"

Tail the nightly log to monitor progress.

$ tail -f log/nightly.log

When the build has finished the nightly log will be moved to a
timestamped dir and a mail_msg summary will be written.  If the build
returns a non-zero exit status you'll want to check both files.

$ grep '\*\*\*' log/log.<ts>/nightly.log
$ less log/log<ts>/mail_msg

If you fix something and need to rebuild but don't want to rebuild
everything then you can do an incremental build.

$ /opt/onbld/bin/nightly -i illumos.sh || echo \"BUILD FAILED -- CHECK LOGS\"

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
* http://illumos.org/books/dev/workflow.html

"

}

#
# Copy and configure illumos.sh to be used with the nightly build.
# This step will not proceed if $GATE_DIR/illumos.sh already eixsts.
#
# Assumes the CWD is $GATE_DIR.
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
        echo "unset __SUNC" >> illumos.sh
        echo "export CW_NO_SHADOW=1" >> illumos.sh
        echo "export ONLY_LINT_DEFS=-I\${SPRO_ROOT}/sunstudio12.1/prod/include/lint" >> illumos.sh

        # Disable IPP & SMB printing so the build doesn't fail.
        sed -i -r \
            -e "s:(export ENABLE_IPP_PRINTING=.*):#\1:" \
            -e "s:(export ENABLE_SMB_PRINTING=.*):#\1:" \
            illumos.sh

        case $OS_NAME in
            OmniOS)
                echo "Adding OmniOS specific customizations to illumos.sh"
                echo "export GCC_ROOT=/opt/gcc-4.4.4/" >> illumos.sh
                echo "export PERL_VERSION=5.16.1" >> illumos.sh
                echo "export PERL_PKGVERS=-5161" >> illumos.sh
                echo "export PERL_ARCH=i86pc-solaris-thread-multi-64int" >> illumos.sh
                echo "export ONNV_BUILDNUM=$OS_VSN" >> illumos.sh
                ;;
            OpenIndiana)
                echo "Adding OpenIndiana specific customizations to illumos.sh"
                # Make sure branch number for nightly packages
                # is greater than host system.
                echo "export ONNV_BUILDNUM=152.0.0" >> illumos.sh
                ;;
        esac

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

check_os
install_pkgs
clone_illumos
cd $GATE_DIR
get_closed_bins
setup_illumos_sh
link_gnu_egrep
link_studio
