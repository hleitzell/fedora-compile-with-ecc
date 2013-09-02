#!/bin/bash
# Based on http://danielpocock.com/ussing-ecc-ecdsa-in-openssl-and-strongswan-fedora
if [ `id -u` -eq 0 ]; then
  echo "ERROR: don't run this script as root"
  exit 1
fi
arch=`uname -m`
tmpdir=`mktemp -d`
rdir=`dirname $0`
dir=`realpath $rdir`
patch="${dir}/openssl-enable_ec.patch"

if [ ! -r $patch ]; then
  echo "ERROR: Cannot read the patch file: $patch"
  exit 1
fi
if [ -e ~/rpmbuild ]; then
  echo "ERROR: directory ~/rpmbuild already exists"
  exit 1
fi

#echo "Installing building dependencies:"
#sudo yum-builddep openssl httpd nss nss-util nss-softokn

# Get OpenSSL version info
cd $tmpdir
fullname=`repoquery openssl.${arch}`
openssl_v=`echo $fullname | sed -e 's,openssl-.:\(.*\)-.*,\1,'`
openssl_r=`echo $fullname | sed -e 's,openssl-.:.*-\(.*\)\..*,\1,'`
# Download OpenSSL
echo "Downloading openssl for Fedora"
yumdownloader --destdir $tmpdir --source openssl
echo "Downloading openssl-${openssl_v}.tar.gz"
wget --timestamping -P $tmpdir  https://www.openssl.org/source/openssl-${openssl_v}.tar.gz

# OpenSSL - Fedora
rpm -i ${tmpdir}/openssl-${openssl_v}-${openssl_r}.src.rpm
cp -p ${tmpdir}/openssl-${openssl_v}.tar.gz ~/rpmbuild/SOURCES 
cd ~/rpmbuild/SPECS
# Orginal patch from http://zxvdr.fedorapeople.org/openssl.spec.ec_patch
patch -p0 < $patch
# Fedora's SRPM has a modified source, must use the original
sed -i -e 's/-usa.tar.xz/.tar.gz/' openssl.spec
rpmbuild -ba openssl.spec
mkdir -p ${tmpdir}/openssl
mv ~/rpmbuild/RPMS/*/* ${tmpdir}/openssl
cd $tmpdir
rm -rf ~/rpmbuild
sudo rpm -ivh --force ${tmpdir}/openssl/openssl-libs-${openssl_v}-${openssl_r}.${arch}.rpm
sudo rpm -ivh --force ${tmpdir}/openssl/openssl-${openssl_v}-${openssl_r}.${arch}.rpm
sudo rpm -ivh --force ${tmpdir}/openssl/openssl-devel-${openssl_v}-${openssl_r}.${arch}.rpm

# Get Apache verson info
fullname=`repoquery httpd.${arch}`
httpd_v=`echo $fullname | sed -e 's,httpd-.:\(.*\)-.*,\1,'`
httpd_r=`echo $fullname | sed -e 's,httpd-.:.*-\(.*\)\..*,\1,'`
# Download Apache
echo "Downloading httpd for Fedora"
yumdownloader --destdir $tmpdir --source httpd

# Apache - Fedora
rpmbuild --rebuild ${tmpdir}/httpd-${httpd_v}-${httpd_r}.src.rpm
mkdir -p ${tmpdir}/httpd
mv ~/rpmbuild/RPMS/*/* ${tmpdir}/httpd
cd $tmpdir
rm -rf ~/rpmbuild

# NSS
fullname=`repoquery nss-util.${arch}`
nss_util_v=`echo $fullname | sed -e 's,nss-util-.:\(.*\)-.*,\1,'`
nss_util_r=`echo $fullname | sed -e 's,nss-util-.:.*-\(.*\)\..*,\1,'`

fullname=`repoquery nss-softokn.${arch}`
nss_softokn_v=`echo $fullname | sed -e 's,nss-softokn-.:\(.*\)-.*,\1,'`
nss_softokn_r=`echo $fullname | sed -e 's,nss-softokn-.:.*-\(.*\)\..*,\1,'`

fullname=`repoquery nss.${arch}`
nss_v=`echo $fullname | sed -e 's,nss-.:\(.*\)-.*,\1,'`
nss_r=`echo $fullname | sed -e 's,nss-.:.*-\(.*\)\..*,\1,'`
nss_v1=`echo $nss_v | sed -e 's,\(.*\)\..*\..*,\1,'`
nss_v2=`echo $nss_v | sed -e 's,.*\.\(.*\)\..*,\1,'`
nss_v3=`echo $nss_v | sed -e 's,.*\..*\.\(.*\),\1,'`

echo "Downloading nss-softokn for Fedora"
yumdownloader --destdir $tmpdir --source nss
yumdownloader --destdir $tmpdir --source nss-softokn
yumdownloader --destdir $tmpdir --source nss-util
wget --timestamping -P $tmpdir ftp://ftp.mozilla.org/pub/mozilla.org/security/nss/releases/NSS_${nss_v1}_${nss_v2}_${nss_v3}_RTM/src/nss-${nss_v}.tar.gz

# nss-util
rpm -i ${tmpdir}/nss-util-${nss_util_v}-${nss_util_r}.src.rpm
cp -p -f ${tmpdir}/nss-${nss_v}.tar.gz ~/rpmbuild/SOURCES/nss-${nss_v}-stripped.tar.bz2
rpmbuild -ba ~/rpmbuild/SPECS/nss-util.spec
mkdir -p ${tmpdir}/nss-util
mv ~/rpmbuild/RPMS/*/* ${tmpdir}/nss-util
rm -rf ~/rpmbuild
sudo rpm -ivh --force ${tmpdir}/nss-util/nss-util-${nss_util_v}-${nss_util_r}.${arch}.rpm
sudo rpm -ivh --force ${tmpdir}/nss-util/nss-util-devel-${nss_util_v}-${nss_util_r}.${arch}.rpm

# nss-softokn
rpm -i ${tmpdir}/nss-softokn-${nss_softokn_v}-${nss_softokn_r}.src.rpm
cp -p -f ${tmpdir}/nss-${nss_v}.tar.gz ~/rpmbuild/SOURCES/nss-${nss_v}-stripped.tar.bz2
rpmbuild -ba ~/rpmbuild/SPECS/nss-softokn.spec
mkdir -p ${tmpdir}/nss-softokn
mv ~/rpmbuild/RPMS/*/* ${tmpdir}/nss-softokn
rm -rf ~/rpmbuild
sudo rpm -ivh --force ${tmpdir}/nss-softokn/nss-softokn-freebl-${nss_softokn_v}-${nss_softokn_r}.${arch}.rpm
sudo rpm -ivh --force ${tmpdir}/nss-softokn/nss-softokn-${nss_softokn_v}-${nss_softokn_r}.${arch}.rpm
sudo rpm -ivh --force ${tmpdir}/nss-softokn/nss-softokn-freebl-devel-${nss_softokn_v}-${nss_softokn_r}.${arch}.rpm
sudo rpm -ivh --force ${tmpdir}/nss-softokn/nss-softokn-devel-${nss_softokn_v}-${nss_softokn_r}.${arch}.rpm

# nss
rpm -i ${tmpdir}/nss-${nss_v}-${nss_r}.src.rpm
cp -p -f ${tmpdir}/nss-${nss_v}.tar.gz ~/rpmbuild/SOURCES/nss-${nss_v}-stripped.tar.bz2
rpmbuild -ba ~/rpmbuild/SPECS/nss.spec
mkdir -p ${tmpdir}/nss
mv ~/rpmbuild/RPMS/*/* ${tmpdir}/nss
rm -rf ~/rpmbuild
sudo rpm -ivh --force ${tmpdir}/nss/nss-tools-${nss_v}-${nss_r}.${arch}.rpm
sudo rpm -ivh --force ${tmpdir}/nss/nss-sysinit-${nss_v}-${nss_r}.${arch}.rpm
sudo rpm -ivh --force ${tmpdir}/nss/nss-${nss_v}-${nss_r}.${arch}.rpm
sudo rpm -ivh --force ${tmpdir}/nss/nss-devel-${nss_v}-${nss_r}.${arch}.rpm
sudo rpm -ivh --force ${tmpdir}/nss/nss-pkcs11-devel-${nss_v}-${nss_r}.${arch}.rpm

echo "**********************"
echo "RPMS built at $tmpdir"