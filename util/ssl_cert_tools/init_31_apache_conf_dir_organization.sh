#! /bin/bash
#
# ARGS: server.dir.prefix
# 

cat <<EOT

.......................................................................................

Initializing the $1 Apache Bulk Virtual Host SSL Server configuration directory tree...

EOT




if test $# != 2 ; then
  cat <<EOT

ERROR: b0rk b0rk b0rk

THIS ACTION IS NOW ABORTING...

EOT
  exit 1
fi


if ! test -d 21_server_CA ; then
  cat <<EOT

ERROR: you are running 

  $0

in the wrong directory: we don't see the mandatory '21_server_CA' directory in here!

THIS ACTION IS NOW ABORTING...

EOT
  exit 1
fi









wd="$( pwd )";

# http://stackoverflow.com/questions/3572030/bash-script-absolute-path-with-osx/3572105#3572105
realpath() {
  [[ $1 = /* ]] && echo "$1" || echo "$wd/${1#./}"
}


# destination path must exist, or be made to exist:
if ! test -d "$2" ; then
  mkdir -p "$2"
fi


serverCertBaseDir="21_server_CA/newcerts/$( echo "$1" | sed -e 's/[^0-9a-zA-Z._-]/-/g' )"  

if ! test -d "$serverCertBaseDir" ; then
  echo "UH-OH INTERNAL ERROR: SERVER"
  exit 2
fi




# And generate the directory contents for the ssl-vhosts-bulk.conf Apache configuration:
# decrypted key, certificate, etc.etc.
# 
#     
#    SSLCertificateFile      conf/ssl-vhosts-bulk/crt/vhosts-bulk-server.crt
#    #SSLCertificateFile      conf/ssl-vhosts-bulk/crt/vhosts-bulk-server-dsa.crt
#    SSLCertificateKeyFile   conf/ssl-vhosts-bulk/key/vhosts-bulk-server.key
#
#    #
#    # We use client certificates to ensure only vetted individuals are allowed to reach these 
#    # HTTPS protected websites.
#    # 
#    SSLVerifyClient require
#    SSLVerifyDepth 10
#    SSLCARevocationFile     conf/ssl-vhosts-bulk/crl/ca-bundle-client.crl
#    SSLCACertificateFile    conf/ssl-vhosts-bulk/crt/ca-bundle-client.crt
#    SSLCADNRequestFile      conf/ssl-vhosts-bulk/ca-names.crt
#
if     ! test -s "$2/conf/ssl-vhosts-bulk/ca-names.crt"                 \
    && ! test -s "$2/conf/ssl-vhosts-bulk/crl/ca-bundle-client.crl"     \
    && ! test -s "$2/conf/ssl-vhosts-bulk/crt/ca-bundle-client.crt"     \
    && ! test -s "$2/conf/ssl-vhosts-bulk/crt/vhosts-bulk-server.crt"   \
    && ! test -s "$2/conf/ssl-vhosts-bulk/key/vhosts-bulk-server.key"   \
    && ! test -s "$2/conf/ssl-vhosts-bulk/server.crt"                   \
    && ! test -s "$2/conf/ssl-vhosts-bulk/servercert.p12"               \
; then
  cat <<EOT

Generating the Apache ssl-vhosts-bulk SSL Certs & Keys directory layout in

      $2/conf/ssl-vhosts-bulk/...


EOT

  mkdir -p  "$2/conf/ssl-vhosts-bulk/crt"
  mkdir -p  "$2/conf/ssl-vhosts-bulk/crl"
  mkdir -p  "$2/conf/ssl-vhosts-bulk/key"

  echo "concat server + CA certs..."
  cp "$serverCertBaseDir/bundled-server.crt"  "$2/conf/ssl-vhosts-bulk/collected-server-and-ca-certs.pem"

  openssl x509 -in "$serverCertBaseDir/servercert.pem" -outform pem -out "$2/conf/ssl-vhosts-bulk/server.crt"

  echo "create a PKCS12 certificate ..."
  # openssl pkcs12 -export -in "$2/conf/ssl-vhosts-bulk/collected-server-and-ca-certs.pem" -name "Moir-Brandts-Honk Server Certificate" -inkey "$serverCertBaseDir/private/serverkey.pem" -passin "file:$serverCertBaseDir/private/pass.phrase.txt" -out "$2/conf/ssl-vhosts-bulk/servercert-1.p12" -passout pass:dummy
  openssl pkcs12 -export -in "$2/conf/ssl-vhosts-bulk/collected-server-and-ca-certs.pem" -name "Moir-Brandts-Honk Server Certificate" -inkey "$serverCertBaseDir/private/serverkey.pem" -passin "file:$serverCertBaseDir/private/pass.phrase.txt" -out "$2/conf/ssl-vhosts-bulk/servercert.p12" -passout pass:

  # echo "remove password from the PKCS12 file..." 
  # # (cannot do that in the previous command, hence this second pkcs12 call):
  # openssl pkcs12 -passin pass:dummy -in "$2/conf/ssl-vhosts-bulk/servercert-1.p12" -clcerts -nokeys -out "$2/conf/ssl-vhosts-bulk/servercert-1.cert.crt"
  # openssl pkcs12 -passin pass:dummy -in "$2/conf/ssl-vhosts-bulk/servercert-1.p12" -cacerts -nokeys -out "$2/conf/ssl-vhosts-bulk/servercert-1.ca-cert.crt"
  # openssl pkcs12 -passin pass:dummy -in "$2/conf/ssl-vhosts-bulk/servercert-1.p12" -nocerts -out "$2/conf/ssl-vhosts-bulk/servercert-1.private.key" -passout pass:TemporaryPassword
  # openssl rsa -in "$2/conf/ssl-vhosts-bulk/servercert-1.private.key" -out "$2/conf/ssl-vhosts-bulk/servercert-1.new.key" -passin pass:TemporaryPassword

  # cat "$2/conf/ssl-vhosts-bulk/servercert-1.new.key" "$2/conf/ssl-vhosts-bulk/servercert-1.cert.crt" "$2/conf/ssl-vhosts-bulk/servercert-1.ca-cert.crt" > PEM.pem

  # openssl pkcs12 -export -nodes -CAfile "$2/conf/ssl-vhosts-bulk/servercert-1.ca-cert.crt" -in PEM.pem -out "$2/conf/ssl-vhosts-bulk/servercert.p12" -passout pass:

  echo "Generate a trimmed server certificate..."
  cp "$2/conf/ssl-vhosts-bulk/collected-server-and-ca-certs.pem"  "$2/conf/ssl-vhosts-bulk/crt/vhosts-bulk-server.crt"

  echo "Generate a trimmed server CA list..."
  cp "$serverCertBaseDir/bundled-server-ca-list.crt"  "$2/conf/ssl-vhosts-bulk/crt/ca-bundle-server.crt"

  echo "and write the decrypted server key..."
  openssl rsa -passin "file:$serverCertBaseDir/private/pass.phrase.txt" -in "$serverCertBaseDir/private/serverkey.pem" -outform pem -out "$2/conf/ssl-vhosts-bulk/key/vhosts-bulk-server.key"



  echo "set up the files for the client certificates:"

  # trim off the text parts in those .pem files to produce a clean catalog:
  # https://www.digicert.com/ssl-support/pem-ssl-creation.htm
  openssl x509 -in 22_client_CA/cacert.pem         -outform pem  > "$2/conf/ssl-vhosts-bulk/collected-ca-client-certs.pem"
  openssl x509 -in 12_client_base_CA/cacert.pem    -outform pem >> "$2/conf/ssl-vhosts-bulk/collected-ca-client-certs.pem"
  openssl x509 -in 00_root_CA/cacert.pem           -outform pem >> "$2/conf/ssl-vhosts-bulk/collected-ca-client-certs.pem"
  
  echo "copy the client issuing CA certificate to the right place..."
  openssl x509 -in "22_client_CA/cacert.pem" -outform pem -out "$2/conf/ssl-vhosts-bulk/ca-names.crt"
  
  echo "copy the client issuing CA certificate CHAIN to the right place..."
  #openssl x509 -in "$2/conf/ssl-vhosts-bulk/collected-ca-client-certs.pem" -outform pem -out "$2/conf/ssl-vhosts-bulk/crt/ca-bundle-client.crt"
  # ^-- that command strips all but the *first* certificate, which is NOT what we want!
  cp "$2/conf/ssl-vhosts-bulk/collected-ca-client-certs.pem"  "$2/conf/ssl-vhosts-bulk/crt/ca-bundle-client.crt"

  echo "copy the revocation list too..."
  cat "22_client_CA/crl.pem"       > "$2/conf/ssl-vhosts-bulk/crl/ca-bundle-client.crl"
  cat "12_client_base_CA/crl.pem" >> "$2/conf/ssl-vhosts-bulk/crl/ca-bundle-client.crl"
  cat "00_root_CA/crl.pem"        >> "$2/conf/ssl-vhosts-bulk/crl/ca-bundle-client.crl"



  # cleanup
  rm -f "$2/conf/ssl-vhosts-bulk/collected-server-and-ca-certs.pem"          \
        "$2/conf/ssl-vhosts-bulk/collected-ca-client-certs.pem"   \
        "$2/conf/ssl-vhosts-bulk/servercert-1.new.key"            \
        "$2/conf/ssl-vhosts-bulk/servercert-1.cert.crt"           \
        "$2/conf/ssl-vhosts-bulk/servercert-1.ca-cert.crt"        \
        PEM.pem
fi


