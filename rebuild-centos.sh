#!/bin/bash
# Based on http://danielpocock.com/ussing-ecc-ecdsa-in-openssl-and-strongswan-fedora
if [ `id -u` -eq 0 ]; then
  echo "ERROR: don't run this script as root"
  exit 1
fi
tmpdir=`mktemp -d`
rdir=`dirname $0`
dir=`realpath $rdir`
patch="${dir}/openssl-enable_ec.patch"
build_for_centos=true
centos_release=6
centos_arch="i386"
centos_patch="${dir}/openssl-enable_ec_centos.patch"

if [ ! -r $patch ]; then
  echo "ERROR: Cannot read the patch file: $patch"
  exit 1
fi
if [ -e ~/rpmbuild ]; then
  echo "ERROR: directory ~/rpmbuild already exists"
  exit 1
fi

# Get OpenSSL version info
cd $tmpdir
fullname=`repoquery openssl`
openssl_v=`echo $fullname | sed -e 's,openssl-.:\(.*\)-.*,\1,'`
openssl_r=`echo $fullname | sed -e 's,openssl-.:.*-\(.*\)\..*,\1,'`
# Download OpenSSL
echo "Downloading ${srcpackage} for Fedora"
yumdownloader --destdir $tmpdir --source openssl
echo "Downloading openssl-${openssl_v}.tar.gz"
wget --timestamping -P $tmpdir  https://www.openssl.org/source/openssl-${openssl_v}.tar.gz

# OpenSSL - Fedora
rpmdev-setuptree
rpm -i ${tmpdir}/openssl-${openssl_v}-${openssl_r}.src.rpm
cp -p ${tmpdir}/openssl-${openssl_v}.tar.gz ~/rpmbuild/SOURCES 
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

# OpenSSL - CentOS
if $build_for_centos; then
  if [ ! -r $centos_patch ]; then
    echo "ERROR: Cannot read the patch file: $centos_patch"
    exit 1
  fi
  rpmdev-setuptree
  rpm -i ${tmpdir}/openssl-${openssl_v}-${openssl_r}.src.rpm
  cp -p ${tmpdir}/openssl-${openssl_v}.tar.gz ~/rpmbuild/SOURCES
  cd ~/rpmbuild/SPECS
  # Orginal patch from http://zxvdr.fedorapeople.org/openssl.spec.ec_patch
  patch -p1 < $centos_patch
  # Fedora's SRPM has a modified source, must use the original
  sed -i -e 's/-usa.tar.xz/.tar.gz/' openssl.spec
  rpmbuild -bs openssl.spec
  mock -r epel-${centos_release}-${centos_arch} ~/rpmbuild/SRPMS/openssl-${openssl_v}-${openssl_r}.src.rpm
  mkdir -p ${tmpdir}/centos
  cp -p /var/lib/mock/epel-${centos_release}-${centos_arch}/result/*rpm ${tmpdir}/centos
  cd $tmpdir
  rm -rf ~/rpmbuild
fi

# Get Apache verson info
fullname=`repoquery httpd`
httpd_v=`echo $fullname | sed -e 's,httpd-.:\(.*\)-.*,\1,'`
httpd_r=`echo $fullname | sed -e 's,httpd-.:.*-\(.*\)\..*,\1,'`
# Download Apache
echo "Downloading ${srcpackage} for Fedora"
yumdownloader --destdir $tmpdir --source httpd

# Apache - Fedora
rpmdev-setuptree
rpmbuild --rebuild ${tmpdir}/httpd-${httpd_v}-${httpd_r}.src.rpm
cp -p ~/rpmbuild/RPMS/*/* ${tmpdir}/fedora
cd $tmpdir
rm -rf ~/rpmbuild

# Apache - CentOS
if $build_for_centos; then
  mock -r epel-${centos_release}-${centos_arch} --init
  #mock -r epel-${centos_release}-${centos_arch} --copyin ${tmpdir}/centos/openssl-${openssl_v}-${openssl_r}.*.rpm /tmp
  #mock -r epel-${centos_release}-${centos_arch} --shell "yum install 
  mock -r epel-${centos_release}-${centos_arch} --copyin ${dir}/CentOS-source.repo /etc/yum.repos.d
  for file in $(find ${tmpdir}/centos/openssl-*rpm); do
    mock -r epel-${centos_release}-${centos_arch} --copyin $file /tmp
  done
  mock -r epel-${centos_release}-${centos_arch} --shell "yum install /tmp/openssl*rpm"
  mock -r epel-${centos_release}-${centos_arch} --install yum-utils
  mock -r epel-${centos_release}-${centos_arch} --chroot "yumdownloader --destdir /tmp --source httpd"
  mock -r epel-${centos_release}-${centos_arch} --copyout /tmp/httpd* ${tmpdir}/centos
  mock -r epel-${centos_release}-${centos_arch} --no-clean ${tmpdir}/centos/httpd*src.rpm
fi
cp -p /var/lib/mock/epel-${centos_release}-${centos_arch}/result/*rpm ${tmpdir}/centos

echo "**********************"
echo "RPMS built at $tmpdir"








