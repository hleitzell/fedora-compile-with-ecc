#!/bin/bash
# Based on http://danielpocock.com/ussing-ecc-ecdsa-in-openssl-and-strongswan-fedora
if [ `id -u` -eq 0 ]; then
  echo "ERROR: don't run this script as root"
  exit 1
fi
name="openssl"
tmpdir=`mktemp -d`
rdir=`dirname $0`
dir=`realpath $rdir`
patch="${dir}/openssl-enable_ec.patch"
build_for_centos=true
centos_release=6
centos_arch="i386"
centos_patch="${dir}/openssl-enable_ec_centos.patch"

# Get OpenSSL version info
cd $tmpdir
fullname=`repoquery ${name}`
version=`echo $fullname | sed -e 's,openssl-.:\(.*\)-.*,\1,'`
release=`echo $fullname | sed -e 's,openssl-.:.*-\(.*\)\..*,\1,'`
if [ ! -r $patch ]; then
  echo "ERROR: Cannot read the patch file: $patch"
  exit 1
fi
if [ -e ~/rpmbuild ]; then
  echo "ERROR: directory ~/rpmbuild already exists"
  exit 1
fi

# Download software
echo "Downloading ${srcpackage} for Fedora"
yumdownloader --destdir $tmpdir --source $name
echo "Downloading ${name}-${version}.tar.gz"
wget --timestamping -P $tmpdir  https://www.openssl.org/source/${name}-${version}.tar.gz

# Fedora
rpmdev-setuptree
rpm -i ${tmpdir}/${name}-${version}-${release}.src.rpm
cp -p ${tmpdir}/${name}-${version}.tar.gz ~/rpmbuild/SOURCES 
cd ~/rpmbuild/SPECS
# Orginal patch from http://zxvdr.fedorapeople.org/openssl.spec.ec_patch
patch -p0 < $patch
# Fedora's SRPM has a modified source, must use the original
sed -i -e 's/-usa.tar.xz/.tar.gz/' openssl.spec
rpmbuild -ba openssl.spec
mkdir -p ${tmpdir}/fedora
cp -p ~/rpmbuild/RPMS/*/* ${tmpdir}/fedora
cp -p ~/rpmbuild/SRPMS/* ${tmpdir}/fedora
cd $tmpdir
rm -rf ~/rpmbuild

# CentOS
if $build_for_centos; then
  if [ ! -r $centos_patch ]; then
    echo "ERROR: Cannot read the patch file: $centos_patch"
    exit 1
  fi
  rpmdev-setuptree
  rpm -i ${tmpdir}/${name}-${version}-${release}.src.rpm
  cp -p ${tmpdir}/${name}-${version}.tar.gz ~/rpmbuild/SOURCES
  cd ~/rpmbuild/SPECS
  # Orginal patch from http://zxvdr.fedorapeople.org/openssl.spec.ec_patch
  patch -p1 < $centos_patch
  # Fedora's SRPM has a modified source, must use the original
  sed -i -e 's/-usa.tar.xz/.tar.gz/' openssl.spec
  rpmbuild -bs openssl.spec
  mock -r epel-${centos_release}-${centos_arch} ~/rpmbuild/SRPMS/${name}-${version}-${release}.src.rpm
  mkdir -p ${tmpdir}/centos
  cp -p /var/lib/mock/epel-${centos_release}-${centos_arch}/result/*rpm ${tmpdir}/centos
  cp -p ~/rpmbuild/SRPMS/* ${tmpdir}/centos
  cd $tmpdir
  rm -rf ~/rpmbuild
fi

echo "**********************"
echo "RPMS built at $tmpdir"
