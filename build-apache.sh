#!/bin/bash
if [ `id -u` -eq 0 ]; then
  echo "ERROR: don't run this script as root"
  exit 1
fi
name="httpd"
tmpdir=`mktemp -d`
rdir=`dirname $0`
dir=`realpath $rdir`
build_for_centos=false
centos_release=6
centos_arch="i386"

# Get Apache version info
cd $tmpdir
fullname=`repoquery ${name}`
version=`echo $fullname | sed -e 's,httpd-.:\(.*\)-.*,\1,'`
release=`echo $fullname | sed -e 's,httpd-.:.*-\(.*\)\..*,\1,'`
if [ -e ~/rpmbuild ]; then
  echo "ERROR: directory ~/rpmbuild already exists"
  exit 1
fi

# Download software
echo "Downloading ${srcpackage} for Fedora"
yumdownloader --destdir $tmpdir --source $name

# Fedora
rpmdev-setuptree
rpmbuild --rebuild ${tmpdir}/${name}-${version}-${release}.src.rpm
mkdir -p ${tmpdir}/fedora
cp -p ~/rpmbuild/RPMS/*/* ${tmpdir}/fedora
cd $tmpdir
rm -rf ~/rpmbuild

echo "**********************"
echo "RPMS built at $tmpdir"
