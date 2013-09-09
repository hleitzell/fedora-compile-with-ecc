#!/bin/bash
# Based on http://danielpocock.com/ussing-ecc-ecdsa-in-openssl-and-strongswan-fedora
#if [ `id -u` -eq 0 ]; then
#  echo "ERROR: don't run this script as root"
#  exit 1
#fi
if [ -e ~/rpmbuild ]; then
  echo "ERROR: directory ~/rpmbuild already exists"
  exit 1
fi

arch=`uname -m`
mock_arch="fedora-19-x86_64"
tmpdir=`mktemp -d`
rdir=`dirname $0`
dir=`realpath $rdir`
custom_disttag="ecc"
patch_openssl="${dir}/patches/openssl-enable_ec.patch"
patch_nsssoftokn="${dir}/patches/nss-softokn-enable_ec.patch"
patch_nssutil="${dir}/patches/nss-util-enable_ec.patch"
RPM_PACKAGER="Juan Orti Alcaine <jorti@fedoraproject.org>"
export RPM_PACKAGER

cd $tmpdir

########################################################
# OpenSSL
########################################################
# Get OpenSSL version info
if [ ! -r $patch_openssl ]; then
  echo "ERROR: Cannot read the patch file: $patch_openssl"
  exit 1
fi
fullname=`repoquery openssl.${arch}`
openssl_v=`echo $fullname | sed -e 's,openssl-.:\(.*\)-.*,\1,'`
openssl_r=`echo $fullname | sed -e 's,openssl-.:.*-\(.*\)\..*\..*,\1,'`
openssl_disttag=`echo $fullname | sed -e 's,openssl-.:.*-.*\.\(.*\)\..*,\1,'`
# Download OpenSSL
echo "Downloading openssl for Fedora"
yumdownloader --destdir $tmpdir --source openssl
echo "Downloading openssl-${openssl_v}.tar.gz"
wget --timestamping -P $tmpdir  https://www.openssl.org/source/openssl-${openssl_v}.tar.gz

# OpenSSL - Fedora
rpm -i ${tmpdir}/openssl-${openssl_v}-${openssl_r}.${openssl_disttag}.src.rpm
cp -p ${tmpdir}/openssl-${openssl_v}.tar.gz ~/rpmbuild/SOURCES 
pushd  ~/rpmbuild
  # Orginal patch from http://zxvdr.fedorapeople.org/openssl.spec.ec_patch
  patch -p1 < $patch_openssl
  rpmdev-bumpspec -s $custom_disttag -c "- Enable ECC" SPECS/openssl.spec
popd
rpmbuild -bs ~/rpmbuild/SPECS/openssl.spec
mock -r $mock_arch ~/rpmbuild/SRPMS/openssl-${openssl_v}-${openssl_r}.${openssl_disttag}.${custom_disttag}1.src.rpm
if [ $? -ne 0 ]; then
   echo "ERROR: OpenSSL mock build failed"
   exit 0
fi
mkdir -p ${tmpdir}/openssl
mv /var/lib/mock/${mock_arch}/result/openssl*rpm ${tmpdir}/openssl
rm -rf ~/rpmbuild

########################################################
# Apache
########################################################
# Get Apache version info
fullname=`repoquery httpd.${arch}`
httpd_v=`echo $fullname | sed -e 's,httpd-.:\(.*\)-.*,\1,'`
httpd_r=`echo $fullname | sed -e 's,httpd-.:.*-\(.*\)\..*\..*,\1,'`
httpd_disttag=`echo $fullname | sed -e 's,httpd-.:.*-.*\.\(.*\)\..*,\1,'`
# Download Apache
echo "Downloading httpd for Fedora"
yumdownloader --destdir $tmpdir --source httpd

# Apache - Fedora
rpm -i ${tmpdir}/httpd-${httpd_v}-${httpd_r}.${httpd_disttag}.src.rpm
pushd ~/rpmbuild
  rpmdev-bumpspec -s $custom_disttag -c "- Enable ECC" SPECS/httpd.spec
popd
rpmbuild -bs ~/rpmbuild/SPECS/httpd.spec
mock -r $mock_arch --init
mock -r $mock_arch --copyin ${tmpdir}/openssl/*rpm /tmp
mock -r $mock_arch --install yum
mock -r $mock_arch --shell "/usr/bin/yum install -y /tmp/openssl*rpm"
mock -r $mock_arch --no-clean --rebuild ~/rpmbuild/SRPMS/httpd-${httpd_v}-${httpd_r}.${httpd_disttag}.${custom_disttag}1.src.rpm
if [ $? -ne 0 ]; then
   echo "ERROR: Httpd mock build failed"
   exit 0
fi
mkdir -p ${tmpdir}/httpd
mv /var/lib/mock/${mock_arch}/result/*.rpm ${tmpdir}/httpd
rm -rf ~/rpmbuild

########################################################
# nss-softokn
########################################################
# Get nss-softokn version info
if [ ! -r $patch_nsssoftokn ]; then
  echo "ERROR: Cannot read the patch file: $patch_nsssoftokn"
  exit 1
fi
fullname=`repoquery nss-softokn.${arch}`
nss_softokn_v=`echo $fullname | sed -e 's,nss-softokn-.:\(.*\)-.*,\1,'`
nss_softokn_r=`echo $fullname | sed -e 's,nss-softokn-.:.*-\(.*\)\..*\..*,\1,'`
nss_softokn_disttag=`echo $fullname | sed -e 's,nss-softokn-.:.*-.*\.\(.*\)\..*,\1,'`

fullname=`repoquery nss.${arch}`
nss_v=`echo $fullname | sed -e 's,nss-.:\(.*\)-.*,\1,'`
nss_r=`echo $fullname | sed -e 's,nss-.:.*-\(.*\)\..*,\1,'`
nss_v1=`echo $nss_v | sed -e 's,\(.*\)\..*\..*,\1,'`
nss_v2=`echo $nss_v | sed -e 's,.*\.\(.*\)\..*,\1,'`
nss_v3=`echo $nss_v | sed -e 's,.*\..*\.\(.*\),\1,'`

# Download NSS
echo "Downloading NSS for Fedora"
yumdownloader --destdir $tmpdir --source nss-softokn
wget --timestamping -P $tmpdir ftp://ftp.mozilla.org/pub/mozilla.org/security/nss/releases/NSS_${nss_v1}_${nss_v2}_${nss_v3}_RTM/src/nss-${nss_v}.tar.gz

rpm -i ${tmpdir}/nss-softokn-${nss_softokn_v}-${nss_softokn_r}.${nss_softokn_disttag}.src.rpm
cp -p -f ${tmpdir}/nss-${nss_v}.tar.gz ~/rpmbuild/SOURCES
pushd ~/rpmbuild
  patch -p1 < $patch_nsssoftokn
  rpmdev-bumpspec -s $custom_disttag -c "- Enable ECC" SPECS/nss-softokn.spec
popd
pushd ~/rpmbuild/SOURCES
  ./nss-split-softokn.sh $nss_softokn_v
popd
rpmbuild -bs ~/rpmbuild/SPECS/nss-softokn.spec
mock -r $mock_arch ~/rpmbuild/SRPMS/nss-softokn-${nss_softokn_v}-${nss_softokn_r}.${nss_softokn_disttag}.${custom_disttag}1.src.rpm
if [ $? -ne 0 ]; then
   echo "ERROR: nss-softokn mock build failed"
   exit 0
fi
mkdir -p ${tmpdir}/nss-softokn
mv /var/lib/mock/${mock_arch}/result/*.rpm ${tmpdir}/nss-softokn
rm -rf ~/rpmbuild

echo "**********************"
echo "RPMS built at $tmpdir"
